// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import {HedgerTest} from "./HedgerTest.sol";

contract HedgerDecreaseHedgeForTest is HedgerTest {
    // given the cvToken is not whitelisted
    //  [X] it reverts
    // given the caller is not an approved operator for the user
    //  [X] it reverts
    // when reserves to supply and reserves to withdraw are both zero
    //  [X] it reverts
    // when the slippage check fails
    //  [X] it reverts
    // when reserves to withdraw is non-zero and reserves to supply is zero
    //  given the user has not approved Hedger to operate the Morpho position
    //   [X] it reverts
    //  [X] it withdraws the reserves from the Morpho market
    //  [X] it swaps the reserves for MGST
    //  [X] it repays the MGST loan
    // when reserves to supply is non-zero and reserves to withdraw is zero
    //  given the user has not approved this contract to spend the reserve token
    //   [X] it reverts
    //  [X] it transfers the reserves to the Hedger from the user
    //  [X] it swaps the reserves for MGST
    //  [X] it repays the MGST loan
    // when reserves to supply and reserves to withdraw are both non-zero
    //  [X] it transfers the reserves to the Hedger from the user
    //  [X] it withdraws the reserves from the Morpho market
    //  [X] it swaps the reserves for MGST
    //  [X] it repays the MGST loan

    function test_debtTokenIsNotWhitelisted_reverts()
        public
        givenUserHasAuthorizedHedger
        givenUserHasApprovedOperator
        givenDebtTokenMorphoMarketIsCreated
    {
        // Expect revert
        _expectInvalidParam("cvToken");

        // Call
        vm.prank(OPERATOR);
        hedger.decreaseHedgeFor(address(debtToken), 1e18, 0, _getMgstOut(1e18), USER);
    }

    function test_callerIsNotAnApprovedOperator_reverts()
        public
        givenUserHasAuthorizedHedger
        givenUserHasApprovedOperator
        givenDebtTokenMorphoMarketIsCreated
    {
        // Expect revert
        _expectInvalidOperator();

        // Call
        vm.prank(ADMIN);
        hedger.decreaseHedgeFor(address(debtToken), 1e18, 0, _getMgstOut(1e18), USER);
    }

    function test_reservesZero_reverts()
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
        _expectInvalidParam("reserves");

        // Call
        vm.prank(OPERATOR);
        hedger.decreaseHedgeFor(address(debtToken), 0, 0, _getMgstOut(1e18), USER);
    }

    function test_reservesToSupply_spendingIsNotApproved_reverts()
        public
        givenDebtTokenMorphoMarketIsCreated
        givenDebtTokenIsWhitelisted
        givenDebtTokenSpendingIsApproved(DEBT_TOKEN_AMOUNT)
        givenDebtTokenIsIssued(DEBT_TOKEN_AMOUNT)
        givenUserHasDepositedDebtToken(DEBT_TOKEN_AMOUNT)
        givenUserHasAuthorizedHedger
        givenUserHasApprovedOperator
        givenOperatorHasReserve(1e18)
    {
        // Expect revert
        _expectArithmeticError();

        // Call
        vm.prank(OPERATOR);
        hedger.decreaseHedgeFor(address(debtToken), 1e18, 0, _getMgstOut(1e18), USER);
    }

    function test_reservesToSupply()
        public
        givenDebtTokenMorphoMarketIsCreated
        givenDebtTokenIsWhitelisted
        givenDebtTokenSpendingIsApproved(DEBT_TOKEN_AMOUNT)
        givenDebtTokenIsIssued(DEBT_TOKEN_AMOUNT)
        givenUserHasDepositedDebtToken(DEBT_TOKEN_AMOUNT)
        givenUserHasAuthorizedHedger
        givenUserHasApprovedOperator
        givenDebtTokenMorphoMarketHasSupply(100e18)
        givenUserHasIncreasedMgstHedge(1e18)
    {
        uint256 mgstBorrowed = 1e18;
        uint256 reserveAmount = _getReserveOut(mgstBorrowed) * 105 / 100;

        // Mint reserve to the user
        _mintReserve(reserveAmount);
        _approveReserveSpendingByHedger(reserveAmount);

        // Call
        vm.prank(OPERATOR);
        hedger.decreaseHedgeFor(address(debtToken), reserveAmount, 0, mgstBorrowed, USER);

        // Assertions
        _assertUserReserveBalanceLt(reserveAmount);
        _assertUserDebtTokenBalance(0);
        _assertOperatorBalances(0, 0);
        _assertMorphoDebtTokenCollateral(DEBT_TOKEN_AMOUNT);
        _assertMorphoBorrowed(0);
    }

    function test_reservesToSupply_slippageCheckFails_reverts()
        public
        givenDebtTokenMorphoMarketIsCreated
        givenDebtTokenIsWhitelisted
        givenDebtTokenSpendingIsApproved(DEBT_TOKEN_AMOUNT)
        givenDebtTokenIsIssued(DEBT_TOKEN_AMOUNT)
        givenUserHasDepositedDebtToken(DEBT_TOKEN_AMOUNT)
        givenUserHasAuthorizedHedger
        givenUserHasApprovedOperator
        givenDebtTokenMorphoMarketHasSupply(100e18)
        givenUserHasIncreasedMgstHedge(1e18)
    {
        uint256 mgstBorrowed = 1e18;
        uint256 reserveAmount = _getReserveOut(mgstBorrowed) * 100 / 100;

        // Mint reserve to the user
        _mintReserve(reserveAmount);
        _approveReserveSpendingByHedger(reserveAmount);

        // Expect revert
        _expectSafeTransferFailure();

        // Call
        vm.prank(OPERATOR);
        hedger.decreaseHedgeFor(address(debtToken), reserveAmount, 0, mgstBorrowed, USER);
    }

    function test_reservesToWithdraw_hedgerNotAuthorized_reverts()
        public
        givenDebtTokenMorphoMarketIsCreated
        givenDebtTokenIsWhitelisted
        givenDebtTokenSpendingIsApproved(DEBT_TOKEN_AMOUNT)
        givenDebtTokenIsIssued(DEBT_TOKEN_AMOUNT)
        givenUserHasDepositedDebtToken(DEBT_TOKEN_AMOUNT)
        givenUserHasAuthorizedHedger
        givenUserHasApprovedOperator
        givenDebtTokenMorphoMarketHasSupply(100e18)
        givenUserHasIncreasedMgstHedge(1e18)
    {
        uint256 mgstBorrowed = 1e18;
        uint256 reserveAmount = _getReserveOut(mgstBorrowed) * 105 / 100;

        // Deposit reserves to MGST<>RESERVE market
        _mintReserve(reserveAmount);
        _approveMorphoReserveDeposit(reserveAmount);
        _depositReservesToMorphoMarket(reserveAmount);

        // Revoke authorization for Hedger
        vm.prank(USER);
        morpho.setAuthorization(address(hedger), false);

        // Expect revert
        _expectUnauthorized();

        // Call
        vm.prank(OPERATOR);
        hedger.decreaseHedgeFor(address(debtToken), 0, reserveAmount, mgstBorrowed, USER);
    }

    function test_reservesToWithdraw()
        public
        givenDebtTokenMorphoMarketIsCreated
        givenDebtTokenIsWhitelisted
        givenDebtTokenSpendingIsApproved(DEBT_TOKEN_AMOUNT)
        givenDebtTokenIsIssued(DEBT_TOKEN_AMOUNT)
        givenUserHasDepositedDebtToken(DEBT_TOKEN_AMOUNT)
        givenUserHasAuthorizedHedger
        givenUserHasApprovedOperator
        givenDebtTokenMorphoMarketHasSupply(100e18)
        givenUserHasIncreasedMgstHedge(1e18)
    {
        uint256 mgstBorrowed = 1e18;
        uint256 reserveAmount = _getReserveOut(mgstBorrowed) * 105 / 100;

        // Deposit reserves to MGST<>RESERVE market
        _mintReserve(reserveAmount);
        _approveMorphoReserveDeposit(reserveAmount);
        _depositReservesToMorphoMarket(reserveAmount);

        // Call
        vm.prank(OPERATOR);
        hedger.decreaseHedgeFor(address(debtToken), 0, reserveAmount, mgstBorrowed, USER);

        // Assertions
        _assertUserReserveBalanceLt(reserveAmount);
        _assertUserDebtTokenBalance(0);
        _assertOperatorBalances(0, 0);
        _assertMorphoDebtTokenCollateral(DEBT_TOKEN_AMOUNT);
        _assertMorphoReserveBalance(0);
        _assertMorphoBorrowed(0);
    }

    function test_reservesToSupply_reservesToWithdraw()
        public
        givenDebtTokenMorphoMarketIsCreated
        givenDebtTokenIsWhitelisted
        givenDebtTokenSpendingIsApproved(DEBT_TOKEN_AMOUNT)
        givenDebtTokenIsIssued(DEBT_TOKEN_AMOUNT)
        givenUserHasDepositedDebtToken(DEBT_TOKEN_AMOUNT)
        givenUserHasAuthorizedHedger
        givenUserHasApprovedOperator
        givenDebtTokenMorphoMarketHasSupply(100e18)
        givenUserHasIncreasedMgstHedge(1e18)
    {
        uint256 mgstBorrowed = 1e18;
        uint256 reserveAmount = _getReserveOut(mgstBorrowed) * 105 / 100;

        uint256 reservesToSupply = reserveAmount / 3;
        uint256 reservesToWithdraw = reserveAmount - reservesToSupply;

        // Mint reserve to the user
        _mintReserve(reservesToSupply);
        _approveReserveSpendingByHedger(reservesToSupply);

        // Deposit reserves to MGST<>RESERVE market
        _mintReserve(reservesToWithdraw);
        _approveMorphoReserveDeposit(reservesToWithdraw);
        _depositReservesToMorphoMarket(reservesToWithdraw);

        uint256 maxHedgeBefore = hedger.maxIncreaseHedgeFor(address(debtToken), USER);
        uint256 reservesRequired = hedger.previewDecreaseHedge(address(debtToken), mgstBorrowed);

        // Call
        vm.prank(OPERATOR);
        hedger.decreaseHedgeFor(
            address(debtToken), reservesToSupply, reservesToWithdraw, mgstBorrowed, USER
        );

        // Assertions
        _assertUserReserveBalanceLt(reserveAmount);
        _assertUserDebtTokenBalance(0);
        _assertOperatorBalances(0, 0);
        _assertMorphoDebtTokenCollateral(DEBT_TOKEN_AMOUNT);
        _assertMorphoReserveBalance(0);
        _assertMorphoBorrowed(0);

        // Check the maximum hedge amount after
        assertEq(
            hedger.maxIncreaseHedgeFor(address(debtToken), USER),
            maxHedgeBefore + mgstBorrowed,
            "maxDecreaseHedgeFor"
        );

        // Check the reserves required
        assertEq(
            reservesRequired, reserveAmount - reserve.balanceOf(address(USER)), "reservesRequired"
        );
    }
}
