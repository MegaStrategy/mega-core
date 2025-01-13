// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.19;

import {HedgerTest} from "./HedgerTest.sol";

contract HedgerUnwindAndWithdrawTest is HedgerTest {
    // given the cvToken is not whitelisted
    //  [X] it reverts
    // given the user has not approved Hedger to operate the Morpho position
    //  [X] it reverts
    // when the amount is zero
    //  [X] it reverts
    // when reserves to supply and reserves to withdraw are both zero
    //  [X] it reverts
    // when the slippage check fails
    //  [X] it reverts
    // given the amount is greater than the user's balance of the cvToken
    //  [X] it reverts
    // when reserves to withdraw is non-zero and reserves to supply is zero
    //  [X] it withdraws the reserves from the Morpho market
    //  [X] it swaps the reserves for MGST
    //  [X] it repays the MGST loan
    //  [X] it transfers the cvToken to the user
    // when reserves to supply is non-zero and reserves to withdraw is zero
    //  given the caller has not approved this contract to spend the reserve token
    //   [X] it reverts
    //  [X] it transfers the reserves to the Hedger
    //  [X] it swaps the reserves for MGST
    //  [X] it repays the MGST loan
    //  [X] it transfers the cvToken to the user
    // when reserves to supply and reserves to withdraw are both non-zero
    //  [X] it transfers the reserves to the Hedger
    //  [X] it withdraws the reserves from the Morpho market
    //  [X] it swaps the reserves for MGST
    //  [X] it repays the MGST loan
    //  [X] it transfers the cvToken to the user

    function test_cvTokenIsNotWhitelisted_reverts()
        public
        givenUserHasAuthorizedHedger
        givenDebtTokenMorphoMarketIsCreated
    {
        // Expect revert
        _expectInvalidParam("cvToken");

        // Call
        vm.prank(USER);
        hedger.unwindAndWithdraw(address(debtToken), 0, 0, 0, 0);
    }

    function test_amountIsZero_reverts()
        public
        givenDebtTokenMorphoMarketIsCreated
        givenDebtTokenIsWhitelisted
        givenDebtTokenSpendingIsApproved(DEBT_TOKEN_AMOUNT)
        givenDebtTokenIsIssued(DEBT_TOKEN_AMOUNT)
        givenUserHasDepositedDebtToken(DEBT_TOKEN_AMOUNT)
        givenUserHasAuthorizedHedger
        givenDebtTokenMorphoMarketHasSupply(100e18)
        givenUserHasIncreasedMgstHedge(1e18)
        givenUserHasReserve(_getReserveOut(1e18))
        givenReserveSpendingIsApproved(_getReserveOut(1e18))
    {
        uint256 reserveAmount = _getReserveOut(1e18);
        uint256 minMgstOut = _getMgstOut(reserveAmount);

        // Expect revert
        _expectInvalidParam("amount");

        // Call
        vm.prank(USER);
        hedger.unwindAndWithdraw(address(debtToken), 0, reserveAmount, 0, minMgstOut * 95 / 100);
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
        givenUserHasReserve(_getReserveOut(1e18))
        givenReserveSpendingIsApproved(_getReserveOut(1e18))
    {
        uint256 reserveAmount = _getReserveOut(1e18);
        uint256 minMgstOut = _getMgstOut(reserveAmount);

        // Expect revert
        _expectInvalidParam("reserves");

        // Call
        vm.prank(USER);
        hedger.unwindAndWithdraw(address(debtToken), DEBT_TOKEN_AMOUNT, 0, 0, minMgstOut * 95 / 100);
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
        givenUserHasReserve(_getReserveOut(1e18))
        givenReserveSpendingIsApproved(_getReserveOut(1e18))
        givenUserHasUnauthorizedHedger
    {
        uint256 reserveAmount = _getReserveOut(1e18);
        uint256 minMgstOut = _getMgstOut(reserveAmount);

        // Expect revert
        _expectUnauthorized();

        // Call
        vm.prank(USER);
        hedger.unwindAndWithdraw(
            address(debtToken), DEBT_TOKEN_AMOUNT, reserveAmount, 0, minMgstOut * 95 / 100
        );
    }

    function test_insufficientDebtTokenBalance_reverts()
        public
        givenDebtTokenMorphoMarketIsCreated
        givenDebtTokenIsWhitelisted
        givenDebtTokenSpendingIsApproved(DEBT_TOKEN_AMOUNT)
        givenDebtTokenIsIssued(DEBT_TOKEN_AMOUNT)
        givenUserHasDepositedDebtToken(DEBT_TOKEN_AMOUNT)
        givenUserHasAuthorizedHedger
        givenDebtTokenMorphoMarketHasSupply(100e18)
        givenUserHasIncreasedMgstHedge(1e18)
        givenUserHasReserve(_getReserveOut(1e18))
        givenReserveSpendingIsApproved(_getReserveOut(1e18))
    {
        uint256 reserveAmount = _getReserveOut(1e18);
        uint256 minMgstOut = _getMgstOut(reserveAmount);

        // Expect revert
        _expectArithmeticError();

        // Call
        vm.prank(USER);
        hedger.unwindAndWithdraw(
            address(debtToken), DEBT_TOKEN_AMOUNT + 1, reserveAmount, 0, minMgstOut * 95 / 100
        );
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
        givenUserHasReserve(_getReserveOut(1e18))
    {
        uint256 reserveAmount = _getReserveOut(1e18);
        uint256 minMgstOut = _getMgstOut(reserveAmount);
        uint256 debtTokenAmount = 1e18;

        // Expect revert
        _expectArithmeticError();

        // Call
        vm.prank(USER);
        hedger.unwindAndWithdraw(
            address(debtToken), debtTokenAmount, reserveAmount, 0, minMgstOut * 95 / 100
        );
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
        givenUserHasReserve(_getReserveOut(1e18))
        givenReserveSpendingIsApproved(_getReserveOut(1e18))
    {
        uint256 reserveAmount = _getReserveOut(1e18);
        uint256 minMgstOut = _getMgstOut(reserveAmount);
        uint256 debtTokenAmount = 1e18;

        // Call
        vm.prank(USER);
        hedger.unwindAndWithdraw(
            address(debtToken), debtTokenAmount, reserveAmount, 0, minMgstOut * 95 / 100
        );

        // Assert
        _assertUserBalances(0, debtTokenAmount);
        _assertOperatorBalances(0, 0);
        _assertMorphoDebtTokenCollateral(DEBT_TOKEN_AMOUNT - debtTokenAmount);
        _assertMorphoReserveBalance(0);
        _assertMorphoBorrowedLessThan(1e18);
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
        givenUserHasReserve(_getReserveOut(1e18))
        givenReserveSpendingIsApproved(_getReserveOut(1e18))
    {
        uint256 reserveAmount = _getReserveOut(1e18);
        uint256 minMgstOut = _getMgstOut(reserveAmount);
        uint256 debtTokenAmount = 1e18;

        // Expect revert
        vm.expectRevert("Too little received");

        // Call
        vm.prank(USER);
        hedger.unwindAndWithdraw(
            address(debtToken), debtTokenAmount, reserveAmount, 0, minMgstOut * 100 / 100
        );
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
        uint256 reserveAmount = _getReserveOut(1e18);
        uint256 minMgstOut = _getMgstOut(reserveAmount);
        uint256 debtTokenAmount = 1e18;

        // Deposit reserves to MGST<>RESERVE market
        _mintReserve(reserveAmount);
        _approveMorphoReserveDeposit(reserveAmount);
        _depositReservesToMorphoMarket(reserveAmount);

        // Call
        vm.prank(USER);
        hedger.unwindAndWithdraw(
            address(debtToken), debtTokenAmount, 0, reserveAmount, minMgstOut * 95 / 100
        );

        // Assert
        _assertUserBalances(0, debtTokenAmount);
        _assertOperatorBalances(0, 0);
        _assertMorphoDebtTokenCollateral(DEBT_TOKEN_AMOUNT - debtTokenAmount);
        _assertMorphoReserveBalance(0);
        _assertMorphoBorrowedLessThan(1e18);
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
        uint256 reserveAmount = _getReserveOut(1e18);
        uint256 minMgstOut = _getMgstOut(reserveAmount);

        uint256 reservesToSupply = reserveAmount / 3;
        uint256 reservesToWithdraw = reserveAmount - reservesToSupply;

        uint256 debtTokenAmount = 1e18;

        // Mint reserve to the user
        _mintReserve(reservesToSupply);
        _approveReserveSpendingByHedger(reservesToSupply);

        // Deposit reserves to MGST<>RESERVE market
        _mintReserve(reservesToWithdraw);
        _approveMorphoReserveDeposit(reservesToWithdraw);
        _depositReservesToMorphoMarket(reservesToWithdraw);

        // Call
        vm.prank(USER);
        hedger.unwindAndWithdraw(
            address(debtToken),
            debtTokenAmount,
            reservesToSupply,
            reservesToWithdraw,
            minMgstOut * 95 / 100
        );

        // Assert
        _assertUserBalances(0, debtTokenAmount);
        _assertOperatorBalances(0, 0);
        _assertMorphoDebtTokenCollateral(DEBT_TOKEN_AMOUNT - debtTokenAmount);
        _assertMorphoReserveBalance(0);
        _assertMorphoBorrowedLessThan(1e18);
    }
}
