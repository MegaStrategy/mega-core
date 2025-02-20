// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import {BankerTest} from "./BankerTest.sol";

import {IBanker} from "src/policies/interfaces/IBanker.sol";
import {ConvertibleDebtToken} from "src/lib/ConvertibleDebtToken.sol";

contract BankerGetConvertedAmountTest is BankerTest {
    // given the debt token was not created by the policy
    //  [X] it reverts
    // given the amount is zero
    //  [X] it returns zero
    // given the underlying asset has 6 decimals
    //  given the conversion price is small
    //   [X] it does not lose precision
    //  given the conversion price is large
    //   [X] it does not lose precision
    //  [X] the converted amount is in terms of the destination token
    // given the conversion price is small
    //  [X] it does not lose precision
    // given the conversion price is large
    //  [X] it does not lose precision
    // [X] the converted amount is in terms of the destination token

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

        // Expect revert
        vm.expectRevert(abi.encodeWithSelector(IBanker.InvalidDebtToken.selector));

        // Call function
        banker.getConvertedAmount(_debtToken, 1e18);
    }

    function test_amountZero() public givenPolicyIsActive givenDebtTokenCreated {
        // Call function
        uint256 convertedAmount = banker.getConvertedAmount(debtToken, 0);

        // Assert
        assertEq(convertedAmount, 0, "convertedAmount");
    }

    function test_underlyingAssetHasSmallerDecimals()
        public
        givenPolicyIsActive
        givenUnderlyingAssetDecimals(6)
        givenDebtTokenConversionPrice(5e6)
        givenDebtTokenCreated
    {
        // Call function
        uint256 convertedAmount = banker.getConvertedAmount(debtToken, 1e6);

        // Amount is 1e6 debt tokens (== 1)
        // Conversion price is 5e6
        // 5 debt tokens converts to 1 protocol token
        // 1 debt token converts to 0.2 protocol token
        // == 2e17

        // Assert
        assertEq(convertedAmount, 2e17, "convertedAmount");
    }

    function test_underlyingAssetHasSmallerDecimals_fuzz(
        uint256 amount_
    )
        public
        givenPolicyIsActive
        givenUnderlyingAssetDecimals(6)
        givenDebtTokenConversionPrice(5e6)
        givenDebtTokenCreated
    {
        // 1 to 1,000,000
        uint256 amount = bound(amount_, 1e6, 1_000_000e6);

        // Call function
        uint256 convertedAmount = banker.getConvertedAmount(debtToken, amount);

        // Conversion price is 5e6
        // 5 debt tokens converts to 1 protocol token
        // converted amount = amount * protocol token scale / conversion price
        // e.g. amount = 1,000,000
        // converted amount = 1_000_000e6 * 1e18 / 5e6 = 2e23
        // = 200,000
        uint256 expectedConvertedAmount = amount * 1e18 / 5e6;

        // Assert
        assertEq(convertedAmount, expectedConvertedAmount, "convertedAmount");
    }

    function test_underlyingAssetHasSmallerDecimals_smallConversionPrice_fuzz(
        uint256 amount_
    )
        public
        givenPolicyIsActive
        givenUnderlyingAssetDecimals(6)
        givenDebtTokenConversionPrice(1)
        givenDebtTokenCreated
    {
        // 1 to 1,000,000
        uint256 amount = bound(amount_, 1e6, 1_000_000e6);

        // Call function
        uint256 convertedAmount = banker.getConvertedAmount(debtToken, amount);

        // Expected converted amount does not lose precision
        uint256 expectedConvertedAmount = amount * 1e18 / 1;

        // Assert
        assertEq(convertedAmount, expectedConvertedAmount, "convertedAmount");
        assertTrue(convertedAmount > 0, "convertedAmount should not be zero");
    }

    function test_underlyingAssetHasSmallerDecimals_largeConversionPrice_fuzz(
        uint256 amount_
    )
        public
        givenPolicyIsActive
        givenUnderlyingAssetDecimals(6)
        givenDebtTokenConversionPrice(1_000_000e6)
        givenDebtTokenCreated
    {
        // 1 to 1,000,000
        uint256 amount = bound(amount_, 1e6, 1_000_000e6);

        // Call function
        uint256 convertedAmount = banker.getConvertedAmount(debtToken, amount);

        // Expected converted amount does not lose precision
        uint256 expectedConvertedAmount = amount * 1e18 / 1_000_000e6;

        // Assert
        assertEq(convertedAmount, expectedConvertedAmount, "convertedAmount");
        assertTrue(convertedAmount > 0, "convertedAmount should not be zero");
    }

    function test_success_fuzz(
        uint256 amount_
    ) public givenPolicyIsActive givenDebtTokenCreated {
        // 1 to 1,000,000
        uint256 amount = bound(amount_, 1e18, 1_000_000e18);

        // Call function
        uint256 convertedAmount = banker.getConvertedAmount(debtToken, amount);

        uint256 expectedConvertedAmount = amount * 1e18 / debtTokenParams.conversionPrice;

        // Assert
        assertEq(convertedAmount, expectedConvertedAmount, "convertedAmount");
    }

    function test_smallConversionPrice_fuzz(
        uint256 amount_
    ) public givenPolicyIsActive givenDebtTokenConversionPrice(1) givenDebtTokenCreated {
        // 1 to 1,000,000
        uint256 amount = bound(amount_, 1e18, 1_000_000e18);

        // Call function
        uint256 convertedAmount = banker.getConvertedAmount(debtToken, amount);

        // Expected converted amount does not lose precision
        uint256 expectedConvertedAmount = amount * 1e18 / 1;

        // Assert
        assertEq(convertedAmount, expectedConvertedAmount, "convertedAmount");
        assertTrue(convertedAmount > 0, "convertedAmount should not be zero");
    }

    function test_largeConversionPrice_fuzz(
        uint256 amount_
    )
        public
        givenPolicyIsActive
        givenDebtTokenConversionPrice(1_000_000e18)
        givenDebtTokenCreated
    {
        // 1 to 1,000,000
        uint256 amount = bound(amount_, 1e18, 1_000_000e18);

        // Call function
        uint256 convertedAmount = banker.getConvertedAmount(debtToken, amount);

        // Expected converted amount does not lose precision
        uint256 expectedConvertedAmount = amount * 1e18 / 1_000_000e18;

        // Assert
        assertEq(convertedAmount, expectedConvertedAmount, "convertedAmount");
        assertTrue(convertedAmount > 0, "convertedAmount should not be zero");
    }
}
