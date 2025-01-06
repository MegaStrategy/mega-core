// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.19;

import {HedgerTest} from "./HedgerTest.sol";

contract HedgerWithdrawForTest is HedgerTest {
    // given the cvToken is not whitelisted
    //  [ ] it reverts
    // given the caller is not an approved operator for the user
    //  [ ] it reverts
    // [ ] it withdraws the collateral from the Morpho market to the user
}
