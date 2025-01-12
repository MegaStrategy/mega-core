// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.19;

import {HedgerTest} from "./HedgerTest.sol";

contract HedgerDepositForTest is HedgerTest {
    // given the cvToken is not whitelisted
    //  [X] it reverts
    // given the caller has not approved this contract to spend the cvToken
    //  [X] it reverts
    // given the caller does not have sufficient balance of the cvToken
    //  [X] it reverts
    // given the user has not approved Hedger to operate the Morpho position
    //  [X] it transfers the cvToken to the Hedger from the caller
    //  [X] it deposits the cvToken into the Morpho market on behalf of the caller
    // given the caller is not an approved operator for the user
    //  [X] it transfers the cvToken to the Hedger from the caller
    //  [X] it deposits the cvToken into the Morpho market on behalf of the user
    // [X] it transfers the cvToken to the Hedger from the caller
    // [X] it deposits the cvToken into the Morpho market on behalf of the user

    function test_debtTokenNotWhitelisted_reverts() public givenUserHasApprovedOperator {
        // Expect revert
        _expectInvalidDebtToken();

        // Call
        vm.prank(OPERATOR);
        hedger.depositFor(debtToken, DEBT_TOKEN_AMOUNT, USER);
    }

    function test_debtTokenSpendingNotApproved_reverts()
        public
        givenDebtTokenMorphoMarketIsCreated
        givenDebtTokenIsWhitelisted
    {
        // Expect revert
        _expectArithmeticError();

        // Call
        vm.prank(OPERATOR);
        hedger.depositFor(debtToken, DEBT_TOKEN_AMOUNT, USER);
    }

    function test_debtTokenInsufficientBalance_reverts()
        public
        givenUserHasApprovedOperator
        givenDebtTokenMorphoMarketIsCreated
        givenDebtTokenIsWhitelisted
        givenOperatorDebtTokenSpendingIsApproved(DEBT_TOKEN_AMOUNT)
    {
        // Expect revert
        _expectArithmeticError();

        // Call
        vm.prank(OPERATOR);
        hedger.depositFor(debtToken, DEBT_TOKEN_AMOUNT, USER);
    }

    function test_userHasNotAuthorizedHedger()
        public
        givenDebtTokenMorphoMarketIsCreated
        givenDebtTokenIsWhitelisted
        givenOperatorDebtTokenSpendingIsApproved(DEBT_TOKEN_AMOUNT)
        givenOperatorDebtTokenIsIssued(DEBT_TOKEN_AMOUNT)
    {
        // Call
        vm.prank(OPERATOR);
        hedger.depositFor(debtToken, DEBT_TOKEN_AMOUNT, USER);

        // Assertions
        _assertUserBalances(0, 0);
        _assertOperatorBalances(0, 0);
        _assertMorphoDebtTokenCollateral(DEBT_TOKEN_AMOUNT);
    }

    function test_callerIsNotApprovedOperator()
        public
        givenDebtTokenMorphoMarketIsCreated
        givenDebtTokenIsWhitelisted
        givenOperatorDebtTokenSpendingIsApproved(DEBT_TOKEN_AMOUNT)
        givenOperatorDebtTokenIsIssued(DEBT_TOKEN_AMOUNT)
        givenUserHasAuthorizedHedger
    {
        // Call
        vm.prank(OPERATOR);
        hedger.depositFor(debtToken, DEBT_TOKEN_AMOUNT, USER);

        // Assertions
        _assertUserBalances(0, 0);
        _assertOperatorBalances(0, 0);
        _assertMorphoDebtTokenCollateral(DEBT_TOKEN_AMOUNT);
    }

    function test_depositFor()
        public
        givenDebtTokenMorphoMarketIsCreated
        givenDebtTokenIsWhitelisted
        givenOperatorDebtTokenSpendingIsApproved(DEBT_TOKEN_AMOUNT)
        givenOperatorDebtTokenIsIssued(DEBT_TOKEN_AMOUNT)
        givenUserHasAuthorizedHedger
        givenUserHasApprovedOperator
    {
        // Call
        vm.prank(OPERATOR);
        hedger.depositFor(debtToken, DEBT_TOKEN_AMOUNT, USER);

        // Assertions
        _assertUserBalances(0, 0);
        _assertOperatorBalances(0, 0);
        _assertMorphoDebtTokenCollateral(DEBT_TOKEN_AMOUNT);
    }
}
