// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.19;

import {HedgerTest} from "./HedgerTest.sol";

contract HedgerIncreaseHedgeForTest is HedgerTest {
    // given the cvToken is not whitelisted
    //  [X] it reverts
    // given the user has not approved Hedger to operate the Morpho position
    //  [X] it reverts
    // given the caller is not an approved operator for the user
    //  [X] it reverts
    // when the hedge amount is zero
    //  [X] it reverts
    // when the slippage check fails
    //  [X] it reverts
    // [X] it borrows the hedge amount in MGST, swaps it for the reserve token, and deposits it into the Morpho market on behalf of the user

    function test_cvTokenIsNotWhitelisted_reverts()
        public
        givenUserHasAuthorizedHedger
        givenUserHasApprovedOperator
    {
        // Expect revert
        _expectInvalidParam("cvToken");

        // Call
        vm.prank(OPERATOR);
        hedger.increaseHedgeFor(address(reserve), DEBT_TOKEN_AMOUNT, 18e18, USER);
    }

    function test_userHasNotAuthorizedHedger_reverts()
        public
        givenDebtTokenMorphoMarketIsCreated
        givenDebtTokenIsWhitelisted
        givenDebtTokenSpendingIsApproved(DEBT_TOKEN_AMOUNT)
        givenDebtTokenIsIssued(DEBT_TOKEN_AMOUNT)
        givenUserHasDepositedDebtToken(DEBT_TOKEN_AMOUNT)
        givenUserHasApprovedOperator
    {
        // Expect revert
        _expectUnauthorized();

        // Call
        vm.prank(OPERATOR);
        hedger.increaseHedgeFor(address(debtToken), DEBT_TOKEN_AMOUNT, 18e18, USER);
    }

    function test_callerIsNotApprovedOperator_reverts()
        public
        givenDebtTokenMorphoMarketIsCreated
        givenDebtTokenIsWhitelisted
        givenDebtTokenSpendingIsApproved(DEBT_TOKEN_AMOUNT)
        givenDebtTokenIsIssued(DEBT_TOKEN_AMOUNT)
        givenUserHasDepositedDebtToken(DEBT_TOKEN_AMOUNT)
        givenUserHasAuthorizedHedger
    {
        // Expect revert
        _expectInvalidOperator();

        // Call
        vm.prank(OPERATOR);
        hedger.increaseHedgeFor(address(debtToken), DEBT_TOKEN_AMOUNT, 18e18, USER);
    }

    function test_hedgeAmountIsZero_reverts()
        public
        givenDebtTokenMorphoMarketIsCreated
        givenDebtTokenIsWhitelisted
        givenDebtTokenSpendingIsApproved(DEBT_TOKEN_AMOUNT)
        givenDebtTokenIsIssued(DEBT_TOKEN_AMOUNT)
        givenUserHasDepositedDebtToken(DEBT_TOKEN_AMOUNT)
        givenUserHasAuthorizedHedger
        givenUserHasApprovedOperator
    {
        // Expect revert
        _expectInvalidParam("hedgeAmount");

        // Call
        vm.prank(OPERATOR);
        hedger.increaseHedgeFor(address(debtToken), 0, 18e18, USER);
    }

    function test_increaseHedge_slippageCheck_reverts(
        uint256 hedgeAmount_
    )
        public
        givenDebtTokenMorphoMarketIsCreated
        givenDebtTokenIsWhitelisted
        givenDebtTokenSpendingIsApproved(DEBT_TOKEN_AMOUNT)
        givenDebtTokenIsIssued(DEBT_TOKEN_AMOUNT)
        givenUserHasDepositedDebtToken(DEBT_TOKEN_AMOUNT)
        givenUserHasAuthorizedHedger
        givenUserHasApprovedOperator
        givenDebtTokenMorphoMarketHasSupply(100e18)
    {
        uint256 maximumHedgeAmount = _getMaximumHedgeAmount(DEBT_TOKEN_AMOUNT);
        uint256 hedgeAmount = bound(hedgeAmount_, 1e18, maximumHedgeAmount);

        // Calculate the minimum reserve amount out
        uint256 minReserveOut = _getReserveOut(hedgeAmount);

        // Expect revert
        vm.expectRevert("Too little received");

        // Call
        vm.prank(OPERATOR);
        hedger.increaseHedgeFor(address(debtToken), hedgeAmount, minReserveOut * 100 / 100, USER);
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
        givenUserHasApprovedOperator
        givenDebtTokenMorphoMarketHasSupply(100e18)
    {
        uint256 maximumHedgeAmount = _getMaximumHedgeAmount(DEBT_TOKEN_AMOUNT);
        uint256 hedgeAmount = bound(hedgeAmount_, 1e18, maximumHedgeAmount);

        // Calculate the minimum reserve amount out
        uint256 minReserveOut = _getReserveOut(hedgeAmount);

        // Check the maximum hedge amount
        assertEq(
            hedger.maxIncreaseHedgeFor(address(debtToken), USER),
            maximumHedgeAmount,
            "maxIncreaseHedgeFor"
        );

        // Call
        vm.prank(OPERATOR);
        hedger.increaseHedgeFor(address(debtToken), hedgeAmount, minReserveOut * 95 / 100, USER);

        // Assertions
        _assertUserBalances(0, 0);
        _assertOperatorBalances(0, 0);
        _assertMorphoDebtTokenCollateral(DEBT_TOKEN_AMOUNT);
        _assertMorphoBorrowed(hedgeAmount);

        // Check the maximum hedge amount after
        assertEq(
            hedger.maxIncreaseHedgeFor(address(debtToken), USER),
            maximumHedgeAmount - hedgeAmount,
            "maxIncreaseHedgeFor"
        );
    }
}
