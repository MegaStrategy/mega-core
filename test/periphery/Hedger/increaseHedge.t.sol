// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.19;

import {HedgerTest} from "./HedgerTest.sol";

contract HedgerIncreaseHedgeTest is HedgerTest {
    // given the cvToken is not whitelisted
    //  [X] it reverts
    // when the hedge amount is zero
    //  [X] it reverts
    // given the user has not approved Hedger to operate the Morpho position
    //  [X] it reverts
    // when the slippage check fails
    //  [ ] it reverts
    // [ ] it borrows the hedge amount in MGST, swaps it for the reserve token, and deposits it into the Morpho market on behalf of the caller

    // TODO what if the hedge amount is greater than the user's debt token balance?

    function test_cvTokenIsNotWhitelisted_reverts() public {
        // Expect revert
        _expectInvalidParam("cvToken");

        // Call
        vm.prank(USER);
        hedger.increaseHedge(address(reserve), DEBT_TOKEN_AMOUNT, 18e18);
    }

    function test_hedgeAmountIsZero_reverts()
        public
        givenDebtTokenMorphoMarketIsCreated
        givenDebtTokenIsWhitelisted
        givenDebtTokenSpendingIsApproved(DEBT_TOKEN_AMOUNT)
        givenDebtTokenIsIssued(DEBT_TOKEN_AMOUNT)
        givenUserHasDepositedDebtToken(DEBT_TOKEN_AMOUNT)
    {
        // Expect revert
        _expectInvalidParam("hedgeAmount");

        // Call
        vm.prank(USER);
        hedger.increaseHedge(address(debtToken), 0, 18e18);
    }

    function test_userHasNotAuthorizedHedger_reverts()
        public
        givenDebtTokenMorphoMarketIsCreated
        givenDebtTokenIsWhitelisted
        givenDebtTokenSpendingIsApproved(DEBT_TOKEN_AMOUNT)
        givenDebtTokenIsIssued(DEBT_TOKEN_AMOUNT)
        givenUserHasDepositedDebtToken(DEBT_TOKEN_AMOUNT)
    {
        // Expect revert
        _expectUnauthorized();

        // Call
        vm.prank(USER);
        hedger.increaseHedge(address(debtToken), DEBT_TOKEN_AMOUNT, 18e18);
    }

    function test_increaseHedge(
        uint256 hedgeAmount_
    )
        public
        givenDebtTokenMorphoMarketIsCreated
        givenDebtTokenIsWhitelisted
        givenDebtTokenSpendingIsApproved(DEBT_TOKEN_AMOUNT)
        givenDebtTokenIsIssued(DEBT_TOKEN_AMOUNT)
        givenUserHasDepositedDebtToken(DEBT_TOKEN_AMOUNT)
        givenUserHasAuthorizedHedger
        givenDebtTokenMorphoMarketHasSupply(100e18)
    {
        uint256 maximumHedgeAmount = _getMaximumHedgeAmount(DEBT_TOKEN_AMOUNT);
        uint256 hedgeAmount = bound(hedgeAmount_, 1e18, maximumHedgeAmount);

        // Calculate the minimum reserve amount out
        uint256 minReserveOut = _getReserveOut(hedgeAmount);

        // Call
        vm.prank(USER);
        hedger.increaseHedge(address(debtToken), hedgeAmount, minReserveOut * 99 / 100);

        // Assertions
        _assertUserBalances(0, 0);
        _assertOperatorBalances(0, 0);
        _assertMorphoDebtTokenCollateral(DEBT_TOKEN_AMOUNT);
        _assertMorphoBorrowed(hedgeAmount);
    }
}
