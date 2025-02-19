// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import {Test} from "@forge-std/Test.sol";
import {MockERC20} from "@solmate-6.8.0/test/utils/mocks/MockERC20.sol";

import {ConvertibleDebtToken} from "src/lib/ConvertibleDebtToken.sol";

abstract contract ConvertibleDebtTokenTest is Test {
    MockERC20 public underlyingAsset;
    MockERC20 public convertsToAsset;
    uint48 public maturity = 1 days;
    uint256 public conversionPrice = 5e18;
    ConvertibleDebtToken public cdt;

    address public OWNER = address(1);
    address public USER = address(2);
    address public OTHER = address(3);

    function setUp() public {
        underlyingAsset = new MockERC20("Underlying", "UNDY", 18);
        convertsToAsset = new MockERC20("ConvertsTo", "CONV", 18);
    }

    modifier givenTokenIsCreated() {
        cdt = new ConvertibleDebtToken(
            "CDT",
            "CDT",
            address(underlyingAsset),
            address(convertsToAsset),
            maturity,
            conversionPrice,
            OWNER
        );
        _;
    }

    modifier givenMaturityIsSet(
        uint48 maturity_
    ) {
        maturity = maturity_;
        _;
    }

    modifier givenConversionPriceIsSet(
        uint256 conversionPrice_
    ) {
        conversionPrice = conversionPrice_;
        _;
    }

    modifier givenMinted(address to_, uint256 amount_) {
        vm.prank(OWNER);
        cdt.mint(to_, amount_);
        _;
    }
}
