// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {Test, console2, StdCheats, StdInvariant} from "forge-std/Test.sol";
import { Addresses } from "../src/libraries/Addresses.sol";
import {Constants} from "./Constants.sol";
import {IERC20} from "@aave/v3/dependencies/openzeppelin/contracts/IERC20.sol";
import {EToken} from "euler-contracts/modules/EToken.sol";
import {DToken} from "euler-contracts/modules/DToken.sol";
import {Handler} from "./Handler.t.sol";

contract InvariantTest is Test {
    Handler public handler;
    EToken public eDAI;
    DToken public dDAI;

    function setUp() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), Constants.ATTACK_BLOCK_NUMBER - 1);
        eDAI = EToken(Addresses.eDAI);
        dDAI = DToken(Addresses.dDAI);
        IERC20 token = IERC20(Addresses.DAI);

        handler = new Handler(eDAI, dDAI, token);

        handler.deposit(1e9 * 1e18);

        targetContract(address(handler));
    }

    // @notice invariant: No protocol action should be able to result in an account with risk adjusted liability > risk adjusted assets (checkLiquidity failing)
    // @dev I've used the balance of EToken and DToken just for simplicity as this is only an example.
    // The logic in checkLiquidity should have been used to check the real invariant.
    function invariant_NeverInsolvent() public view {
        address user = address(handler);

        uint256 eTokenBalance = eDAI.balanceOf(user);
        uint256 dTokenBalance = dDAI.balanceOf(user);

        console2.log("eTokenBalance", eTokenBalance / 1e18);
        console2.log("dTokenBalance", dTokenBalance / 1e18);
        // Check invariants
        assert(dTokenBalance <= eTokenBalance);
    }

}
