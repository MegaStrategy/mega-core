// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.19;

import {HedgerTest} from "./HedgerTest.sol";

contract HedgerWithdrawReservesTest is HedgerTest {
    // given the amount is zero
    //  [ ] it reverts
    // given the user's position does not have sufficient balance of the reserve token
    //  [ ] it reverts
    // [ ] it withdraws the reserves from the MGST<>RESERVE market and transfers them to the caller
}
