// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.19;

import {HedgerTest} from "./HedgerTest.sol";

contract HedgerIncreaseHedgeTest is HedgerTest {
    // given the cvToken is not whitelisted
    //  [ ] it reverts
    // when the hedge amount is zero
    //  [ ] it reverts
    // when the slippage check fails
    //  [ ] it reverts
    // [ ] it borrows the hedge amount in MGST, swaps it for the reserve token, and deposits it into the Morpho market on behalf of the caller
}