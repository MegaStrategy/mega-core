// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.19;

import {HedgerTest} from "./HedgerTest.sol";

contract HedgerDepositAndHedgeForTest is HedgerTest {
// given the cvToken is not whitelisted
//  [ ] it reverts
// given the user has not approved Hedger to operate the Morpho position
//  [ ] it reverts
// given the caller is not an approved operator for the user
//  [ ] it reverts
// given the user has not approved this contract to spend the cvToken
//  [ ] it reverts
// given the user does not have sufficient balance of the cvToken
//  [ ] it reverts
// [ ] it deposits the cvToken into the Morpho market on behalf of the user
// [ ] it borrows the hedge amount in MGST, swaps it for the reserve token, and deposits it into the Morpho market on behalf of the user
}
