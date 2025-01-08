// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.19;

import {HedgerTest} from "./HedgerTest.sol";

contract HedgerWithdrawAllTest is HedgerTest {
// given the cvToken is not whitelisted
//  [ ] it reverts
// given the user has not approved Hedger to operate the Morpho position
//  [ ] it reverts
// given the caller is not an approved operator for the user
//  [ ] it reverts
// [ ] it withdraws all of the collateral from the Morpho market to the user
}
