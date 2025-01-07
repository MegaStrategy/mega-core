// SPDX-License-Identifier: TBD
pragma solidity 0.8.19;

import {HedgerTest} from "./HedgerTest.sol";

contract AddCvTokenTest is HedgerTest {
    // given the caller is not the owner
    //  [ ] it reverts
    // given the cvToken is zero
    //  [ ] it reverts
    // given the cvMarket ID is zero
    //  [ ] it reverts
    // given the cvMarket ID does not correspond to the cvToken
    //  [ ] it reverts
    // given the cvMarket ID does not correspond to the MGST token
    //  [ ] it reverts
    // [ ] it adds the cvToken and cvMarket ID to the whitelist
}
