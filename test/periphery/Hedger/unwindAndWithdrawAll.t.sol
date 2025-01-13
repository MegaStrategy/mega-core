// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.19;

import {HedgerTest} from "./HedgerTest.sol";

import {console2} from "forge-std/console2.sol";
import {Position as MorphoPosition, Market as MorphoMarket} from "morpho-blue-1.0.0/interfaces/IMorpho.sol";

contract HedgerUnwindAndWithdrawAllTest is HedgerTest {
    // given the cvToken is not whitelisted
    //  [X] it reverts
    // given the user has not approved Hedger to operate the Morpho position
    //  [X] it reverts
    // when reserves to supply and reserves to withdraw are both zero
    //  [X] it reverts
    // when the slippage check fails
    //  [ ] it reverts
    // when reserves to withdraw is non-zero and reserves to supply is zero
    //  [ ] it withdraws the reserves from the Morpho market
    //  [ ] it swaps the reserves for MGST
    //  [ ] it repays the MGST loan
    //  [ ] it transfers all of the cvToken balance to the user
    // when reserves to supply is non-zero and reserves to withdraw is zero
    //  given the caller has not approved this contract to spend the reserve token
    //   [X] it reverts
    //  [ ] it transfers the reserves to the Hedger
    //  [ ] it swaps the reserves for MGST
    //  [ ] it repays the MGST loan
    //  [ ] it transfers all of the cvToken balance to the user
    // when reserves to supply and reserves to withdraw are both non-zero
    //  [ ] it transfers the reserves to the Hedger
    //  [ ] it withdraws the reserves from the Morpho market
    //  [ ] it swaps the reserves for MGST
    //  [ ] it repays the MGST loan
    //  [ ] it transfers all of the cvToken balance to the user

    function test_cvTokenIsNotWhitelisted_reverts()
        public
        givenUserHasAuthorizedHedger
        givenDebtTokenMorphoMarketIsCreated
    {
        // Expect revert
        _expectInvalidParam("cvToken");

        // Call
        vm.prank(USER);
        hedger.unwindAndWithdrawAll(address(debtToken), 0, 0, 0);
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
        hedger.unwindAndWithdrawAll(address(debtToken), 0, 0, minMgstOut * 95 / 100);
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
        hedger.unwindAndWithdrawAll(address(debtToken), reserveAmount, 0, minMgstOut * 95 / 100);
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

        // Expect revert
        _expectArithmeticError();

        // Call
        vm.prank(USER);
        hedger.unwindAndWithdrawAll(address(debtToken), reserveAmount, 0, minMgstOut * 95 / 100);
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
        givenUserHasReserve(_getReserveOut(2e18))
        givenReserveSpendingIsApproved(_getReserveOut(2e18))
    {
        uint256 reserveAmount = _getReserveOut(2e18);
        uint256 mgstBorrowed = 1e18;

        // Check the borrow amount
        MorphoPosition memory position = morpho.position(debtTokenMarket, USER);
        console2.log("borrow", position.borrowShares);
        MorphoMarket memory market = morpho.market(debtTokenMarket);
        console2.log("total borrow assets", market.totalBorrowAssets);
        console2.log("total borrow shares", market.totalBorrowShares);

        // Call
        vm.prank(USER);
        hedger.unwindAndWithdrawAll(address(debtToken), reserveAmount, 0, mgstBorrowed);

        // Assert
        _assertUserBalances(0, DEBT_TOKEN_AMOUNT);
        _assertOperatorBalances(0, 0);
        _assertMorphoDebtTokenCollateral(0);
        _assertMorphoReserveBalance(0);
        _assertMorphoBorrowedLessThan(1e18);
    }
}
