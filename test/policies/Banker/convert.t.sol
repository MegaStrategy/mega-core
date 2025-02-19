// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import {IBanker} from "src/policies/interfaces/IBanker.sol";
import {ERC20} from "solmate-6.8.0/tokens/ERC20.sol";
import {ConvertibleDebtToken} from "src/lib/ConvertibleDebtToken.sol";
import {FullMath} from "src/lib/FullMath.sol";
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
    //   [X] it does not lose precision
    //  given the conversion price is large
    //   [X] it does not lose precision
    //  [X] it decreases the contract's withdraw allowance for the debt token's underlying asset by amount
    //  [X] the converted amount is in terms of the destination token
    //  [X] the mint allowance is decreased by the amount converted
    // when multiple issue rounds are converted at once
    //  [X] the converted amount does not exceed the mint allowance
    // given the debt tokens are issued through an auction
    //  [X] it burns the given amount of debt tokens from the sender
    //  [X] it mints the amount divided by the conversion price of TOKEN to the sender
    //  [X] it decreases the contract's withdraw allowance for the debt token's underlying asset by amount
    //  [X] the mint allowance is decreased by the amount converted
    // [X] it burns the given amount of debt tokens from the sender
    // [X] it mints the amount divided by the conversion price of TOKEN to the sender
    // [X] it decreases the contract's withdraw allowance for the debt token's underlying asset by amount
    // [X] the mint allowance is decreased by the amount converted

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

    function test_underlyingAssetHasSmallerDecimals_fuzz(
        uint256 amount_,
        uint256 amountToConvert_
    )
        public
        givenPolicyIsActive
        givenUnderlyingAssetDecimals(6)
        givenDebtTokenConversionPrice(5e6)
        givenDebtTokenCreated
    {
        // 1 to 1,000,000
        uint256 amount = bound(amount_, 1e6, 1_000_000e6);
        uint256 amountToConvert = bound(amountToConvert_, 1e6, amount);

        // Issuer debt tokens to the buyer
        _issueDebtToken(buyer, amount);
        // Don't warp so the debt token has not matured

        uint256 mintApprovalBefore = mgst.mintApproval(address(banker));

        // Call function
        vm.startPrank(buyer);
        ERC20(debtToken).approve(address(banker), amountToConvert);
        banker.convert(debtToken, amountToConvert);
        vm.stopPrank();

        // Conversion price is 5e6
        // 5 debt tokens converts to 1 protocol token
        // converted amount = amount * protocol token scale / conversion price
        // e.g. amount = 1,000,000
        // converted amount = 1_000_000e6 * 1e18 / 5e6 = 2e23
        // = 200,000
        uint256 expectedConvertedAmount = amountToConvert * 1e18 / 5e6;

        // Check that balances are updated
        _assertBalances(amount, amountToConvert, 0, expectedConvertedAmount);
        _assertApprovals(amount, amountToConvert, 0, mintApprovalBefore, expectedConvertedAmount);
    }

    function test_underlyingAssetHasSmallerDecimals_smallConversionPrice_fuzz(
        uint256 amount_,
        uint256 amountToConvert_
    )
        public
        givenPolicyIsActive
        givenUnderlyingAssetDecimals(6)
        givenDebtTokenConversionPrice(1)
        givenDebtTokenCreated
    {
        // 1 to 1,000,000
        uint256 amount = bound(amount_, 1e6, 1_000_000e6);
        uint256 amountToConvert = bound(amountToConvert_, 1e6, amount);

        // Issuer debt tokens to the buyer
        _issueDebtToken(buyer, amount);
        // Don't warp so the debt token has not matured

        uint256 mintApprovalBefore = mgst.mintApproval(address(banker));

        // Call function
        vm.startPrank(buyer);
        ERC20(debtToken).approve(address(banker), amountToConvert);
        banker.convert(debtToken, amountToConvert);
        vm.stopPrank();

        // Conversion price is 1
        // 5 debt tokens converts to 1 protocol token
        // converted amount = amount * protocol token scale / conversion price
        // e.g. amount = 1,000,000
        // converted amount = 1_000_000e6 * 1e18 / 1 = 1e30
        // = 1,000,000,000,000
        uint256 expectedConvertedAmount = amountToConvert * 1e18 / 1;

        // Check that balances are updated
        _assertBalances(amount, amountToConvert, 0, expectedConvertedAmount);
        _assertApprovals(amount, amountToConvert, 0, mintApprovalBefore, expectedConvertedAmount);
    }

    function test_underlyingAssetHasSmallerDecimals_largeConversionPrice_fuzz(
        uint256 amount_,
        uint256 amountToConvert_
    )
        public
        givenPolicyIsActive
        givenUnderlyingAssetDecimals(6)
        givenDebtTokenConversionPrice(1_000_000e6)
        givenDebtTokenCreated
    {
        // 1 to 1,000,000
        uint256 amount = bound(amount_, 1e6, 1_000_000e6);
        uint256 amountToConvert = bound(amountToConvert_, 1e6, amount);

        // Issuer debt tokens to the buyer
        _issueDebtToken(buyer, amount);
        // Don't warp so the debt token has not matured

        uint256 mintApprovalBefore = mgst.mintApproval(address(banker));

        // Call function
        vm.startPrank(buyer);
        ERC20(debtToken).approve(address(banker), amountToConvert);
        banker.convert(debtToken, amountToConvert);
        vm.stopPrank();

        // Conversion price is 5e6
        // 5 debt tokens converts to 1 protocol token
        // converted amount = amount * protocol token scale / conversion price
        // e.g. amount = 1,000,000
        // converted amount = 1_000_000e6 * 1e18 / 1_000_000e6 = 1e18
        // = 1
        uint256 expectedConvertedAmount = amountToConvert * 1e18 / 1_000_000e6;

        // Check that balances are updated
        _assertBalances(amount, amountToConvert, 0, expectedConvertedAmount);
        _assertApprovals(amount, amountToConvert, 0, mintApprovalBefore, expectedConvertedAmount);
    }

    function test_multipleIssue(
        uint256 amountOne_,
        uint256 amountTwo_
    ) public givenPolicyIsActive givenDebtTokenCreated {
        uint256 amountOne = bound(amountOne_, 1e18, 1_000_000e18);
        uint256 amountTwo = bound(amountTwo_, 1e18, 1_000_000e18);

        _issueDebtToken(buyer, amountOne);
        _issueDebtToken(buyer, amountTwo);

        uint256 mintApprovalBefore = mgst.mintApproval(address(banker));

        vm.startPrank(buyer);
        ERC20(debtToken).approve(address(banker), amountOne + amountTwo);
        banker.convert(debtToken, amountOne + amountTwo);
        vm.stopPrank();

        uint256 expectedConvertedAmount =
            (amountOne + amountTwo) * 1e18 / debtTokenParams.conversionPrice;
        _assertBalances(amountOne + amountTwo, amountOne + amountTwo, 0, expectedConvertedAmount);
        _assertApprovals(
            amountOne + amountTwo,
            amountOne + amountTwo,
            0,
            mintApprovalBefore,
            expectedConvertedAmount
        );
    }

    function test_success(
        uint128 amount_,
        uint128 amountToConvert_
    ) public givenPolicyIsActive givenDebtTokenCreated {
        // 1 to 1,000,000
        uint256 amount = bound(amount_, 1e18, 1_000_000e18);
        uint256 amountToConvert = bound(amountToConvert_, 1e18, amount);

        // Issue debt tokens to the buyer
        _issueDebtToken(buyer, amount);
        // Don't warp so the debt token has not matured

        // Check beginning balances and withdraw approval
        assertEq(ERC20(debtToken).balanceOf(buyer), amount, "debtToken balance");
        assertEq(mgst.balanceOf(buyer), 0, "mgst balance");
        assertEq(
            TRSRY.withdrawApproval(address(banker), ERC20(debtTokenParams.underlying)),
            amount,
            "underlying withdraw approval"
        );
        uint256 mintApprovalBefore = mgst.mintApproval(address(banker));
        assertEq(
            mintApprovalBefore,
            FullMath.mulDivUp(amount, 10 ** mgst.decimals(), debtTokenParams.conversionPrice),
            "mgst mint approval"
        );

        // Convert the tokens at the conversion price
        vm.startPrank(buyer);
        ERC20(debtToken).approve(address(banker), amountToConvert);
        banker.convert(debtToken, amountToConvert);
        vm.stopPrank();

        // Check that the balances are updated
        uint256 expectedConvertedAmount =
            amountToConvert * 10 ** mgst.decimals() / debtTokenParams.conversionPrice;
        _assertBalances(amount, amountToConvert, 0, expectedConvertedAmount);
        _assertApprovals(amount, amountToConvert, 0, mintApprovalBefore, expectedConvertedAmount);
    }

    function test_smallConversionPrice_fuzz(
        uint256 amount_,
        uint256 amountToConvert_
    ) public givenPolicyIsActive givenDebtTokenConversionPrice(1) givenDebtTokenCreated {
        // 1 to 1,000,000
        uint256 amount = bound(amount_, 1e18, 1_000_000e18);
        uint256 amountToConvert = bound(amountToConvert_, 1e18, amount);

        // Issue debt tokens to the buyer
        _issueDebtToken(buyer, amount);
        // Don't warp so the debt token has not matured

        uint256 mintApprovalBefore = mgst.mintApproval(address(banker));

        // Call function
        vm.startPrank(buyer);
        ERC20(debtToken).approve(address(banker), amountToConvert);
        banker.convert(debtToken, amountToConvert);
        vm.stopPrank();

        // Check that balances are updated
        uint256 expectedConvertedAmount = amountToConvert * 1e18 / 1;
        _assertBalances(amount, amountToConvert, 0, expectedConvertedAmount);
        _assertApprovals(amount, amountToConvert, 0, mintApprovalBefore, expectedConvertedAmount);
    }

    function test_largeConversionPrice_fuzz(
        uint256 amount_,
        uint256 amountToConvert_
    )
        public
        givenPolicyIsActive
        givenDebtTokenConversionPrice(1_000_000e18)
        givenDebtTokenCreated
    {
        // 1 to 1,000,000
        uint256 amount = bound(amount_, 1e18, 1_000_000e18);
        uint256 amountToConvert = bound(amountToConvert_, 1e18, amount);

        // Issue debt tokens to the buyer
        _issueDebtToken(buyer, amount);
        // Don't warp so the debt token has not matured

        uint256 mintApprovalBefore = mgst.mintApproval(address(banker));

        // Call function
        vm.startPrank(buyer);
        ERC20(debtToken).approve(address(banker), amountToConvert);
        banker.convert(debtToken, amountToConvert);
        vm.stopPrank();

        // Check that balances are updated
        uint256 expectedConvertedAmount = amountToConvert * 1e18 / 1_000_000e18;
        _assertBalances(amount, amountToConvert, 0, expectedConvertedAmount);
        _assertApprovals(amount, amountToConvert, 0, mintApprovalBefore, expectedConvertedAmount);
    }

    function test_auctionLifecycle()
        public
        givenPolicyIsActive
        givenAuctionIsCreated
        givenAuctionHasStarted
        givenAuctionHasBid(100e18, 5e18)
        givenAuctionHasConcluded
        givenAuctionHasSettled
        givenBidIsClaimed(1)
    {
        // Get the balance before
        uint256 debtTokenBalanceBefore = ERC20(debtToken).balanceOf(buyer);
        uint256 mintApprovalBefore = mgst.mintApproval(address(banker));
        assertEq(
            debtTokenBalanceBefore, auctionParams.capacity, "debt token balance before conversion"
        );

        // Convert the tokens at the conversion price
        vm.startPrank(buyer);
        ERC20(debtToken).approve(address(banker), debtTokenBalanceBefore);
        banker.convert(debtToken, debtTokenBalanceBefore);
        vm.stopPrank();

        // Check that the balances are updated
        uint256 expectedConvertedAmount =
            debtTokenBalanceBefore * 10 ** mgst.decimals() / debtTokenParams.conversionPrice;
        _assertBalances(debtTokenBalanceBefore, debtTokenBalanceBefore, 0, expectedConvertedAmount);
        _assertApprovals(
            debtTokenBalanceBefore,
            debtTokenBalanceBefore,
            0,
            mintApprovalBefore,
            expectedConvertedAmount
        );
    }
}
