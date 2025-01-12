// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.19;

import {HedgerTest} from "./HedgerTest.sol";

import {console2} from "forge-std/console2.sol";

contract HedgerDecreaseHedgeTest is HedgerTest {
    // given the cvToken is not whitelisted
    //  [X] it reverts
    // when reserves to supply and reserves to withdraw are both zero
    //  [X] it reverts
    // when the slippage check fails
    //  [X] it reverts
    // when reserves to withdraw is non-zero and reserves to supply is zero
    //  given the user has not approved Hedger to operate the Morpho position
    //   [ ] it succeeds
    //  [ ] it withdraws the reserves from the Morpho market
    //  [ ] it swaps the reserves for MGST
    //  [ ] it repays the MGST loan
    // when reserves to supply is non-zero and reserves to withdraw is zero
    //  given the caller has not approved this contract to spend the reserve token
    //   [X] it reverts
    //  [X] it transfers the reserves to the Hedger
    //  [X] it swaps the reserves for MGST
    //  [X] it repays the MGST loan
    // when reserves to supply and reserves to withdraw are both non-zero
    //  [ ] it transfers the reserves to the Hedger
    //  [ ] it withdraws the reserves from the Morpho market
    //  [ ] it swaps the reserves for MGST
    //  [ ] it repays the MGST loan

    function test_debtTokenIsNotWhitelisted_reverts()
        public
        givenUserHasAuthorizedHedger
        givenDebtTokenMorphoMarketIsCreated
    {
        // Expect revert
        _expectInvalidParam("cvToken");

        // Call
        vm.prank(USER);
        hedger.decreaseHedge(address(debtToken), 1e18, 0, _getMgstOut(1e18));
    }

    function test_reservesZero_reverts()
        public
        givenDebtTokenMorphoMarketIsCreated
        givenDebtTokenIsWhitelisted
        givenDebtTokenSpendingIsApproved(DEBT_TOKEN_AMOUNT)
        givenDebtTokenIsIssued(DEBT_TOKEN_AMOUNT)
        givenUserHasDepositedDebtToken(DEBT_TOKEN_AMOUNT)
        givenUserHasAuthorizedHedger
    {
        // Expect revert
        _expectInvalidParam("reserves");

        // Call
        vm.prank(USER);
        hedger.decreaseHedge(address(debtToken), 0, 0, _getMgstOut(1e18));
    }

    function test_reservesToSupply_spendingIsNotApproved_reverts()
        public
        givenDebtTokenMorphoMarketIsCreated
        givenDebtTokenIsWhitelisted
        givenDebtTokenSpendingIsApproved(DEBT_TOKEN_AMOUNT)
        givenDebtTokenIsIssued(DEBT_TOKEN_AMOUNT)
        givenUserHasDepositedDebtToken(DEBT_TOKEN_AMOUNT)
        givenUserHasAuthorizedHedger
        givenUserHasReserve(1e18)
    {
        // Expect revert
        _expectArithmeticError();

        // Call
        vm.prank(USER);
        hedger.decreaseHedge(address(debtToken), 1e18, 0, _getMgstOut(1e18));
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

        // Call
        vm.prank(USER);
        hedger.decreaseHedge(
            address(debtToken), reserveAmount, 0, _getMgstOut(reserveAmount) * 95 / 100
        );

        // Assertions
        _assertUserBalances(0, 0);
        _assertOperatorBalances(0, 0);
        _assertMorphoDebtTokenCollateral(DEBT_TOKEN_AMOUNT);
        _assertMorphoBorrowedLessThan(1e18);
    }

    function test_reservesToSupply_slippageCheckFails_reverts()
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

        // Expect revert
        vm.expectRevert("Too little received");

        // Call
        vm.prank(USER);
        hedger.decreaseHedge(
            address(debtToken), reserveAmount, 0, _getMgstOut(reserveAmount) * 100 / 100
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

        // TODO deposit reserves to MGST<>RESERVE market

        // Call
        vm.prank(USER);
        hedger.decreaseHedge(
            address(debtToken), 0, reserveAmount, _getMgstOut(reserveAmount) * 95 / 100
        );

        // Assertions
        _assertUserBalances(0, 0);
        _assertOperatorBalances(0, 0);
        _assertMorphoDebtTokenCollateral(DEBT_TOKEN_AMOUNT);
        _assertMorphoBorrowedLessThan(1e18);
    }
}
