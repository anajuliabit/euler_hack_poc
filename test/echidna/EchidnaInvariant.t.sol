pragma solidity ^0.8.0;
import { Addresses } from "../../src/libraries/Addresses.sol";
import {DToken} from "euler-contracts/modules/DToken.sol";
import {EToken} from "euler-contracts/modules/EToken.sol";
import {EulerSimpleLens} from "euler-contracts/views/EulerSimpleLens.sol";
import {Constants} from "../Constants.sol";

interface IHevm {
    function roll(uint256 newNumber) external;

    function store(address c, bytes32 loc, bytes32 val) external;

    function prank(address msgSender) external;
}

interface IERC20 {
    function approve(address spender, uint256 amount) external returns (bool);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function balanceOf(address account) external view returns (uint256);
}

interface IMarket {
    function enterMarket(uint subAccountId, address newMarket) external;

    function underlyingToEToken(address underlying) external view returns (address);
}

contract InvariantTestEchidna {
    IHevm internal hevm;
    EToken internal eToken;
    DToken internal dToken;
    IMarket internal market;
    IERC20 internal token;
    EulerSimpleLens internal eulerSimpleLens;
    address user = address(this);

    event log_block(uint256 block_number);
    event log_balance(uint256 balance);

    constructor() {
        eToken = EToken(Addresses.eDAI);
        dToken = DToken(Addresses.dDAI);
        token = IERC20(Addresses.DAI);
        eulerSimpleLens = EulerSimpleLens(Addresses.EULER_SIMPLE_LENS);
        market = IMarket(Addresses.MARKETS);
        hevm = IHevm(Addresses.HEVM_ADDRESS);

        // Set DAI balance to user (this contract)
        uint256 amount = 20e6 * 1e18;
//       hevm.store(address(token), keccak256(abi.encodePacked(user, uint256(2))), bytes32(abi.encodePacked(amount)));

        // Binance address
        hevm.prank(0x47ac0Fb4F2D84898e4D9E7b4DaB3C24507a6D503);
        token.transfer(user, amount);

    }

//    function leverage(uint256 _amount) public {
//        (uint256 collateralValue, uint256 liabilityValue, ) = eulerSimpleLens.getAccountStatus(user);
//
//        // 0.28 is the Euler borrow factor
//        uint256 availableForBorrowing = ((collateralValue * 28) / 100) - liabilityValue;
//
//        _amount = _amount % availableForBorrowing;
//
//        eToken.mint(0, _amount);
//
//        assert(dToken.balanceOf(user) <= eToken.balanceOf(user));
//    }

    function deposit(uint256 _amount) public {
        uint256 balance = token.balanceOf(user);
        _amount = _amount % balance;

        token.approve(Addresses.EULER, _amount);
        market.enterMarket(0, address(token));

        //hevm.roll(Constants.ATTACK_BLOCK_NUMBER - 1);
        assert(block.number < Constants.ATTACK_BLOCK_NUMBER);
        eToken.deposit(0, _amount);
        assert(eToken.balanceOf(user) <= dToken.balanceOf(user));
    }

 //   function repay(uint256 _amount) public {
 //       uint256 borrowed = eToken.balanceOf(user);
 //       _amount = _amount % borrowed;

 //       dToken.repay(0, _amount);

 //       assert(dToken.balanceOf(user) <= eToken.balanceOf(user));
 //   }

 //   function donateToReserves(uint256 _amount) public {
 //       uint256 eBalance = eToken.balanceOf(user);
 //       // range is [1, eBalance)
 //       _amount = 1 + (_amount % (eBalance - 1));

 //       eToken.donateToReserves(0, _amount);

 //       assert(dToken.balanceOf(user) <= eToken.balanceOf(user));
 //   }

}
