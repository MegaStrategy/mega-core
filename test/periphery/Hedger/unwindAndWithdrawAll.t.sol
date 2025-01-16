// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.19;

import {HedgerTest} from "./HedgerTest.sol";

contract HedgerUnwindAndWithdrawAllTest is HedgerTest {
    // given the cvToken is not whitelisted
    //  [X] it reverts
    // given the user has not approved Hedger to operate the Morpho position
    //  [X] it reverts
    // when reserves to supply and reserves to withdraw are both zero
    //  [X] it reverts
    // when the slippage check fails
    //  [X] it reverts
    // when reserves to withdraw is non-zero and reserves to supply is zero
    //  [X] it withdraws the reserves from the Morpho market
    //  [X] it swaps the reserves for MGST
    //  [X] it repays the MGST loan
    //  [X] it transfers all of the cvToken balance to the user
    // when reserves to supply is non-zero and reserves to withdraw is zero
    //  given the caller has not approved this contract to spend the reserve token
    //   [X] it reverts
    //  [X] it transfers the reserves to the Hedger
    //  [X] it swaps the reserves for MGST
    //  [X] it repays the MGST loan
    //  [X] it transfers all of the cvToken balance to the user
    // when reserves to supply and reserves to withdraw are both non-zero
    //  [X] it transfers the reserves to the Hedger
    //  [X] it withdraws the reserves from the Morpho market
    //  [X] it swaps the reserves for MGST
    //  [X] it repays the MGST loan
    //  [X] it transfers all of the cvToken balance to the user

    function test_cvTokenIsNotWhitelisted_reverts()
        public
        givenUserHasAuthorizedHedger
        givenDebtTokenMorphoMarketIsCreated
    {
        // Expect revert
        _expectInvalidParam("cvToken");

        // Call
        vm.prank(USER);
        hedger.unwindAndWithdrawAll(address(debtToken), 0, 0);
    }

    function test_reservesToSupplyAndWithdrawAreZero_reverts()
        public
        givenDebtTokenMorphoMarketIsCreated
        givenDebtTokenIsWhitelisted
        givenDebtTokenSpendingIsApproved(DEBT_TOKEN_AMOUNT)
        givenDebtTokenIsIssued(DEBT_TOKEN_AMOUNT)
        givenUserHasDepositedDebtToken(DEBT_TOKEN_AMOUNT)
        givenUserHasAuthorizedHedger
        givenDebtTokenMorphoMarketHasSupply(100e18)
        givenUserHasIncreasedMgstHedge(1e18)
    {
        // Expect revert
        _expectInvalidParam("reserves");

        // Call
        vm.prank(USER);
        hedger.unwindAndWithdrawAll(address(debtToken), 0, 0);
    }

    function test_userHasNotApprovedHedger_reverts()
        public
        givenDebtTokenMorphoMarketIsCreated
        givenDebtTokenIsWhitelisted
        givenDebtTokenSpendingIsApproved(DEBT_TOKEN_AMOUNT)
        givenDebtTokenIsIssued(DEBT_TOKEN_AMOUNT)
        givenUserHasDepositedDebtToken(DEBT_TOKEN_AMOUNT)
        givenUserHasAuthorizedHedger
        givenDebtTokenMorphoMarketHasSupply(100e18)
        givenUserHasIncreasedMgstHedge(1e18)
        givenUserHasUnauthorizedHedger
    {
        uint256 mgstBorrowed = hedger.getHedgePositionFor(address(debtToken), USER);
        uint256 reservesRequired = hedger.previewDecreaseHedge(address(debtToken), mgstBorrowed);

        // Mint reserve to the user
        _mintReserve(reservesRequired);
        _approveReserveSpendingByHedger(reservesRequired);

        // Expect revert
        _expectUnauthorized();

        // Call
        vm.prank(USER);
        hedger.unwindAndWithdrawAll(address(debtToken), reservesRequired, 0);
    }

    function test_reservesToSupply_callerSpendingNotApproved_reverts()
        public
        givenDebtTokenMorphoMarketIsCreated
        givenDebtTokenIsWhitelisted
        givenDebtTokenSpendingIsApproved(DEBT_TOKEN_AMOUNT)
        givenDebtTokenIsIssued(DEBT_TOKEN_AMOUNT)
        givenUserHasDepositedDebtToken(DEBT_TOKEN_AMOUNT)
        givenUserHasAuthorizedHedger
        givenDebtTokenMorphoMarketHasSupply(100e18)
        givenUserHasIncreasedMgstHedge(1e18)
    {
        uint256 mgstBorrowed = hedger.getHedgePositionFor(address(debtToken), USER);
        uint256 reservesRequired = hedger.previewDecreaseHedge(address(debtToken), mgstBorrowed);

        // Mint reserve to the user
        // Do not approve spending
        _mintReserve(reservesRequired);

        // Expect revert
        _expectArithmeticError();

        // Call
        vm.prank(USER);
        hedger.unwindAndWithdrawAll(address(debtToken), reservesRequired, 0);
    }

    function test_reservesToSupply()
        public
        givenDebtTokenMorphoMarketIsCreated
        givenDebtTokenIsWhitelisted
        givenDebtTokenSpendingIsApproved(DEBT_TOKEN_AMOUNT)
        givenDebtTokenIsIssued(DEBT_TOKEN_AMOUNT)
        givenUserHasDepositedDebtToken(DEBT_TOKEN_AMOUNT)
        givenUserHasAuthorizedHedger
        givenDebtTokenMorphoMarketHasSupply(100e18)
        givenUserHasIncreasedMgstHedge(1e18)
    {
        uint256 mgstBorrowed = hedger.getHedgePositionFor(address(debtToken), USER);
        uint256 reservesRequired = hedger.previewDecreaseHedge(address(debtToken), mgstBorrowed);

        // Mint reserve to the user
        _mintReserve(reservesRequired);
        _approveReserveSpendingByHedger(reservesRequired);

        // Call
        vm.prank(USER);
        hedger.unwindAndWithdrawAll(address(debtToken), reservesRequired, 0);

        // Assert
        _assertUserReserveBalanceLt(reservesRequired);
        _assertUserDebtTokenBalance(DEBT_TOKEN_AMOUNT);
        _assertOperatorBalances(0, 0);
        _assertMorphoDebtTokenCollateral(0);
        _assertMorphoReserveBalance(0);
        _assertMorphoBorrowed(0);
    }

    function test_reservesToSupply_slippageCheck_reverts()
        public
        givenDebtTokenMorphoMarketIsCreated
        givenDebtTokenIsWhitelisted
        givenDebtTokenSpendingIsApproved(DEBT_TOKEN_AMOUNT)
        givenDebtTokenIsIssued(DEBT_TOKEN_AMOUNT)
        givenUserHasDepositedDebtToken(DEBT_TOKEN_AMOUNT)
        givenUserHasAuthorizedHedger
        givenDebtTokenMorphoMarketHasSupply(100e18)
        givenUserHasIncreasedMgstHedge(1e18)
    {
        uint256 mgstBorrowed = hedger.getHedgePositionFor(address(debtToken), USER);
        uint256 reservesRequired =
            hedger.previewDecreaseHedge(address(debtToken), mgstBorrowed) * 95 / 100;

        // Mint reserve to the user
        _mintReserve(reservesRequired);
        _approveReserveSpendingByHedger(reservesRequired);

        // Expect revert
        _expectSafeTransferFailure();

        // Call
        vm.prank(USER);
        hedger.unwindAndWithdrawAll(address(debtToken), reservesRequired, 0);
    }

    function test_reservesToWithdraw()
        public
        givenDebtTokenMorphoMarketIsCreated
        givenDebtTokenIsWhitelisted
        givenDebtTokenSpendingIsApproved(DEBT_TOKEN_AMOUNT)
        givenDebtTokenIsIssued(DEBT_TOKEN_AMOUNT)
        givenUserHasDepositedDebtToken(DEBT_TOKEN_AMOUNT)
        givenUserHasAuthorizedHedger
        givenDebtTokenMorphoMarketHasSupply(100e18)
        givenUserHasIncreasedMgstHedge(1e18)
    {
        uint256 mgstBorrowed = hedger.getHedgePositionFor(address(debtToken), USER);
        uint256 reservesRequired = hedger.previewDecreaseHedge(address(debtToken), mgstBorrowed);

        // Deposit reserves to MGST<>RESERVE market
        _mintReserve(reservesRequired);
        _approveMorphoReserveDeposit(reservesRequired);
        _depositReservesToMorphoMarket(reservesRequired);

        // Call
        vm.prank(USER);
        hedger.unwindAndWithdrawAll(address(debtToken), 0, reservesRequired);

        // Assert
        _assertUserReserveBalanceLt(reservesRequired);
        _assertUserDebtTokenBalance(DEBT_TOKEN_AMOUNT);
        _assertOperatorBalances(0, 0);
        _assertMorphoDebtTokenCollateral(0);
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
        givenDebtTokenMorphoMarketHasSupply(100e18)
        givenUserHasIncreasedMgstHedge(1e18)
    {
        uint256 mgstBorrowed = hedger.getHedgePositionFor(address(debtToken), USER);
        uint256 reservesRequired = hedger.previewDecreaseHedge(address(debtToken), mgstBorrowed);
        uint256 reservesToSupply = reservesRequired / 3;
        uint256 reservesToWithdraw = reservesRequired - reservesToSupply;

        // Mint reserve to the user
        _mintReserve(reservesToSupply);
        _approveReserveSpendingByHedger(reservesToSupply);

        // Deposit reserves to MGST<>RESERVE market
        _mintReserve(reservesToWithdraw);
        _approveMorphoReserveDeposit(reservesToWithdraw);
        _depositReservesToMorphoMarket(reservesToWithdraw);

        // Call
        vm.prank(USER);
        hedger.unwindAndWithdrawAll(address(debtToken), reservesToSupply, reservesToWithdraw);

        // Assert
        _assertUserReserveBalanceLt(reservesRequired);
        _assertUserDebtTokenBalance(DEBT_TOKEN_AMOUNT);
        _assertOperatorBalances(0, 0);
        _assertMorphoDebtTokenCollateral(0);
        _assertMorphoReserveBalance(0);
        _assertMorphoBorrowed(0);
    }
}
