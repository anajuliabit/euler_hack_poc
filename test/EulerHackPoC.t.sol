// SPDX-License-Identifier: UNLICENSED
pragma experimental ABIEncoderV2;
pragma solidity ^0.8.0;

import {Test, console2} from "forge-std/Test.sol";
import {EulerHackPoC} from "../src/EulerHackPoC.sol";
import {IPoolAddressesProvider} from "@aave/v3/interfaces/IPoolAddressesProvider.sol";
import {IPool} from "@aave/v3/interfaces/IPool.sol";
import {DataTypes} from "@aave/v3/protocol/libraries/types/DataTypes.sol";
import {IERC20} from "@aave/v3/dependencies/openzeppelin/contracts/IERC20.sol";

contract EulerHackPoCTest is Test {
    EulerHackPoC public attacker;
    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");
    // https://etherscan.io/tx/0xc310a0affe2169d1f6feec1c63dbc7f7c62a887fa48795d327d4d2da2d6b111d
    uint256 constant ATTACK_BLOCK_NUMBER = 16817996;
    IPoolAddressesProvider public poolAddressesProvider;
    address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    IPool public POOL;

    function setUp() public {
        // TODO put attack block number here
        vm.createSelectFork(MAINNET_RPC_URL);
        poolAddressesProvider = IPoolAddressesProvider(0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e);
        POOL = IPool(poolAddressesProvider.getPool());
        attacker = new EulerHackPoC(poolAddressesProvider, DAI);

    }

    function test_getConfiguration() public {
        DataTypes.ReserveConfigurationMap memory config = POOL.getConfiguration(DAI);
        //bit 56: reserve is active
        // check if reserve is active
        assertEq(config.data & 2**56, 2**56);
    }

    function test_Attack() public {
        // impersonate random account with DAI, from https://etherscan.io/token/0x6b175474e89094c44da98b954eedeac495271d0f#balances
        address daiHolder = 0x47ac0Fb4F2D84898e4D9E7b4DaB3C24507a6D503;

        uint256 borrowAmount = 30 * 10**18;

        attacker.callFashLoan(DAI, borrowAmount);
        assertEq(address(attacker).balance, borrowAmount);
    }
}
