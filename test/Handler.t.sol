// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {Test, console2, StdCheats, StdInvariant} from "forge-std/Test.sol";
import {IERC20} from "@aave/v3/dependencies/openzeppelin/contracts/IERC20.sol";
import { Addresses } from "../src/libraries/Addresses.sol";
import { Constants } from "./Constants.sol";
import {EToken} from "euler-contracts/modules/EToken.sol";
import {DToken} from "euler-contracts/modules/DToken.sol";

contract Handler is Test {

    EToken public eToken;
    DToken public dToken;
    IERC20 public token;

    constructor () {
        eToken = Addresses.eDAI;
        dToken = Addresses.dDAI;
        token = IERC20(Constants.DAI);
    }

    function donateToReserves(uint256 _amount, uint8 leverage) public {
        // Assume upper limits
        vm.assume(_amount < 10e23);
        vm.assume(leverage <= 10);

        // Mint 150% of the amount
        deal(address(token), address(this), _amount * 150 / 10);

        token.approve(Addresses.EULER, _amount);
        eToken.deposit(0, _amount);

        uint256 amountLeveraged = _amount * leverage;

        eToken.mint(0, amountLeveraged);

        dToken.repay(0, _amount / 2);

        eToken.mint(0, amountLeveraged);

        // Donate to reserves
        eToken.donateToReserves(0, amountLeveraged / 2);

        // Check invariants


    }
}
