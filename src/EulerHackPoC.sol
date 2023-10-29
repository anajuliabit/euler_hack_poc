// SPDX-License-Identifier: UNLICENSED
// TODO update sol version
pragma solidity ^0.8.0;

import {Test, console2} from "forge-std/Test.sol";
import {IPool} from "@aave/v3/interfaces/IPool.sol";
import {FlashLoanSimpleReceiverBase} from "@aave/v3/flashloan/base/FlashLoanSimpleReceiverBase.sol";
import {IERC20} from "@aave/v3/dependencies/openzeppelin/contracts/IERC20.sol";
import {IPoolAddressesProvider} from "@aave/v3/interfaces/IPoolAddressesProvider.sol";

contract EulerHackPoC is FlashLoanSimpleReceiverBase, Test{
    Violator private violator;
     constructor(
        IPoolAddressesProvider _addressProvider,
        address _collateral
    ) FlashLoanSimpleReceiverBase(IPoolAddressesProvider(_addressProvider)) {
         violator = new Violator();
     }

    // 1. Flahsloan 30M DAI from AaveV2
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

        // 2. Transfer the full 30m DAI loan balance to the violator
        IERC20(asset).transfer(address(violator), amount);

        // check balance
        uint256 balance = IERC20(asset).balanceOf(address(this));
        assertEq(balance, 0);
        require(balance >= amount + premium, "Not enough funds to repay loan!");

        // Approve the LendingPool contract allowance to *pull* the owed amount
        uint amountOwing = amount + premium;
        IERC20(asset).approve(address(POOL), amountOwing);

        return true;
    }


    function getBalance(address _tokenAddress) external view returns (uint256) {
        return IERC20(_tokenAddress).balanceOf(address(this));
    }

    function withdraw(address _tokenAddress) external {
        IERC20 token = IERC20(_tokenAddress);
        token.transfer(msg.sender, token.balanceOf(address(this)));
    }

    receive() external payable {}

}

contract Violator {
    function executeAttack() {
        // 3. Deposit 20m DAI to the DAI EToken of Euler Finance, receiving ~19,56m eDAI tokens

    }
}
}

contract Liquidator {}
