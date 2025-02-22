// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import {IBanker} from "src/policies/interfaces/IBanker.sol";
import {ROLESv1} from "src/modules/ROLES/ROLES.v1.sol";
import {MockERC20, ERC20} from "@solmate-6.8.0/test/utils/mocks/MockERC20.sol";
import {FullMath} from "src/lib/FullMath.sol";
import {BankerTest} from "./BankerTest.sol";

contract BankerIssueTest is BankerTest {
    // test cases
    // when the policy is not active
    //  [X] it reverts
    // when the caller is not permissioned
    //  [X] it reverts
    // when the debt token was not created by the policy
    //  [X] it reverts
    // when the amount is zero
    //  [X] it reverts
    // when the debt token has matured
    //  [X] it reverts
    // when the recipient has not approved spending of the underlying asset
    //  [X] it reverts
    // given the underlying asset has 6 decimals
    //  [X] it increases the contract's withdraw allowance for the debt token's underlying asset by the amount issued
    //  [X] it increases the contract's mint allowance for TOKEN by amount divided by conversion price
    // when the parameters are valid and the token has not matured
    //  [X] it transfers the underlying asset from the recipient
    //  [X] it mints the given amount of debt tokens to the given address
    //  [X] it increases the contract's withdraw allowance for the debt token's underlying asset
    //  [X] it increases the contract's mint allowance for TOKEN by amount divided by conversion price

    function test_policyNotActive_reverts() public {
        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSelector(IBanker.Inactive.selector));
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
        vm.expectRevert(abi.encodeWithSelector(IBanker.InvalidDebtToken.selector));
        banker.issue(_debtToken, address(this), 1e18);
    }

    function test_amountZero_reverts() public givenPolicyIsActive givenDebtTokenCreated {
        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSelector(IBanker.InvalidParam.selector, "amount"));
        banker.issue(debtToken, address(this), 0);
    }

    function test_debtTokenMatured_reverts(
        uint48 warp_
    ) public givenPolicyIsActive givenDebtTokenCreated {
        uint48 time = debtTokenParams.maturity
            + uint48(bound(warp_, 0, type(uint48).max - debtTokenParams.maturity));

        vm.warp(time);
        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSelector(IBanker.DebtTokenMatured.selector));
        banker.issue(debtToken, address(this), 1e18);
    }

    function test_recipientHasNotApprovedSpendingOfUnderlyingAsset_reverts()
        public
        givenPolicyIsActive
        givenDebtTokenCreated
    {
        // Expect revert
        vm.expectRevert("TRANSFER_FROM_FAILED");

        vm.prank(manager);
        banker.issue(debtToken, buyer, 1e18);
    }

    function test_underlyingAssetHasSmallerDecimals(
        uint256 amount_
    )
        public
        givenPolicyIsActive
        givenUnderlyingAssetDecimals(6)
        givenDebtTokenConversionPrice(5e6)
        givenDebtTokenCreated
    {
        uint256 amount = bound(amount_, 1e6, 1_000_000e6);

        // Mint the underlying asset to the buyer
        stablecoin.mint(buyer, amount);

        // Approve spending of the underlying asset
        vm.startPrank(buyer);
        ERC20(debtTokenParams.underlying).approve(address(banker), amount);
        vm.stopPrank();

        // Issue debt tokens
        vm.prank(manager);
        banker.issue(debtToken, buyer, amount);

        // Check that the debt tokens were minted
        assertEq(ERC20(debtToken).balanceOf(buyer), amount, "debt token balance");

        // Check that the contract's withdraw allowance for the debt token's underlying asset was increased
        assertEq(
            TRSRY.withdrawApproval(address(banker), ERC20(debtTokenParams.underlying)),
            amount,
            "underlying withdraw allowance"
        );

        // Check that the contract's mint allowance for TOKEN was increased
        assertEq(
            mgst.mintApproval(address(banker)),
            FullMath.mulDivUp(amount, 1e18, 5e6),
            "mgst mint allowance"
        );
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

        // Mint the underlying asset to the buyer
        stablecoin.mint(to_, amount_);

        // Approve spending of the underlying asset
        vm.startPrank(to_);
        ERC20(debtTokenParams.underlying).approve(address(banker), amount_);
        vm.stopPrank();

        // Issue debt tokens
        vm.prank(manager);
        banker.issue(debtToken, to_, amount_);

        // Check that the debt tokens were minted
        assertEq(ERC20(debtToken).balanceOf(to_), amount_);

        // Check that the banker contract's withdrawal allowance for the debt token's underlying asset was increased
        assertEq(
            TRSRY.withdrawApproval(address(banker), ERC20(debtTokenParams.underlying)),
            amount_,
            "underlying withdraw allowance"
        );

        // Check that the banker contract's mint allowance for the debt token's underlying asset was increased
        assertEq(
            mgst.mintApproval(address(banker)),
            FullMath.mulDivUp(amount_, 10 ** mgst.decimals(), debtTokenParams.conversionPrice),
            "mgst mint allowance"
        );
    }
}
