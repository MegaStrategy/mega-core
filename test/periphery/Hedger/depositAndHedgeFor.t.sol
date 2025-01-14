// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.19;

import {HedgerTest} from "./HedgerTest.sol";

contract HedgerDepositAndHedgeForTest is HedgerTest {
    // given the cvToken is not whitelisted
    //  [X] it reverts
    // given the user has not approved Hedger to operate the Morpho position
    //  [X] it reverts
    // given the caller is not an approved operator for the user
    //  [X] it reverts
    // given the user has not approved this contract to spend the cvToken
    //  [X] it reverts
    // given the user does not have sufficient balance of the cvToken
    //  [X] it reverts
    // when the slippage check fails
    //  [X] it reverts
    // [X] it deposits the cvToken into the Morpho market on behalf of the user
    // [X] it borrows the hedge amount in MGST, swaps it for the reserve token, and deposits it into the Morpho market on behalf of the user

    function test_debtTokenNotWhitelisted_reverts()
        public
        givenDebtTokenMorphoMarketIsCreated
        givenUserHasApprovedOperator
    {
        uint256 hedgeAmount = _getMaximumHedgeAmount(DEBT_TOKEN_AMOUNT);
        uint256 minReserveOut = _getReserveOut(hedgeAmount);

        // Expect revert
        _expectInvalidDebtToken();

        // Call
        vm.prank(OPERATOR);
        hedger.depositAndHedgeFor(
            debtToken, DEBT_TOKEN_AMOUNT, hedgeAmount, minReserveOut * 95 / 100, USER
        );
    }

    function test_callerIsNotAnApprovedOperator_reverts()
        public
        givenDebtTokenMorphoMarketIsCreated
        givenUserHasApprovedOperator
        givenDebtTokenIsWhitelisted
    {
        uint256 hedgeAmount = _getMaximumHedgeAmount(DEBT_TOKEN_AMOUNT);
        uint256 minReserveOut = _getReserveOut(hedgeAmount);

        // Expect revert
        _expectInvalidOperator();

        // Call
        vm.prank(ADMIN);
        hedger.depositAndHedgeFor(
            debtToken, DEBT_TOKEN_AMOUNT, hedgeAmount, minReserveOut * 95 / 100, USER
        );
    }

    function test_debtTokenSpendingNotApproved_reverts()
        public
        givenDebtTokenMorphoMarketIsCreated
        givenDebtTokenIsWhitelisted
        givenUserHasApprovedOperator
    {
        uint256 hedgeAmount = _getMaximumHedgeAmount(DEBT_TOKEN_AMOUNT);
        uint256 minReserveOut = _getReserveOut(hedgeAmount);

        // Expect revert
        _expectArithmeticError();

        // Call
        vm.prank(OPERATOR);
        hedger.depositAndHedgeFor(
            debtToken, DEBT_TOKEN_AMOUNT, hedgeAmount, minReserveOut * 95 / 100, USER
        );
    }

    function test_debtTokenInsufficientBalance_reverts()
        public
        givenDebtTokenMorphoMarketIsCreated
        givenDebtTokenIsWhitelisted
        givenUserHasApprovedOperator
        givenOperatorDebtTokenSpendingIsApproved(DEBT_TOKEN_AMOUNT)
    {
        uint256 hedgeAmount = _getMaximumHedgeAmount(DEBT_TOKEN_AMOUNT);
        uint256 minReserveOut = _getReserveOut(hedgeAmount);

        // Expect revert
        _expectArithmeticError();

        // Call
        vm.prank(OPERATOR);
        hedger.depositAndHedgeFor(
            debtToken, DEBT_TOKEN_AMOUNT, hedgeAmount, minReserveOut * 95 / 100, USER
        );
    }

    function test_userHasNotAuthorizedHedger()
        public
        givenDebtTokenMorphoMarketIsCreated
        givenDebtTokenIsWhitelisted
        givenUserHasApprovedOperator
        givenOperatorDebtTokenSpendingIsApproved(DEBT_TOKEN_AMOUNT)
        givenOperatorDebtTokenIsIssued(DEBT_TOKEN_AMOUNT)
    {
        uint256 hedgeAmount = _getMaximumHedgeAmount(DEBT_TOKEN_AMOUNT);
        uint256 minReserveOut = _getReserveOut(hedgeAmount);

        // Expect revert
        _expectUnauthorized();

        // Call
        vm.prank(OPERATOR);
        hedger.depositAndHedgeFor(
            debtToken, DEBT_TOKEN_AMOUNT, hedgeAmount, minReserveOut * 95 / 100, USER
        );
    }

    function test_slippageCheckFails_reverts(
        uint256 hedgeAmount_
    )
        public
        givenDebtTokenMorphoMarketIsCreated
        givenDebtTokenMorphoMarketHasSupply(100e18)
        givenDebtTokenIsWhitelisted
        givenUserHasApprovedOperator
        givenOperatorDebtTokenSpendingIsApproved(DEBT_TOKEN_AMOUNT)
        givenOperatorDebtTokenIsIssued(DEBT_TOKEN_AMOUNT)
        givenUserHasAuthorizedHedger
    {
        uint256 maximumHedgeAmount = _getMaximumHedgeAmount(DEBT_TOKEN_AMOUNT);
        uint256 hedgeAmount = bound(hedgeAmount_, 1e18, maximumHedgeAmount);
        uint256 minReserveOut = _getReserveOut(hedgeAmount);

        // Expect revert
        vm.expectRevert("Too little received");

        // Call
        vm.prank(OPERATOR);
        hedger.depositAndHedgeFor(
            debtToken, DEBT_TOKEN_AMOUNT, hedgeAmount, minReserveOut * 100 / 100, USER
        );
    }

    function test_depositAndHedgeFor(
        uint256 hedgeAmount_
    )
        public
        givenDebtTokenMorphoMarketIsCreated
        givenDebtTokenMorphoMarketHasSupply(100e18)
        givenDebtTokenIsWhitelisted
        givenUserHasApprovedOperator
        givenOperatorDebtTokenSpendingIsApproved(DEBT_TOKEN_AMOUNT)
        givenOperatorDebtTokenIsIssued(DEBT_TOKEN_AMOUNT)
        givenUserHasAuthorizedHedger
    {
        uint256 maximumHedgeAmount = _getMaximumHedgeAmount(DEBT_TOKEN_AMOUNT);
        uint256 hedgeAmount = bound(hedgeAmount_, 1e18, maximumHedgeAmount);
        uint256 minReserveOut = _getReserveOut(hedgeAmount);

        // Call
        vm.prank(OPERATOR);
        hedger.depositAndHedgeFor(
            debtToken, DEBT_TOKEN_AMOUNT, hedgeAmount, minReserveOut * 95 / 100, USER
        );

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
