// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {ConvertibleDebtTokenTest} from "./ConvertibleDebtTokenTest.sol";
import {ConvertibleDebtToken} from "src/misc/ConvertibleDebtToken.sol";
import {MockERC20} from "solmate-6.8.0/test/utils/mocks/MockERC20.sol";
import {ERC20} from "solmate-6.8.0/tokens/ERC20.sol";

contract ConstructorTest is ConvertibleDebtTokenTest {
    // ========== TESTS ========== //
    // when the asset is the zero address
    //  [X] it reverts
    // when the maturity is not in the future
    //  [X] it reverts
    // when the conversion price is zero
    //  [X] it reverts
    // when the underlying asset has different decimals
    //  [X] the decimals are set correctly
    // [X] it records the issuer
    // [X] it sets the name, symbol, and decimals
    // [X] it sets the asset
    // [X] it sets the maturity
    // [X] it sets the conversion price

    function test_asset_zeroAddress() public {
        // ERC20 constructor reverts
        vm.expectRevert();

        new ConvertibleDebtToken("CDT", "CDT", address(0), maturity, conversionPrice);
    }

    function test_maturity_notInFuture(
        uint48 maturity_
    ) public {
        uint48 maturity = uint48(bound(maturity_, 0, block.timestamp));

        vm.expectRevert(
            abi.encodeWithSelector(ConvertibleDebtToken.InvalidParam.selector, "maturity")
        );

        new ConvertibleDebtToken("CDT", "CDT", address(underlyingAsset), maturity, conversionPrice);
    }

    function test_conversionPrice_zero() public {
        vm.expectRevert(
            abi.encodeWithSelector(ConvertibleDebtToken.InvalidParam.selector, "conversionPrice")
        );

        new ConvertibleDebtToken("CDT", "CDT", address(underlyingAsset), maturity, 0);
    }

    function test_success() public givenTokenIsCreated {
        // Assertions
        assertEq(cdt.name(), "CDT", "name");
        assertEq(cdt.symbol(), "CDT", "symbol");
        assertEq(cdt.decimals(), 18, "decimals");
        assertEq(cdt.ISSUER(), OWNER, "ISSUER");
        assertEq(address(cdt.asset()), address(underlyingAsset), "asset");
        assertEq(cdt.maturity(), maturity, "maturity");
        assertEq(cdt.conversionPrice(), conversionPrice, "conversionPrice");

        (ERC20 asset_, uint48 maturity_, uint256 conversionPrice_) = cdt.getTokenData();

        assertEq(address(asset_), address(underlyingAsset), "asset");
        assertEq(maturity_, maturity, "maturity");
        assertEq(conversionPrice_, conversionPrice, "conversionPrice");
    }

    function test_asset_decimals() public {
        // Define a new asset with different decimals
        MockERC20 asset = new MockERC20("Asset", "ASSET", 17);

        // Call
        ConvertibleDebtToken cdt =
            new ConvertibleDebtToken("CDT", "CDT", address(asset), maturity, conversionPrice);

        // Assertions
        assertEq(cdt.decimals(), 17, "decimals");
    }
}
