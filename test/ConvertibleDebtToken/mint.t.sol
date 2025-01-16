// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {ConvertibleDebtTokenTest} from "./ConvertibleDebtTokenTest.sol";
import {ConvertibleDebtToken} from "src/lib/ConvertibleDebtToken.sol";

contract MintTest is ConvertibleDebtTokenTest {
    // ========== TESTS ========== //
    // when the caller is not the issuer
    //  [X] it reverts
    // [X] it mints the correct amount

    function test_caller_notIssuer() public givenTokenIsCreated {
        vm.expectRevert(abi.encodeWithSelector(ConvertibleDebtToken.NotAuthorized.selector));

        cdt.mint(address(1), 100);
    }

    function test_success(
        uint256 amount_
    ) public givenTokenIsCreated {
        uint256 amount = bound(amount_, 1, 10e18);

        vm.prank(OWNER);
        cdt.mint(address(this), amount);

        assertEq(cdt.balanceOf(address(this)), amount, "balanceOf");
        assertEq(cdt.totalSupply(), amount, "totalSupply");
    }

    function test_success_multiple(uint256 amount1_, uint256 amount2_) public givenTokenIsCreated {
        uint256 amount1 = bound(amount1_, 1, 10e18);
        uint256 amount2 = bound(amount2_, 1, 10e18);

        vm.prank(OWNER);
        cdt.mint(USER, amount1);
        vm.prank(OWNER);
        cdt.mint(OTHER, amount2);

        assertEq(cdt.balanceOf(USER), amount1, "balanceOf(USER)");
        assertEq(cdt.balanceOf(OTHER), amount2, "balanceOf(OTHER)");
        assertEq(cdt.totalSupply(), amount1 + amount2, "totalSupply");
    }
}
