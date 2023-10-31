// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {Test, console2, StdCheats, StdInvariant} from "forge-std/Test.sol";
import {IERC20} from "@aave/v3/dependencies/openzeppelin/contracts/IERC20.sol";
import { Addresses } from "../src/libraries/Addresses.sol";
import {EToken} from "euler-contracts/modules/EToken.sol";
import {DToken} from "euler-contracts/modules/DToken.sol";

// From lib/euler-contracts/contracts/Constants.sol
uint constant MAX_SANE_AMOUNT = type(uint112).max;

contract Handler is Test {

    EToken public eToken;
    DToken public dToken;
    IERC20 public token;

    constructor (EToken _etoken, DToken _dtoken, IERC20 _token) {
        eToken = _etoken;
        dToken = _dtoken;
        token = _token;
    }

    function borrowWithLeverageAndDonate(uint256 _amount) public {
        vm.assume(_amount <= MAX_SANE_AMOUNT);

       // The minBalance is set to 150% of the given _amount.
        // - 2/3 of the _amount is used for leveraging the position.
        // - 1/3 of the _amount is used to decrease the dToken balance, effectively repaying part of the debt.
        uint256 minBalance = _amount * 3 / 2;

        // Increase this contract DAI balance
        deal(address(token), address(this), minBalance);

        token.approve(Addresses.EULER, minBalance);
        eToken.deposit(0, _amount);

        // @dev leverage can be a arg
        uint256 amountLeveraged = _amount * 10;

        // Leverage eToken
        eToken.mint(0, amountLeveraged);

        // Repay half of the loan decreasing dToken balance
        dToken.repay(0, _amount / 2);

        // Leverage again
        eToken.mint(0, amountLeveraged);

        // Donate half of leveraged eToken to reserves
        eToken.donateToReserves(0, amountLeveraged / 2);

    }
}
