// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.19;

import {HedgerTest} from "./HedgerTest.sol";

contract HedgerDepositTest is HedgerTest {
    // given the cvToken is not whitelisted
    //  [X] it reverts
    // given the caller has not approved this contract to spend the cvToken
    //  [X] it reverts
    // given the caller does not have sufficient balance of the cvToken
    //  [X] it reverts
    // [X] it transfers the cvToken to the Hedger from the caller
    // [X] it deposits the cvToken into the Morpho market on behalf of the caller

    function test_debtTokenNotWhitelisted_reverts() public {
        // Expect revert
        _expectInvalidDebtToken();

        // Call
        vm.prank(USER);
        hedger.deposit(debtToken, DEBT_TOKEN_AMOUNT);
    }

    function test_debtTokenSpendingNotApproved_reverts() public givenDebtTokenIsWhitelisted {
        // Expect revert
        vm.expectRevert("TRANSFER_FROM_FAILED");

        // Call
        vm.prank(USER);
        hedger.deposit(debtToken, DEBT_TOKEN_AMOUNT);
    }

    function test_debtTokenInsufficientBalance_reverts()
        public
        givenDebtTokenIsWhitelisted
        givenDebtTokenSpendingIsApproved(DEBT_TOKEN_AMOUNT)
    {
        // Expect revert
        vm.expectRevert("TRANSFER_FROM_FAILED");

        // Call
        vm.prank(USER);
        hedger.deposit(debtToken, DEBT_TOKEN_AMOUNT);
    }

    function test_deposit()
        public
        givenDebtTokenIsWhitelisted
        givenDebtTokenSpendingIsApproved(DEBT_TOKEN_AMOUNT)
        givenDebtTokenIsIssued(DEBT_TOKEN_AMOUNT)
    {
        // Call
        vm.prank(USER);
        hedger.deposit(debtToken, DEBT_TOKEN_AMOUNT);

        // Assertions
        _assertUserBalances(0, 0);
        _assertMorphoCollateral(DEBT_TOKEN_AMOUNT);
    }
}
