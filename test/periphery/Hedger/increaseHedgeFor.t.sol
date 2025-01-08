// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.19;

import {HedgerTest} from "./HedgerTest.sol";

contract HedgerIncreaseHedgeForTest is HedgerTest {
// given the cvToken is not whitelisted
//  [ ] it reverts
// given the user has not approved Hedger to operate the Morpho position
//  [ ] it reverts
// given the caller is not an approved operator for the user
//  [ ] it reverts
// when the hedge amount is zero
//  [ ] it reverts
// when the slippage check fails
//  [ ] it reverts
// [ ] it borrows the hedge amount in MGST, swaps it for the reserve token, and deposits it into the Morpho market on behalf of the user
}
