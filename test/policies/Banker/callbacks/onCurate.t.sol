// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {BankerTest} from "../BankerTest.sol";

contract BankerCallbackOnCurateTest is BankerTest {
    // given the lot does not exist
    //  [ ] it reverts
    // given the curator has a fee
    //  [ ] it mints the required base tokens
    // given the curator has no fee
    //  [ ] it does not mint any base tokens
}
