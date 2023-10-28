// SPDX-License-Identifier: UNLICENSED
// TODO update sol version
pragma solidity ^0.6.12;

import {ILendingPool} from "@aave/v2/interfaces/ILendingPool.sol";

interface IERC20 {
    function approve(address spender, uint256 amount) external returns (bool);
}

contract EulerHackPoC {
    address constant LENDING_POOL_ADDRESS = 0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9;

    address constant aDAI = 0x028171bCA77440897B824Ca71D1c56caC55b68A3;

    // 1. Flahsloan 30M DAI from AaveV2
    function callFashLoan() external {
       address[] memory assets = new address[](1);
       assets[0] = aDAI;

       uint256[] memory amounts = new uint256[](1);
       amounts[0] = 30 * 10**18;

       uint256[] memory modes = new uint256[](1);
       modes[0] = 0;

       ILendingPool(LENDING_POOL_ADDRESS).flashLoan(address(this), assets, amounts, modes, address(0), bytes(""), 0);
    }

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    )
        external
        override
        returns (bool)
    {

        // At the end of your logic above, this contract owes
        // the flashloaned amounts + premiums.
        // Therefore ensure your contract has enough to repay
        // these amounts.

        // Approve the LendingPool contract allowance to *pull* the owed amount
        for (uint i = 0; i < assets.length; i++) {
            uint amountOwing = amounts[i].add(premiums[i]);
            IERC20(assets[i]).approve(LENDING_POOL_ADDRESS, amountOwing);
        }

        return true;
    }
}

contract Violator {
}

contract Liquidator {}
