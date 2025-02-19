// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import {HedgerTest} from "./HedgerTest.sol";

contract HedgerWithdrawAllTest is HedgerTest {
    // given the cvToken is not whitelisted
    //  [X] it reverts
    // given the user has not approved Hedger to operate the Morpho position
    //  [X] it reverts
    // [X] it withdraws all of the collateral from the Morpho market to the caller

    function test_cvTokenIsNotWhitelisted_reverts()
        public
        givenDebtTokenMorphoMarketIsCreated
        givenDebtTokenMorphoMarketHasSupply(100e18)
        givenUserHasAuthorizedHedger
    {
        // Expect revert
        _expectInvalidParam("cvToken");

        // Call
        vm.prank(USER);
        hedger.withdrawAll(debtToken);
    }

    function test_userHasNotAuthorizedHedger_reverts()
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
        hedger.withdrawAll(debtToken);
    }

    function test_withdrawAll()
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
        hedger.withdrawAll(debtToken);

        // Assertions
        _assertUserBalances(0, DEBT_TOKEN_AMOUNT);
        _assertOperatorBalances(0, 0);
        _assertMorphoDebtTokenCollateral(0);
    }
}
