// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.19;

import {HedgerTest} from "./HedgerTest.sol";

contract HedgerWithdrawAllTest is HedgerTest {
    // given the cvToken is not whitelisted
    //  [ ] it reverts
    // [ ] it withdraws all of the collateral from the Morpho market to the caller
}
