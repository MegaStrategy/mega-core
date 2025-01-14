// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Banker} from "src/policies/Banker.sol";
import {ROLESv1} from "src/modules/ROLES/ROLES.v1.sol";
import {MockERC20, ERC20} from "solmate-6.8.0/test/utils/mocks/MockERC20.sol";

import {BankerTest} from "./BankerTest.sol";

contract BankerIssueTest is BankerTest {
    // test cases
    // [X] when the policy is not active
    //    [X] it reverts
    // [X] when the caller is not permissioned
    //    [X] it reverts
    // [X] when the debt token was not created by the policy
    //    [X] it reverts
    // [X] when the amount is zero
    //    [X] it reverts
    // [X] when the debt token has matured
    //    [X] it reverts
    // [X] when the parameters are valid and the token has not matured
    //    [X] it mints the given amount of debt tokens to the given address
    //    [X] it increases the contract's withdraw allowance for the debt token's underlying asset
    //    [X] it increases the contract's mint allowance for TOKEN by amount divided by conversion price

    function test_policyNotActive_reverts() public {
        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSelector(Banker.Inactive.selector));
        banker.issue(debtToken, address(this), 1e18);
    }

    function test_callerNotPermissioned_reverts(
        address caller_
    ) public givenPolicyIsActive givenDebtTokenCreated {
        vm.assume(caller_ != manager);

        vm.prank(caller_);
        vm.expectRevert(
            abi.encodeWithSelector(ROLESv1.ROLES_RequireRole.selector, bytes32("manager"))
        );
        banker.issue(debtToken, address(this), 1e18);
    }

    function test_debtTokenNotCreatedByPolicy_reverts()
        public
        givenPolicyIsActive
        givenDebtTokenCreated
    {
        address _debtToken = address(new MockERC20("Fake Debt Token", "FDT", 18));

        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSelector(Banker.InvalidDebtToken.selector));
        banker.issue(_debtToken, address(this), 1e18);
    }

    function test_amountZero_reverts() public givenPolicyIsActive givenDebtTokenCreated {
        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSelector(Banker.InvalidParam.selector, "amount"));
        banker.issue(debtToken, address(this), 0);
    }

    function test_debtTokenMatured_reverts(
        uint48 warp_
    ) public givenPolicyIsActive givenDebtTokenCreated {
        uint48 time = debtTokenParams.maturity
            + uint48(bound(warp_, 0, type(uint48).max - debtTokenParams.maturity));

        vm.warp(time);
        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSelector(Banker.DebtTokenMatured.selector));
        banker.issue(debtToken, address(this), 1e18);
    }

    function test_success(
        address to_,
        uint128 amount_,
        uint48 warp_
    ) public givenPolicyIsActive givenDebtTokenCreated {
        vm.assume(amount_ > 0);

        uint48 time = debtTokenParams.maturity
            - uint48(bound(warp_, 1, debtTokenParams.maturity - block.timestamp));
        vm.warp(time);

        // Issue debt tokens
        vm.prank(manager);
        banker.issue(debtToken, to_, amount_);

        // Check that the debt tokens were minted
        assertEq(ERC20(debtToken).balanceOf(to_), amount_);

        // Check that the banker contract's withdrawal allowance for the debt token's underlying asset was increased
        assertEq(
            TRSRY.withdrawApproval(address(banker), ERC20(debtTokenParams.underlying)), amount_
        );

        // Check that the banker contract's mint allowance for the debt token's underlying asset was increased
        assertEq(
            mgst.mintApproval(address(banker)),
            amount_ * 10 ** mgst.decimals() / debtTokenParams.conversionPrice
        );
    }
}
