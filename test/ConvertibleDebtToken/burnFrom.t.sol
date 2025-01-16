// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {stdError} from "@forge-std/StdError.sol";

import {ConvertibleDebtTokenTest} from "./ConvertibleDebtTokenTest.sol";
import {ConvertibleDebtToken} from "src/lib/ConvertibleDebtToken.sol";

contract BurnFromTest is ConvertibleDebtTokenTest {
    // when the caller is not the issuer
    //  [X] it reverts
    // when the from address has not provided any allowance
    //  [X] it reverts
    // when the from address has not provided enough allowance
    //  [X] it reverts
    // when the allowance is the max value
    //  [X] it does not change the allowance
    // [X] it burns the correct amount from the from address
    // [X] the total supply is reduced by the correct amount
    // [X] the allowance is reduced by the correct amount

    function test_callerIsNotIssuer_reverts() public givenTokenIsCreated {
        vm.expectRevert(abi.encodeWithSelector(ConvertibleDebtToken.NotAuthorized.selector));

        cdt.burnFrom(USER, 1);
    }

    function test_noAllowance_reverts() public givenTokenIsCreated givenMinted(USER, 100) {
        // No allowance

        vm.expectRevert(stdError.arithmeticError);

        vm.prank(OWNER);
        cdt.burnFrom(USER, 1);
    }

    function test_insufficientAllowance_reverts()
        public
        givenTokenIsCreated
        givenMinted(USER, 100)
    {
        // Insufficient allowance
        vm.prank(USER);
        cdt.approve(OWNER, 99);

        vm.expectRevert(stdError.arithmeticError);

        vm.prank(OWNER);
        cdt.burnFrom(USER, 100);
    }

    function test_success(
        uint256 amount_
    ) public givenTokenIsCreated givenMinted(USER, 100) {
        uint256 amount = bound(amount_, 0, 100);

        // Set allowance
        vm.prank(USER);
        cdt.approve(OWNER, 100);

        // Call
        vm.prank(OWNER);
        cdt.burnFrom(USER, amount);

        // Assert
        assertEq(cdt.balanceOf(USER), 100 - amount, "balanceOf(USER)");
        assertEq(cdt.totalSupply(), 100 - amount, "totalSupply");
        assertEq(cdt.allowance(USER, OWNER), 100 - amount, "allowance(USER, OWNER)");
    }

    function test_maxApproval() public givenTokenIsCreated givenMinted(USER, 100) {
        vm.prank(USER);
        cdt.approve(OWNER, type(uint256).max);

        vm.prank(OWNER);
        cdt.burnFrom(USER, 100);

        assertEq(cdt.allowance(USER, OWNER), type(uint256).max, "allowance(USER, OWNER)");
    }
}
