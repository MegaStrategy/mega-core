// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {IBanker} from "src/policies/interfaces/IBanker.sol";
import {ERC20} from "solmate-6.8.0/tokens/ERC20.sol";
import {ConvertibleDebtToken} from "src/lib/ConvertibleDebtToken.sol";
import {FullMath} from "src/lib/FullMath.sol";
import {BankerTest} from "./BankerTest.sol";

contract BankerRedeemTest is BankerTest {
    // test cases
    // when the policy is not active
    //  [X] it reverts
    // when the debt token was not created by the policy
    //  [X] it reverts
    // when the debt token has not matured
    //  [X] it reverts
    // when the amount is zero
    //  [X] it reverts
    // when the treasury doesn't have enough of the underlying asset to repay the debt
    //  [X] it reverts
    // given the underlying asset has 6 decimals
    //  [X] it decreases the contract's withdraw allowance for the debt token's underlying asset
    //  [X] it decreases the contract's mint allowance for TOKEN
    // when the parameters are valid, the token has matured, and the treasury has enough funds
    //  [X] it burns the given amount of debt tokens from the sender
    //  [X] it transfers the amount of the debt token's underlying asset to the sender
    //  [X] it decreases the contract's mint allowance for the amount divided by conversion price

    function test_policyNotActive_reverts() public {
        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(IBanker.Inactive.selector));
        banker.redeem(debtToken, 1e18);
    }

    function test_debtTokenNotCreatedByPolicy_reverts()
        public
        givenPolicyIsActive
        givenDebtTokenCreated
    {
        address _debtToken = address(
            new ConvertibleDebtToken(
                "Fake Debt Token",
                "FDT",
                debtTokenParams.underlying,
                address(mgst),
                debtTokenParams.maturity,
                debtTokenParams.conversionPrice,
                OWNER
            )
        );
        deal(_debtToken, buyer, 1e18);

        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(IBanker.InvalidDebtToken.selector));
        banker.redeem(_debtToken, 1e18);
    }

    function test_debtTokenNotMatured_reverts(
        uint48 warp_
    ) public givenPolicyIsActive givenDebtTokenCreated givenIssuedDebtTokens(buyer, 1e18) {
        uint48 time = debtTokenParams.maturity - uint48(bound(warp_, 1, debtTokenParams.maturity));

        vm.warp(time);
        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(IBanker.DebtTokenNotMatured.selector));
        banker.redeem(debtToken, 1e18);
    }

    function test_amountZero_reverts() public givenPolicyIsActive givenDebtTokenCreated {
        vm.warp(debtTokenParams.maturity);
        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(IBanker.InvalidParam.selector, "amount"));
        banker.redeem(debtToken, 0);
    }

    function test_treasuryInsufficientFunds_reverts(
        uint128 amount_,
        uint128 treasuryFunds_
    ) public givenPolicyIsActive givenDebtTokenCreated {
        vm.assume(amount_ > 0 && treasuryFunds_ < amount_);

        // Issue debt tokens to the buyer
        _issueDebtToken(buyer, amount_);

        // Override the treasury's balance
        _fundTreasury(treasuryFunds_);

        vm.warp(debtTokenParams.maturity);

        vm.startPrank(buyer);
        ERC20(debtToken).approve(address(banker), amount_);
        vm.expectRevert();
        banker.redeem(debtToken, amount_);
        vm.stopPrank();
    }

    function test_underlyingAssetHasSmallerDecimals(
        uint256 amount_,
        uint256 amountToRedeem_
    )
        public
        givenPolicyIsActive
        givenUnderlyingAssetDecimals(6)
        givenDebtTokenConversionPrice(5e6)
        givenDebtTokenCreated
    {
        // 1 to 1,000,000
        uint256 amount = bound(amount_, 1e6, 1_000_000e6);
        uint256 amountToRedeem = bound(amountToRedeem_, 1e6, amount);

        // Issue debt tokens to the buyer
        _issueDebtToken(buyer, amount);

        // Confirm beginning balances
        assertEq(ERC20(debtToken).balanceOf(buyer), amount, "debt token balance");
        assertEq(ERC20(debtTokenParams.underlying).balanceOf(buyer), 0, "underlying balance");
        assertEq(
            ERC20(debtTokenParams.underlying).balanceOf(address(TRSRY)), amount, "treasury balance"
        );
        assertEq(
            TRSRY.withdrawApproval(address(banker), ERC20(debtTokenParams.underlying)),
            amount,
            "underlying withdraw allowance"
        );
        uint256 mintApprovalBefore = mgst.mintApproval(address(banker));
        assertEq(
            mintApprovalBefore,
            FullMath.mulDivUp(amount, 10 ** mgst.decimals(), debtTokenParams.conversionPrice),
            "mgst mint allowance"
        );

        // Warp to maturity
        vm.warp(debtTokenParams.maturity);

        // Redeem debt tokens
        vm.startPrank(buyer);
        ERC20(debtToken).approve(address(banker), amountToRedeem);
        banker.redeem(debtToken, amountToRedeem);
        vm.stopPrank();

        // Check ending balances
        uint256 expectedConvertedAmount = amountToRedeem * 1e18 / 5e6;
        _assertBalances(amount, 0, amountToRedeem, 0);
        _assertApprovals(amount, 0, amountToRedeem, mintApprovalBefore, expectedConvertedAmount);
    }

    function test_success(
        uint256 amount_,
        uint256 amountToRedeem_
    ) public givenPolicyIsActive givenDebtTokenCreated {
        // 1 to 1,000,000
        uint256 amount = bound(amount_, 1e18, 1_000_000e18);
        uint256 amountToRedeem = bound(amountToRedeem_, 1e18, amount);

        // Issue debt tokens to the buyer
        _issueDebtToken(buyer, amount);

        // Confirm beginning balances
        assertEq(ERC20(debtToken).balanceOf(buyer), amount, "debt token balance");
        assertEq(ERC20(debtTokenParams.underlying).balanceOf(buyer), 0, "underlying balance");
        assertEq(
            ERC20(debtTokenParams.underlying).balanceOf(address(TRSRY)), amount, "treasury balance"
        );
        assertEq(
            TRSRY.withdrawApproval(address(banker), ERC20(debtTokenParams.underlying)),
            amount,
            "underlying withdraw allowance"
        );
        uint256 mintApprovalBefore = mgst.mintApproval(address(banker));
        assertEq(
            mintApprovalBefore,
            FullMath.mulDivUp(amount, 10 ** mgst.decimals(), debtTokenParams.conversionPrice),
            "mgst mint allowance"
        );

        // Warp to maturity
        vm.warp(debtTokenParams.maturity);

        // Redeem debt tokens
        vm.startPrank(buyer);
        ERC20(debtToken).approve(address(banker), amountToRedeem);
        banker.redeem(debtToken, amountToRedeem);
        vm.stopPrank();

        // Check ending balances
        uint256 expectedConvertedAmount = amountToRedeem * 1e18 / debtTokenParams.conversionPrice;
        _assertBalances(amount, 0, amountToRedeem, 0);
        _assertApprovals(amount, 0, amountToRedeem, mintApprovalBefore, expectedConvertedAmount);
    }
}
