// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Banker} from "src/policies/Banker.sol";

import {BankerTest} from "./BankerTest.sol";

contract BankerAuctionTest is BankerTest {
    // ======= Modifiers ======= //

    // ======= Tests ======= //

    // when the policy is not active
    // [X] it reverts
    // when the caller is not permissioned
    // [ ] it reverts
    // when the auction parameters are invalid
    // [ ] it reverts
    // given the curator fee has not been set
    // [ ] it reverts
    // when the maturity date is now or in the past
    // [ ] it reverts
    // given the parameters are valid
    // [ ] it creates an EMP auction with the given auction parameters
    // [ ] the AuctionHouse receives the capacity in debt tokens
    // [ ] the policy is the curator
    // [ ] the policy has accepted curation
    // [ ] the DebtAuction event is emitted

    function test_policyNotActive() public {
        vm.expectRevert(Banker.Inactive.selector);

        // Call
        vm.prank(manager);
        banker.auction(debtTokenParams, auctionParams);
    }
}
