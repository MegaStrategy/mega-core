// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.19;

import {HedgerTest} from "./HedgerTest.sol";

contract HedgerWithdrawReservesTest is HedgerTest {
    // given the amount is zero
    //  [X] it reverts
    // given the user has not approved Hedger to operate the Morpho position
    //  [X] it reverts
    // given the user's position does not have sufficient balance of the reserve token
    //  [X] it reverts
    // [X] it withdraws the reserves from the MGST<>RESERVE market and transfers them to the caller

    function test_amountZero_reverts()
        public
        givenUserHasAuthorizedHedger
        givenUserHasReserve(100e18)
        givenUserHasApprovedMorphoReserveDeposit(100e18)
        givenUserHasDepositedReserves(100e18)
    {
        // Expect revert
        _expectInvalidParam("amount");

        // Call
        vm.prank(USER);
        hedger.withdrawReserves(0);
    }

    function test_userHasNotAuthorizedHedger_reverts()
        public
        givenUserHasAuthorizedHedger
        givenUserHasReserve(100e18)
        givenUserHasApprovedMorphoReserveDeposit(100e18)
        givenUserHasDepositedReserves(100e18)
        givenUserHasUnauthorizedHedger
    {
        // Expect revert
        _expectUnauthorized();

        // Call
        vm.prank(USER);
        hedger.withdrawReserves(100e18);
    }

    function test_insufficientBalance_reverts()
        public
        givenUserHasAuthorizedHedger
        givenUserHasReserve(100e18)
        givenUserHasApprovedMorphoReserveDeposit(100e18)
        givenUserHasDepositedReserves(100e18)
    {
        // Expect revert
        _expectArithmeticError();

        // Call
        vm.prank(USER);
        hedger.withdrawReserves(100e18 + 1);
    }

    function test_withdrawReserves()
        public
        givenUserHasAuthorizedHedger
        givenUserHasReserve(100e18)
        givenUserHasApprovedMorphoReserveDeposit(100e18)
        givenUserHasDepositedReserves(100e18)
    {
        // Call
        vm.prank(USER);
        hedger.withdrawReserves(100e18);

        // Assert
        _assertUserBalances(100e18, 0);
        _assertOperatorBalances(0, 0);
    }
}
