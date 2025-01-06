// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.19;

import {HedgerTest} from "./HedgerTest.sol";

contract HedgerUnwindAndWithdrawAllForTest is HedgerTest {
    // given the cvToken is not whitelisted
    //  [ ] it reverts
    // given the caller is not an approved operator for the user
    //  [ ] it reverts
    // given the user has not approved this contract to spend the cvToken
    //  [ ] it reverts
    // given the user does not have sufficient balance of the cvToken
    //  [ ] it reverts
    // when reserves to supply and reserves to withdraw are both zero
    //  [ ] it reverts
    // when the slippage check fails
    //  [ ] it reverts
    // when reserves to withdraw is non-zero and reserves to supply is zero
    //  [ ] it withdraws the reserves from the Morpho market
    //  [ ] it swaps the reserves for MGST
    //  [ ] it repays the MGST loan
    //  [ ] it transfers all of the cvToken balance to the user
    // when reserves to supply is non-zero and reserves to withdraw is zero
    //  given the user has not approved this contract to spend the reserve token
    //   [ ] it reverts
    //  [ ] it transfers the reserves to the Hedger from the user
    //  [ ] it swaps the reserves for MGST
    //  [ ] it repays the MGST loan
    //  [ ] it transfers all of the cvToken balance to the user
    // when reserves to supply and reserves to withdraw are both non-zero
    //  [ ] it transfers the reserves to the Hedger from the user
    //  [ ] it withdraws the reserves from the Morpho market
    //  [ ] it swaps the reserves for MGST
    //  [ ] it repays the MGST loan
    //  [ ] it transfers all of the cvToken balance to the user
}
