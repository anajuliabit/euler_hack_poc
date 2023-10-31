// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;
import {EToken} from "euler-contracts/modules/EToken.sol";
import {DToken} from "euler-contracts/modules/DToken.sol";

// Addresses from mainnet
library Addresses {
    address constant EULER = 0x27182842E098f60e3D576794A5bFFb0777E025d3;
    address constant LIQUIDATION = 0xf43ce1d09050BAfd6980dD43Cde2aB9F18C85b34;
    EToken constant eDAI = EToken(0xe025E3ca2bE02316033184551D4d3Aa22024D9DC);
    DToken constant dDAI = DToken(0x6085Bc95F506c326DCBCD7A6dd6c79FBc18d4686);
}
