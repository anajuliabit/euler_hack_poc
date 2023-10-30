// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {Test, console2, StdCheats, StdInvariant} from "forge-std/Test.sol";
import { Addresses } from "../src/libraries/Addresses.sol";
import { Constants } from "./Constants.sol";
import {IERC20} from "@aave/v3/dependencies/openzeppelin/contracts/IERC20.sol";
import {EToken} from "euler-contracts/modules/EToken.sol";
import {DToken} from "euler-contracts/modules/DToken.sol";
import {IPool} from "@aave/v3/interfaces/IPool.sol";
import {Handler} from "./Handler.t.sol";

contract InvariantTest is Test {
    Handler public handler;
    EToken public eDAI;
    DToken public dDAI;

    function setUp() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), Constants.ATTACK_BLOCK_NUMBER - 1);
        eDAI = Addresses.eDAI;
        dDAI = Addresses.dDAI;

        handler = new Handler();
        targetContract(address(handler));
    }

    // Invariant to check account health
    function invariant_debtNeverInsovent() public {
        address user = address(handler);

        // Check invariants
        assert(dDAI.balanceOf(user) <= eDAI.balanceOf(user));
    }

}
