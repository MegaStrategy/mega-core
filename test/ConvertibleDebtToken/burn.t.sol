// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import {stdError} from "@forge-std/StdError.sol";

import {ConvertibleDebtTokenTest} from "./ConvertibleDebtTokenTest.sol";

contract BurnTest is ConvertibleDebtTokenTest {
    // ========== TESTS ========== //
    // when the caller does not have enough balance
    //  [X] it reverts
    // when the caller is the issuer
    //  [X] it burns the correct amount from the caller
    // when the caller has not provided enough allowance
    //  [X] it burns the correct amount from the caller
    // [X] it burns the correct amount from the caller

    function test_callerIsIssuer() public givenTokenIsCreated givenMinted(OWNER, 100) {
        vm.prank(OWNER);
        cdt.burn(99);

        assertEq(cdt.balanceOf(OWNER), 1, "balanceOf(OWNER)");
        assertEq(cdt.totalSupply(), 1, "totalSupply");
    }

    function test_insufficientBalance_reverts() public givenTokenIsCreated givenMinted(USER, 100) {
        vm.expectRevert(stdError.arithmeticError);

        vm.prank(USER);
        cdt.burn(101);
    }

    function test_insufficientAllowance() public givenTokenIsCreated givenMinted(USER, 100) {
        // No allowance

        vm.prank(USER);
        cdt.burn(99);

        // Assert
        assertEq(cdt.balanceOf(USER), 1, "balanceOf(USER)");
        assertEq(cdt.totalSupply(), 1, "totalSupply");
        assertEq(cdt.allowance(USER, OWNER), 0, "allowance(USER, OWNER)");
    }

    function test_success() public givenTokenIsCreated givenMinted(USER, 100) {
        // Set allowance
        vm.prank(USER);
        cdt.approve(OWNER, 99);

        vm.prank(USER);
        cdt.burn(99);

        // Assert
        assertEq(cdt.balanceOf(USER), 1, "balanceOf(USER)");
        assertEq(cdt.totalSupply(), 1, "totalSupply");
        assertEq(cdt.allowance(USER, OWNER), 99, "allowance(USER, OWNER)");
    }
}
