// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.19;

import {HedgerTest} from "./HedgerTest.sol";

contract HedgerDepositTest is HedgerTest {
    // given the cvToken is not whitelisted
    //  [ ] it reverts
    // given the caller has not approved this contract to spend the cvToken
    //  [ ] it reverts
    // given the caller does not have sufficient balance of the cvToken
    //  [ ] it reverts
    // [ ] it transfers the cvToken to the Hedger from the caller
    // [ ] it deposits the cvToken into the Morpho market on behalf of the caller
}
