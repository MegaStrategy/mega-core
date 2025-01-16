// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.19;

import {HedgerTest} from "./HedgerTest.sol";

contract HedgerWithdrawAllTest is HedgerTest {
    // given the cvToken is not whitelisted
    //  [X] it reverts
    // given the user has not approved Hedger to operate the Morpho position
    //  [X] it reverts
    // given the caller is not an approved operator for the user
    //  [X] it reverts
    // [X] it withdraws all of the collateral from the Morpho market to the user

    function test_cvTokenIsNotWhitelisted_reverts()
        public
        givenDebtTokenMorphoMarketIsCreated
        givenDebtTokenMorphoMarketHasSupply(100e18)
        givenUserHasAuthorizedHedger
        givenUserHasApprovedOperator
    {
        // Expect revert
        _expectInvalidParam("cvToken");

        // Call
        vm.prank(OPERATOR);
        hedger.withdrawAllFor(debtToken, USER);
    }

    function test_userHasNotAuthorizedHedger_reverts()
        public
        givenDebtTokenMorphoMarketIsCreated
        givenDebtTokenMorphoMarketHasSupply(100e18)
        givenDebtTokenIsWhitelisted
        givenUserHasAuthorizedHedger
        givenUserHasApprovedOperator
        givenDebtTokenIsIssued(DEBT_TOKEN_AMOUNT)
        givenDebtTokenSpendingIsApproved(DEBT_TOKEN_AMOUNT)
        givenUserHasDepositedDebtToken(DEBT_TOKEN_AMOUNT)
        givenUserHasUnauthorizedHedger
    {
        // Expect revert
        _expectUnauthorized();

        // Call
        vm.prank(OPERATOR);
        hedger.withdrawAllFor(debtToken, USER);
    }

    function test_callerIsNotAnApprovedOperator_reverts()
        public
        givenDebtTokenMorphoMarketIsCreated
        givenDebtTokenMorphoMarketHasSupply(100e18)
        givenDebtTokenIsWhitelisted
        givenUserHasAuthorizedHedger
        givenUserHasApprovedOperator
        givenDebtTokenIsIssued(DEBT_TOKEN_AMOUNT)
        givenDebtTokenSpendingIsApproved(DEBT_TOKEN_AMOUNT)
        givenUserHasDepositedDebtToken(DEBT_TOKEN_AMOUNT)
        givenUserHasUnauthorizedHedger
    {
        // Expect revert
        _expectInvalidOperator();

        // Call
        vm.prank(ADMIN);
        hedger.withdrawAllFor(debtToken, USER);
    }

    function test_withdrawAll()
        public
        givenDebtTokenMorphoMarketIsCreated
        givenDebtTokenMorphoMarketHasSupply(100e18)
        givenDebtTokenIsWhitelisted
        givenUserHasAuthorizedHedger
        givenUserHasApprovedOperator
        givenDebtTokenIsIssued(DEBT_TOKEN_AMOUNT)
        givenDebtTokenSpendingIsApproved(DEBT_TOKEN_AMOUNT)
        givenUserHasDepositedDebtToken(DEBT_TOKEN_AMOUNT)
    {
        // Call
        vm.prank(OPERATOR);
        hedger.withdrawAllFor(debtToken, USER);

        // Assertions
        _assertUserBalances(0, DEBT_TOKEN_AMOUNT);
        _assertOperatorBalances(0, 0);
        _assertMorphoDebtTokenCollateral(0);
    }
}
