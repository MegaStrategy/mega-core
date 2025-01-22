// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {IBanker} from "src/policies/interfaces/IBanker.sol";
import {ERC20} from "solmate-6.8.0/tokens/ERC20.sol";
import {ConvertibleDebtToken} from "src/lib/ConvertibleDebtToken.sol";

import {BankerTest} from "./BankerTest.sol";

contract BankerConvertTest is BankerTest {
    // test cases
    // when the policy is not active
    //  [X] it reverts
    // when the debt token was not created by the policy
    //  [X] it reverts
    // when the amount is zero
    //  [X] it reverts
    // given the underlying asset has 6 decimals
    //  given the conversion price is small
    //   [ ] it does not lose precision
    //  given the conversion price is large
    //   [ ] it does not lose precision
    //  [ ] it decreases the contract's withdraw allowance for the debt token's underlying asset by amount
    //  [ ] the converted amount is in terms of the destination token
    //  [ ] the mint allowance is decreased by the amount converted
    // [X] it burns the given amount of debt tokens from the sender
    // [X] it mints the amount divided by the conversion price of TOKEN to the sender
    // [X] it decreases the contract's withdraw allowance for the debt token's underlying asset by amount
    // [ ] the mint allowance is decreased by the amount converted

    function test_policyNotActive_reverts() public {
        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(IBanker.Inactive.selector));
        banker.convert(debtToken, 1e18);
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
        banker.convert(_debtToken, 1e18);
    }

    function test_amountZero_reverts() public givenPolicyIsActive givenDebtTokenCreated {
        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(IBanker.InvalidParam.selector, "amount"));
        banker.convert(debtToken, 0);
    }

    function test_success(
        uint128 amount_
    ) public givenPolicyIsActive givenDebtTokenCreated {
        vm.assume(
            amount_
                >= (
                    debtTokenParams.conversionPrice
                        / (10 ** ERC20(debtTokenParams.underlying).decimals())
                )
        ); // can't round down to zero

        // Issue debt tokens to the buyer
        _issueDebtToken(buyer, amount_);
        // Don't warp so the debt token has not matured

        // Check beginning balances and withdraw approval
        assertEq(ERC20(debtToken).balanceOf(buyer), amount_);
        assertEq(mgst.balanceOf(buyer), 0);
        assertEq(
            TRSRY.withdrawApproval(address(banker), ERC20(debtTokenParams.underlying)), amount_
        );

        // Convert the tokens at the conversion price
        vm.startPrank(buyer);
        ERC20(debtToken).approve(address(banker), amount_);
        banker.convert(debtToken, amount_);
        vm.stopPrank();

        // Check that the balances are updated
        assertEq(ERC20(debtToken).balanceOf(buyer), 0);
        assertEq(
            mgst.balanceOf(buyer), amount_ * 10 ** mgst.decimals() / debtTokenParams.conversionPrice
        );
        assertEq(TRSRY.withdrawApproval(address(banker), ERC20(debtTokenParams.underlying)), 0);
    }
}
