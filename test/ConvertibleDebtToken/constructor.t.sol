// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import {MockERC20} from "@solmate-6.8.0/test/utils/mocks/MockERC20.sol";
import {ERC20} from "@solmate-6.8.0/tokens/ERC20.sol";

import {ConvertibleDebtTokenTest} from "./ConvertibleDebtTokenTest.sol";
import {ConvertibleDebtToken} from "src/lib/ConvertibleDebtToken.sol";

contract ConstructorTest is ConvertibleDebtTokenTest {
    // ========== TESTS ========== //
    // when the underlying asset is the zero address
    //  [X] it reverts
    // when the converts to asset is the zero address
    //  [X] it reverts
    // when the maturity is not in the future
    //  [X] it reverts
    // when the conversion price is zero
    //  [X] it succeeds, we want to be able to optionally set this later
    // when the issuer is the zero address
    //  [X] it reverts
    // when the underlying asset has different decimals
    //  [X] the decimals are set correctly
    // [X] it records the issuer
    // [X] it sets the name, symbol, and decimals
    // [X] it sets the underlying asset
    // [X] it sets the converts to asset
    // [X] it sets the maturity
    // [X] it sets the conversion price

    function test_underlyingAsset_zeroAddress() public {
        // ERC20 constructor reverts
        vm.expectRevert();

        new ConvertibleDebtToken(
            "CDT", "CDT", address(0), address(convertsToAsset), maturity, conversionPrice, OWNER
        );
    }

    function test_convertsToAsset_zeroAddress() public {
        // ERC20 constructor reverts
        vm.expectRevert();

        new ConvertibleDebtToken(
            "CDT", "CDT", address(underlyingAsset), address(0), maturity, conversionPrice, OWNER
        );
    }

    function test_maturity_notInFuture(
        uint48 maturity_
    ) public {
        uint48 maturity = uint48(bound(maturity_, 0, block.timestamp));

        vm.expectRevert(
            abi.encodeWithSelector(ConvertibleDebtToken.InvalidParam.selector, "maturity")
        );

        new ConvertibleDebtToken(
            "CDT",
            "CDT",
            address(underlyingAsset),
            address(convertsToAsset),
            maturity,
            conversionPrice,
            OWNER
        );
    }

    function test_conversionPrice_zero_success() public {
        new ConvertibleDebtToken(
            "CDT", "CDT", address(underlyingAsset), address(convertsToAsset), maturity, 0, OWNER
        );
    }

    function test_issuer_zeroAddress() public {
        vm.expectRevert(
            abi.encodeWithSelector(ConvertibleDebtToken.InvalidParam.selector, "issuer")
        );

        new ConvertibleDebtToken(
            "CDT",
            "CDT",
            address(underlyingAsset),
            address(convertsToAsset),
            maturity,
            conversionPrice,
            address(0)
        );
    }

    function test_success() public givenTokenIsCreated {
        // Assertions
        assertEq(cdt.name(), "CDT", "name");
        assertEq(cdt.symbol(), "CDT", "symbol");
        assertEq(cdt.decimals(), 18, "decimals");
        assertEq(cdt.ISSUER(), OWNER, "ISSUER");
        assertEq(address(cdt.underlying()), address(underlyingAsset), "underlying");
        assertEq(address(cdt.convertsTo()), address(convertsToAsset), "convertsTo");
        assertEq(cdt.maturity(), maturity, "maturity");
        assertEq(cdt.conversionPrice(), conversionPrice, "conversionPrice");

        (ERC20 underlying_, ERC20 convertsTo_, uint48 maturity_, uint256 conversionPrice_) =
            cdt.getTokenData();

        assertEq(address(underlying_), address(underlyingAsset), "asset");
        assertEq(address(convertsTo_), address(convertsToAsset), "convertsTo");
        assertEq(maturity_, maturity, "maturity");
        assertEq(conversionPrice_, conversionPrice, "conversionPrice");
    }

    function test_underlying_decimals() public {
        // Define a new asset with different decimals
        MockERC20 asset = new MockERC20("Asset", "ASSET", 17);

        // Call
        ConvertibleDebtToken cdt = new ConvertibleDebtToken(
            "CDT", "CDT", address(asset), address(convertsToAsset), maturity, conversionPrice, OWNER
        );

        // Assertions
        assertEq(cdt.decimals(), 17, "decimals");
    }
}
