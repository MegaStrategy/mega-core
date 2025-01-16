// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.19;

import {HedgerTest} from "./HedgerTest.sol";

contract HedgerWithdrawTest is HedgerTest {
    // given the cvToken is not whitelisted
    //  [X] it reverts
    // given the user has not approved Hedger to operate the Morpho position
    //  [X] it reverts
    // given the amount is greater than the user's balance of the cvToken
    //  [X] it reverts
    // [X] it withdraws the collateral from the Morpho market to the caller

    function test_cvTokenIsNotWhitelisted_reverts()
        public
        givenDebtTokenMorphoMarketIsCreated
        givenDebtTokenMorphoMarketHasSupply(100e18)
        givenDebtTokenIsWhitelisted
        givenUserHasAuthorizedHedger
    {
        // Expect revert
        _expectInvalidParam("cvToken");

        // Call
        vm.prank(USER);
        hedger.withdraw(address(reserve), DEBT_TOKEN_AMOUNT);
    }

    function test_userHasNotAuthorizedHedger()
        public
        givenDebtTokenMorphoMarketIsCreated
        givenDebtTokenMorphoMarketHasSupply(100e18)
        givenDebtTokenIsWhitelisted
        givenUserHasAuthorizedHedger
        givenDebtTokenIsIssued(DEBT_TOKEN_AMOUNT)
        givenDebtTokenSpendingIsApproved(DEBT_TOKEN_AMOUNT)
        givenUserHasDepositedDebtToken(DEBT_TOKEN_AMOUNT)
        givenUserHasUnauthorizedHedger
    {
        // Expect revert
        _expectUnauthorized();

        // Call
        vm.prank(USER);
        hedger.withdraw(debtToken, DEBT_TOKEN_AMOUNT);
    }

    function test_insufficientBalance_reverts()
        public
        givenDebtTokenMorphoMarketIsCreated
        givenDebtTokenMorphoMarketHasSupply(100e18)
        givenDebtTokenIsWhitelisted
        givenUserHasAuthorizedHedger
        givenDebtTokenIsIssued(DEBT_TOKEN_AMOUNT)
    {
        // Expect revert
        _expectArithmeticError();

        // Call
        vm.prank(USER);
        hedger.withdraw(debtToken, DEBT_TOKEN_AMOUNT);
    }

    function test_withdraw()
        public
        givenDebtTokenMorphoMarketIsCreated
        givenDebtTokenMorphoMarketHasSupply(100e18)
        givenDebtTokenIsWhitelisted
        givenUserHasAuthorizedHedger
        givenDebtTokenIsIssued(DEBT_TOKEN_AMOUNT)
        givenDebtTokenSpendingIsApproved(DEBT_TOKEN_AMOUNT)
        givenUserHasDepositedDebtToken(DEBT_TOKEN_AMOUNT)
    {
        // Call
        vm.prank(USER);
        hedger.withdraw(debtToken, DEBT_TOKEN_AMOUNT);

        // Assertions
        _assertUserBalances(0, DEBT_TOKEN_AMOUNT);
        _assertOperatorBalances(0, 0);
        _assertMorphoDebtTokenCollateral(0);
    }
}
