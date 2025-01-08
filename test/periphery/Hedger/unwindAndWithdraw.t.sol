// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.19;

import {HedgerTest} from "./HedgerTest.sol";

contract HedgerUnwindAndWithdrawTest is HedgerTest {
// given the cvToken is not whitelisted
//  [ ] it reverts
// given the user has not approved Hedger to operate the Morpho position
//  [ ] it reverts
// when the amount is zero
//  [ ] it reverts
// when reserves to supply and reserves to withdraw are both zero
//  [ ] it reverts
// when the slippage check fails
//  [ ] it reverts
// given the amount is greater than the user's balance of the cvToken
//  [ ] it reverts
// when reserves to withdraw is non-zero and reserves to supply is zero
//  [ ] it withdraws the reserves from the Morpho market
//  [ ] it swaps the reserves for MGST
//  [ ] it repays the MGST loan
//  [ ] it transfers the cvToken to the user
// when reserves to supply is non-zero and reserves to withdraw is zero
//  given the caller has not approved this contract to spend the reserve token
//   [ ] it reverts
//  [ ] it transfers the reserves to the Hedger
//  [ ] it swaps the reserves for MGST
//  [ ] it repays the MGST loan
//  [ ] it transfers the cvToken to the user
// when reserves to supply and reserves to withdraw are both non-zero
//  [ ] it transfers the reserves to the Hedger
//  [ ] it withdraws the reserves from the Morpho market
//  [ ] it swaps the reserves for MGST
//  [ ] it repays the MGST loan
//  [ ] it transfers the cvToken to the user
}
