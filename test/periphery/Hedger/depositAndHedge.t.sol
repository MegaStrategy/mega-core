// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.19;

import {HedgerTest} from "./HedgerTest.sol";

contract HedgerDepositAndHedgeTest is HedgerTest {
    // given the cvToken is not whitelisted
    //  [X] it reverts
    // given the user has not approved Hedger to operate the Morpho position
    //  [X] it reverts
    // given the user has not approved this contract to spend the cvToken
    //  [X] it reverts
    // given the user does not have sufficient balance of the cvToken
    //  [X] it reverts
    // when the slippage check fails
    //  [X] it reverts
    // [X] it deposits the cvToken into the Morpho market on behalf of the user
    // [X] it borrows the hedge amount in MGST, swaps it for the reserve token, and deposits it into the Morpho market on behalf of the user

    function test_debtTokenNotWhitelisted_reverts() public {
        uint256 hedgeAmount = _getMaximumHedgeAmount(DEBT_TOKEN_AMOUNT);
        uint256 minReserveOut = _getReserveOut(hedgeAmount);

        // Expect revert
        _expectInvalidDebtToken();

        // Call
        vm.prank(USER);
        hedger.depositAndHedge(debtToken, DEBT_TOKEN_AMOUNT, hedgeAmount, minReserveOut * 95 / 100);
    }

    function test_debtTokenSpendingNotApproved_reverts()
        public
        givenDebtTokenMorphoMarketIsCreated
        givenDebtTokenIsWhitelisted
    {
        uint256 hedgeAmount = _getMaximumHedgeAmount(DEBT_TOKEN_AMOUNT);
        uint256 minReserveOut = _getReserveOut(hedgeAmount);

        // Expect revert
        _expectArithmeticError();

        // Call
        vm.prank(USER);
        hedger.depositAndHedge(debtToken, DEBT_TOKEN_AMOUNT, hedgeAmount, minReserveOut * 95 / 100);
    }

    function test_debtTokenInsufficientBalance_reverts()
        public
        givenDebtTokenMorphoMarketIsCreated
        givenDebtTokenIsWhitelisted
        givenDebtTokenSpendingIsApproved(DEBT_TOKEN_AMOUNT)
    {
        uint256 hedgeAmount = _getMaximumHedgeAmount(DEBT_TOKEN_AMOUNT);
        uint256 minReserveOut = _getReserveOut(hedgeAmount);

        // Expect revert
        _expectArithmeticError();

        // Call
        vm.prank(USER);
        hedger.depositAndHedge(debtToken, DEBT_TOKEN_AMOUNT, hedgeAmount, minReserveOut * 95 / 100);
    }

    function test_userHasNotAuthorizedHedger()
        public
        givenDebtTokenMorphoMarketIsCreated
        givenDebtTokenIsWhitelisted
        givenDebtTokenSpendingIsApproved(DEBT_TOKEN_AMOUNT)
        givenDebtTokenIsIssued(DEBT_TOKEN_AMOUNT)
    {
        uint256 hedgeAmount = _getMaximumHedgeAmount(DEBT_TOKEN_AMOUNT);
        uint256 minReserveOut = _getReserveOut(hedgeAmount);

        // Expect revert
        _expectUnauthorized();

        // Call
        vm.prank(USER);
        hedger.depositAndHedge(debtToken, DEBT_TOKEN_AMOUNT, hedgeAmount, minReserveOut * 95 / 100);
    }

    function test_slippageCheckFails_reverts(
        uint256 hedgeAmount_
    )
        public
        givenDebtTokenMorphoMarketIsCreated
        givenDebtTokenMorphoMarketHasSupply(100e18)
        givenDebtTokenIsWhitelisted
        givenDebtTokenSpendingIsApproved(DEBT_TOKEN_AMOUNT)
        givenDebtTokenIsIssued(DEBT_TOKEN_AMOUNT)
        givenUserHasAuthorizedHedger
    {
        uint256 maximumHedgeAmount = _getMaximumHedgeAmount(DEBT_TOKEN_AMOUNT);
        uint256 hedgeAmount = bound(hedgeAmount_, 1e18, maximumHedgeAmount);
        uint256 minReserveOut = _getReserveOut(hedgeAmount);

        // Expect revert
        vm.expectRevert("Too little received");

        // Call
        vm.prank(USER);
        hedger.depositAndHedge(debtToken, DEBT_TOKEN_AMOUNT, hedgeAmount, minReserveOut * 100 / 100);
    }

    function test_depositAndHedge(
        uint256 hedgeAmount_
    )
        public
        givenDebtTokenMorphoMarketIsCreated
        givenDebtTokenMorphoMarketHasSupply(100e18)
        givenDebtTokenIsWhitelisted
        givenDebtTokenSpendingIsApproved(DEBT_TOKEN_AMOUNT)
        givenDebtTokenIsIssued(DEBT_TOKEN_AMOUNT)
        givenUserHasAuthorizedHedger
    {
        uint256 maximumHedgeAmount = _getMaximumHedgeAmount(DEBT_TOKEN_AMOUNT);
        uint256 hedgeAmount = bound(hedgeAmount_, 1e18, maximumHedgeAmount);
        uint256 minReserveOut = _getReserveOut(hedgeAmount);

        // Call
        vm.prank(USER);
        hedger.depositAndHedge(debtToken, DEBT_TOKEN_AMOUNT, hedgeAmount, minReserveOut * 95 / 100);

        // Assertions
        _assertUserBalances(0, 0);
        _assertOperatorBalances(0, 0);
        _assertMorphoDebtTokenCollateral(DEBT_TOKEN_AMOUNT);
        _assertMorphoBorrowed(hedgeAmount);
    }
}
