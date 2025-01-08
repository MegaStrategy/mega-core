// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.19;

import {HedgerTest} from "./HedgerTest.sol";

contract HedgerWithdrawTest is HedgerTest {
// given the cvToken is not whitelisted
//  [ ] it reverts
// given the user has not approved Hedger to operate the Morpho position
//  [ ] it reverts
// given the amount is greater than the user's balance of the cvToken
//  [ ] it reverts
// [ ] it withdraws the collateral from the Morpho market to the caller
}
