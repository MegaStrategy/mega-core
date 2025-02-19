// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import {HedgerTest} from "./HedgerTest.sol";

contract HedgerWithdrawReservesTest is HedgerTest {
    // given the amount is zero
    //  [X] it reverts
    // given the user has not approved Hedger to operate the Morpho position
    //  [X] it reverts
    // given the caller is not an approved operator for the user
    //  [X] it reverts
    // given the user's position does not have sufficient balance of the reserve token
    //  [X] it reverts
    // [X] it withdraws the reserves from the MGST<>RESERVE market and transfers them to the user

    function test_amountZero_reverts()
        public
        givenUserHasAuthorizedHedger
        givenUserHasApprovedOperator
        givenUserHasReserve(100e18)
        givenUserHasApprovedMorphoReserveDeposit(100e18)
        givenUserHasDepositedReserves(100e18)
    {
        // Expect revert
        _expectInvalidParam("amount");

        // Call
        vm.prank(OPERATOR);
        hedger.withdrawReservesFor(0, USER);
    }

    function test_userHasNotAuthorizedHedger_reverts()
        public
        givenUserHasAuthorizedHedger
        givenUserHasApprovedOperator
        givenUserHasReserve(100e18)
        givenUserHasApprovedMorphoReserveDeposit(100e18)
        givenUserHasDepositedReserves(100e18)
        givenUserHasUnauthorizedHedger
    {
        // Expect revert
        _expectUnauthorized();

        // Call
        vm.prank(OPERATOR);
        hedger.withdrawReservesFor(100e18, USER);
    }

    function test_insufficientBalance_reverts()
        public
        givenUserHasAuthorizedHedger
        givenUserHasApprovedOperator
        givenUserHasReserve(100e18)
        givenUserHasApprovedMorphoReserveDeposit(100e18)
        givenUserHasDepositedReserves(100e18)
    {
        // Expect revert
        _expectArithmeticError();

        // Call
        vm.prank(OPERATOR);
        hedger.withdrawReservesFor(100e18 + 1, USER);
    }

    function test_callerIsNotApprovedOperator_reverts()
        public
        givenUserHasAuthorizedHedger
        givenUserHasReserve(100e18)
        givenUserHasApprovedMorphoReserveDeposit(100e18)
        givenUserHasDepositedReserves(100e18)
    {
        // Expect revert
        _expectInvalidOperator();

        // Call
        vm.prank(OPERATOR);
        hedger.withdrawReservesFor(100e18, USER);
    }

    function test_withdrawReserves()
        public
        givenUserHasAuthorizedHedger
        givenUserHasApprovedOperator
        givenUserHasReserve(100e18)
        givenUserHasApprovedMorphoReserveDeposit(100e18)
        givenUserHasDepositedReserves(100e18)
    {
        // Call
        vm.prank(OPERATOR);
        hedger.withdrawReservesFor(100e18, USER);

        // Assert
        _assertUserBalances(100e18, 0);
        _assertOperatorBalances(0, 0);
    }
}
