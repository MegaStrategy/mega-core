// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Banker} from "src/policies/Banker.sol";
import {ERC20} from "solmate-6.8.0/tokens/ERC20.sol";
import {ConvertibleDebtToken} from "src/lib/ConvertibleDebtToken.sol";

import {BankerTest} from "./BankerTest.sol";

contract BankerRedeemTest is BankerTest {
    // test cases
    // [X] when the policy is not active
    //    [X] it reverts
    // [X] when the debt token was not created by the policy
    //    [X] it reverts
    // [X] when the debt token has not matured
    //    [X] it reverts
    // [X] when the amount is zero
    //    [X] it reverts
    // [X] when the treasury doesn't have enough of the underlying asset to repay the debt
    //    [X] it reverts
    // [X] when the parameters are valid, the token has matured, and the treasury has enough funds
    //    [X] it burns the given amount of debt tokens from the sender
    //    [X] it transfers the amount of the debt token's underlying asset to the sender
    //    [X] it decreases the contract's mint allowance for the amount divided by conversion price

    function test_policyNotActive_reverts() public {
        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(Banker.Inactive.selector));
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
                address(MSTR),
                debtTokenParams.maturity,
                debtTokenParams.conversionPrice,
                OWNER
            )
        );
        deal(_debtToken, buyer, 1e18);

        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(Banker.InvalidDebtToken.selector));
        banker.redeem(_debtToken, 1e18);
    }

    function test_debtTokenNotMatured_reverts(
        uint48 warp_
    ) public givenPolicyIsActive givenDebtTokenCreated givenIssuedDebtTokens(buyer, 1e18) {
        uint48 time = debtTokenParams.maturity - uint48(bound(warp_, 1, debtTokenParams.maturity));

        vm.warp(time);
        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(Banker.DebtTokenNotMatured.selector));
        banker.redeem(debtToken, 1e18);
    }

    function test_amountZero_reverts() public givenPolicyIsActive givenDebtTokenCreated {
        vm.warp(debtTokenParams.maturity);
        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(Banker.InvalidParam.selector, "amount"));
        banker.redeem(debtToken, 0);
    }

    function test_treasuryInsufficientFunds_reverts(
        uint128 amount_,
        uint128 treasuryFunds_
    ) public givenPolicyIsActive givenDebtTokenCreated {
        vm.assume(amount_ > 0 && treasuryFunds_ < amount_);

        // Issue debt tokens to the buyer
        _issueDebtToken(buyer, amount_);

        // Fund the treasury with the given amount
        _fundTreasury(treasuryFunds_);

        vm.warp(debtTokenParams.maturity);

        vm.startPrank(buyer);
        ERC20(debtToken).approve(address(banker), amount_);
        vm.expectRevert();
        banker.redeem(debtToken, amount_);
        vm.stopPrank();
    }

    function test_success(
        uint128 amount_,
        uint128 treasuryFunds_
    ) public givenPolicyIsActive givenDebtTokenCreated {
        vm.assume(amount_ > 0 && treasuryFunds_ >= amount_);

        // Issue debt tokens to the buyer
        _issueDebtToken(buyer, amount_);

        // Fund the treasury with the given amount
        _fundTreasury(treasuryFunds_);

        // Confirm beginning balances
        assertEq(ERC20(debtToken).balanceOf(buyer), amount_);
        assertEq(ERC20(debtTokenParams.underlying).balanceOf(buyer), 0);
        assertEq(ERC20(debtTokenParams.underlying).balanceOf(address(TRSRY)), treasuryFunds_);
        assertEq(
            TRSRY.withdrawApproval(address(banker), ERC20(debtTokenParams.underlying)), amount_
        );
        assertEq(
            MSTR.mintApproval(address(banker)),
            amount_ * 10 ** MSTR.decimals() / debtTokenParams.conversionPrice
        );

        // Warp to maturity
        vm.warp(debtTokenParams.maturity);

        // Redeem debt tokens
        vm.startPrank(buyer);
        ERC20(debtToken).approve(address(banker), amount_);
        banker.redeem(debtToken, amount_);
        vm.stopPrank();

        // Check ending balances
        assertEq(ERC20(debtToken).balanceOf(buyer), 0);
        assertEq(ERC20(debtTokenParams.underlying).balanceOf(buyer), amount_);
        assertEq(
            ERC20(debtTokenParams.underlying).balanceOf(address(TRSRY)), treasuryFunds_ - amount_
        );
        assertEq(TRSRY.withdrawApproval(address(banker), ERC20(debtTokenParams.underlying)), 0);
        assertEq(MSTR.mintApproval(address(banker)), 0);
    }
}
