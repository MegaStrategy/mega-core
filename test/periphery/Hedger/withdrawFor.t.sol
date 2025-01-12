// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.19;

import {HedgerTest} from "./HedgerTest.sol";
import {stdError} from "forge-std/StdError.sol";

contract HedgerWithdrawForTest is HedgerTest {
    // given the cvToken is not whitelisted
    //  [ ] it reverts
    // given the user has not approved Hedger to operate the Morpho position
    //  [ ] it reverts
    // given the caller is not an approved operator for the user
    //  [ ] it reverts
    // [ ] it withdraws the collateral from the Morpho market to the user

    function test_cvTokenIsNotWhitelisted_reverts()
        public
        givenDebtTokenMorphoMarketIsCreated
        givenDebtTokenMorphoMarketHasSupply(100e18)
        givenDebtTokenIsWhitelisted
        givenUserHasApprovedOperator
        givenUserHasAuthorizedHedger
    {
        // Expect revert
        _expectInvalidParam("cvToken");

        // Call
        vm.prank(OPERATOR);
        hedger.withdrawFor(address(reserve), DEBT_TOKEN_AMOUNT, USER);
    }

    function test_userHasNotAuthorizedHedger()
        public
        givenDebtTokenMorphoMarketIsCreated
        givenDebtTokenMorphoMarketHasSupply(100e18)
        givenDebtTokenIsWhitelisted
        givenUserHasApprovedOperator
        givenUserHasAuthorizedHedger
        givenDebtTokenIsIssued(DEBT_TOKEN_AMOUNT)
        givenDebtTokenSpendingIsApproved(DEBT_TOKEN_AMOUNT)
        givenUserHasDepositedDebtToken(DEBT_TOKEN_AMOUNT)
        givenUserHasUnauthorizedHedger
    {
        // Expect revert
        _expectUnauthorized();

        // Call
        vm.prank(OPERATOR);
        hedger.withdrawFor(debtToken, DEBT_TOKEN_AMOUNT, USER);
    }

    function test_callerIsNotAnApprovedOperator_reverts()
        public
        givenDebtTokenMorphoMarketIsCreated
        givenDebtTokenMorphoMarketHasSupply(100e18)
        givenDebtTokenIsWhitelisted
        givenUserHasAuthorizedHedger
        givenDebtTokenIsIssued(DEBT_TOKEN_AMOUNT)
        givenDebtTokenSpendingIsApproved(DEBT_TOKEN_AMOUNT)
        givenUserHasDepositedDebtToken(DEBT_TOKEN_AMOUNT)
    {
        // Expect revert
        _expectInvalidOperator();

        // Call
        vm.prank(OPERATOR);
        hedger.withdrawFor(debtToken, DEBT_TOKEN_AMOUNT, USER);
    }

    function test_insufficientBalance_reverts()
        public
        givenDebtTokenMorphoMarketIsCreated
        givenDebtTokenMorphoMarketHasSupply(100e18)
        givenDebtTokenIsWhitelisted
        givenUserHasApprovedOperator
        givenUserHasAuthorizedHedger
        givenDebtTokenIsIssued(DEBT_TOKEN_AMOUNT)
    {
        // Expect revert
        vm.expectRevert(stdError.arithmeticError);

        // Call
        vm.prank(OPERATOR);
        hedger.withdrawFor(debtToken, DEBT_TOKEN_AMOUNT, USER);
    }

    function test_withdrawFor()
        public
        givenDebtTokenMorphoMarketIsCreated
        givenDebtTokenMorphoMarketHasSupply(100e18)
        givenDebtTokenIsWhitelisted
        givenUserHasApprovedOperator
        givenUserHasAuthorizedHedger
        givenDebtTokenIsIssued(DEBT_TOKEN_AMOUNT)
        givenDebtTokenSpendingIsApproved(DEBT_TOKEN_AMOUNT)
        givenUserHasDepositedDebtToken(DEBT_TOKEN_AMOUNT)
    {
        // Call
        vm.prank(OPERATOR);
        hedger.withdrawFor(debtToken, DEBT_TOKEN_AMOUNT, USER);

        // Assertions
        _assertUserBalances(0, DEBT_TOKEN_AMOUNT);
        _assertOperatorBalances(0, 0);
        _assertMorphoDebtTokenCollateral(0);
    }
}
