// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {Test, console2, StdCheats, StdInvariant} from "forge-std/Test.sol";
import {IERC20} from "@aave/v3/dependencies/openzeppelin/contracts/IERC20.sol";
import { Addresses } from "../src/libraries/Addresses.sol";
import {EToken} from "euler-contracts/modules/EToken.sol";
import {DToken} from "euler-contracts/modules/DToken.sol";
import {EulerSimpleLens} from "euler-contracts/views/EulerSimpleLens.sol";

// From lib/euler-contracts/contracts/Constants.sol
uint constant MAX_SANE_AMOUNT = type(uint112).max;

contract Handler is Test {

    EToken public eToken;
    DToken public dToken;
    IERC20 public token;
    EulerSimpleLens public eulerSimpleLens;

    constructor (EToken _etoken, DToken _dtoken, IERC20 _token) {
        eToken = _etoken;
        dToken = _dtoken;
        token = _token;
        eulerSimpleLens = EulerSimpleLens(Addresses.EULER_SIMPLE_LENS);
    }

    function leverage(uint256 _amount) public {
        (uint256 collateralValue, uint256 liabilityValue, ) = eulerSimpleLens.getAccountStatus(address(this));
        // 0.28 is the Euler borrow factor
        uint256 maxBorrowableAmount = (collateralValue * 28) / 100;

        uint256 availableForBorrowing = maxBorrowableAmount - liabilityValue;

        _amount = bound(_amount, 1, availableForBorrowing);

        eToken.mint(0, _amount);

    }

    function deposit(uint256 _amount) public {
        _amount = bound(_amount, 0, MAX_SANE_AMOUNT);

        deal(address(token), address(this), _amount);

        token.approve(Addresses.EULER, _amount);
        eToken.deposit(0, _amount);

    }

    function repay(uint256 _amount) public {
        uint256 borrowed = eToken.balanceOf(address(this));
        _amount = bound(_amount, 0, borrowed);

        dToken.repay(0, _amount);

    }

    function donateToReserves(uint256 _amount) public {
        uint256 eBalance = eToken.balanceOf(address(this));
        _amount = bound(_amount, 1, eBalance);

        eToken.donateToReserves(0, _amount);

    }

}
