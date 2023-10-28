// SPDX-License-Identifier: UNLICENSED
pragma experimental ABIEncoderV2;
pragma solidity ^0.6.12;

import {Test, console2} from "forge-std/Test.sol";
import {EulerHackPoC} from "../src/EulerHackPoC.sol";

contract EulerHackPoCTest is Test {
    EulerHackPoC public attacker;
    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");
    // https://etherscan.io/tx/0xc310a0affe2169d1f6feec1c63dbc7f7c62a887fa48795d327d4d2da2d6b111d
    uint256 constant ATTACK_BLOCK_NUMBER = 16817996;

    function setUp() public {
        vm.createSelectFork(MAINNET_RPC_URL, ATTACK_BLOCK_NUMBER);
        attacker = new EulerHackPoC();
    }

    function test_Attack() public {
        attacker.callFashLoan();
        console2.log("attacker balance", address(attacker).balance);
        assertEq(address(attacker).balance, 30 * 10**18);
    }
}
