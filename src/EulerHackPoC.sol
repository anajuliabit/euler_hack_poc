// SPDX-License-Identifier: UNLICENSED
// TODO update sol version
pragma solidity ^0.8.0;

import {IPool} from "@aave/v3/interfaces/IPool.sol";
import {IPoolAddressesProvider} from "@aave/v3/interfaces/IPoolAddressesProvider.sol";
import {FlashLoanSimpleReceiverBase} from "@aave/v3/flashloan/base/FlashLoanSimpleReceiverBase.sol";
import {IERC20} from "@aave/v3/dependencies/openzeppelin/contracts/IERC20.sol";

contract EulerHackPoC is FlashLoanSimpleReceiverBase{
    address constant aDAI = 0x018008bfb33d285247A21d44E50697654f754e63;

    //address constant aDAI = 0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c;

     constructor(
        address _addressProvider
    ) FlashLoanSimpleReceiverBase(IPoolAddressesProvider(_addressProvider)) {}

    // 1. Flahsloan 30M DAI from AaveV2
    function callFashLoan() external {
       POOL.flashLoanSimple(address(this), aDAI, 30 * 10**18, "0x", 0);
    }

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

        // At the end of your logic above, this contract owes
        // the flashloaned amounts + premiums.
        // Therefore ensure your contract has enough to repay
        // these amounts.

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
}

contract Liquidator {}
