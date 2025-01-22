// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {IBanker} from "src/policies/interfaces/IBanker.sol";
import {ROLESv1} from "src/modules/ROLES/ROLES.v1.sol";
import {IAuction} from "axis-core-1.0.1/interfaces/modules/IAuction.sol";
import {ConvertibleDebtToken} from "src/lib/ConvertibleDebtToken.sol";
import {
    Veecode,
    fromKeycode,
    fromVeecode,
    keycodeFromVeecode
} from "axis-core-1.0.1/modules/Keycode.sol";
import {ICallback} from "axis-core-1.0.1/interfaces/ICallback.sol";
import {ERC20} from "solmate-6.8.0/tokens/ERC20.sol";
import {IEncryptedMarginalPrice} from
    "axis-core-1.0.1/interfaces/modules/auctions/IEncryptedMarginalPrice.sol";

import {BankerTest} from "./BankerTest.sol";

import {console2} from "forge-std/console2.sol";

contract BankerAuctionTest is BankerTest {
    event DebtAuction(uint96 lotId);

    // ======= Modifiers ======= //

    // ======= Tests ======= //

    // when the policy is not active
    //  [X] it reverts
    // when the caller is not permissioned
    //  [X] it reverts
    // when the auction parameters are invalid
    //  [X] it reverts
    // when the debt token asset is the zero address
    //  [X] it reverts
    // given the underlying asset decimals are 6
    //  [X] the auction minPrice is set according to the scale of the underlying asset
    //  [X] the auction minBidSize is set according to the scale of the underlying asset
    //  [X] the debt token has the underlying asset decimals
    //  [X] the debt token has the conversion price set according to the parameters
    // [X] it creates an EMP auction with the given auction parameters
    // [X] the AuctionHouse receives the capacity in debt tokens
    // [X] the policy is the curator
    // [X] the policy has accepted curation
    // [X] the DebtAuction event is emitted
    // [X] the auction minPrice is set to the 1 quote token per base token, with the discount applied
    // [X] the auction minBidSize is set according to the maximum number of bids
    // [X] the debt token has the underlying asset decimals
    // [X] the debt token converts to the protocol token
    // [X] the debt token has the conversion price set according to the parameters
    // [X] the debt token has the maturity set according to the parameters

    function test_policyNotActive_reverts() public {
        vm.expectRevert(abi.encodeWithSelector(IBanker.Inactive.selector));

        // Call
        vm.prank(manager);
        banker.auction(debtTokenParams, auctionParams);
    }

    function test_callerNotPermissioned_reverts() public {
        vm.expectRevert(
            abi.encodeWithSelector(ROLESv1.ROLES_RequireRole.selector, bytes32("manager"))
        );

        // Call
        vm.prank(admin);
        banker.auction(debtTokenParams, auctionParams);
    }

    function test_debtToken_zeroAddress_reverts()
        public
        givenPolicyIsActive
        givenDebtTokenAsset(address(0))
    {
        vm.expectRevert();

        // Call
        vm.prank(manager);
        banker.auction(debtTokenParams, auctionParams);
    }

    function test_auctionParameters_invalid_reverts() public givenPolicyIsActive {
        // Set the auction start time to the past
        auctionParams.start = uint48(block.timestamp - 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAuction.Auction_InvalidStart.selector, auctionParams.start, block.timestamp
            )
        );

        // Call
        vm.prank(manager);
        banker.auction(debtTokenParams, auctionParams);
    }

    function test_debtTokenMaturity_invalid_reverts(
        uint48 maturity_
    ) public givenPolicyIsActive {
        uint48 maturity = uint48(bound(maturity_, 0, block.timestamp));
        debtTokenParams.maturity = maturity;

        vm.expectRevert(
            abi.encodeWithSelector(ConvertibleDebtToken.InvalidParam.selector, "maturity")
        );

        // Call
        vm.prank(manager);
        banker.auction(debtTokenParams, auctionParams);
    }

    function test_underlyingAssetHasSmallerDecimals()
        public
        givenPolicyIsActive
        givenUnderlyingAssetDecimals(6)
        givenAuctionCapacity(100e6)
        givenDebtTokenConversionPrice(5e6)
    {
        // Call
        vm.prank(manager);
        banker.auction(debtTokenParams, auctionParams);

        // Assertions
        // EMP auction is created
        (, address baseToken,,,,,,,) = auctionHouse.lotRouting(0);

        // EMP auction parameters
        {
            // minPrice is expected to be 1 quote token per base token, with the discount applied
            // = 1e6 * (100e2 - 10e2) / 100e2
            // = 9e5
            uint256 expectedMinPrice = 1e6 * (100e2 - maxDiscount) / 100e2;
            // minBidSize is in terms of quote tokens
            // It assumes the worst case scenario, where the auction has many small bids of quantity maxBids
            // Multiplying the minPrice (QT/BT) by the capacity (BT) gives the quantity of quote tokens at the minPrice
            // It is then divided by the underlying asset decimals to adjust the scale
            // = 9e5 * 100e6 / (1000 * 1e6)
            // = 90000
            // = 0.09
            uint256 expectedMinBidSize = expectedMinPrice * auctionParams.capacity / (maxBids * 1e6);
            // minFilled is the minFillPercent * capacity
            // = 100e2 * 100e6 / 100e2
            // = 100e6
            uint256 expectedMinFilled = minFillPercent * auctionParams.capacity / 100e2;

            IEncryptedMarginalPrice.AuctionData memory empData = empa.getAuctionData(0);
            assertEq(empData.minPrice, expectedMinPrice, "minPrice");
            assertEq(empData.minBidSize, expectedMinBidSize, "minBidSize");
            assertEq(empData.minFilled, expectedMinFilled, "minFilled");
        }

        // Convertible debt token
        ConvertibleDebtToken cdt = ConvertibleDebtToken(baseToken);
        (ERC20 underlying, ERC20 convertsTo, uint48 maturity, uint256 conversionPrice) =
            cdt.getTokenData();

        assertEq(cdt.decimals(), 6, "CDT decimals");
        assertEq(address(underlying), address(stablecoin), "CDT underlying");
        assertEq(address(convertsTo), address(mgst), "CDT convertsTo");
        assertEq(maturity, debtTokenParams.maturity, "CDT maturity");
        assertEq(conversionPrice, 5e6, "CDT conversionPrice");
    }

    function test_auction_success() public givenPolicyIsActive {
        // Call
        vm.prank(manager);
        banker.auction(debtTokenParams, auctionParams);

        // Assertions
        // EMP auction is created
        (
            address seller,
            address baseToken,
            address quoteToken,
            Veecode auctionReference,
            uint256 funding,
            ICallback callbacks,
            Veecode derivativeReference,
            ,
        ) = auctionHouse.lotRouting(0);

        assertEq(seller, address(banker), "seller == banker");
        assertEq(quoteToken, address(stablecoin), "quoteToken == stablecoin");
        // The base token is the debt token
        assertEq(
            fromKeycode(keycodeFromVeecode(auctionReference)),
            bytes5("EMPA"),
            "auction module == EMPA"
        );
        assertEq(funding, auctionCapacity, "funding == 100");
        assertEq(address(callbacks), address(banker), "callbacks == banker");
        assertEq(fromVeecode(derivativeReference), bytes7(""), "no derivative");

        // Auction parameters
        (
            uint48 start,
            uint48 conclusion,
            uint8 quoteTokenDecimals,
            uint8 baseTokenDecimals,
            bool capacityInQuote,
            uint256 capacity,
            ,
        ) = empa.lotData(0);

        assertEq(start, auctionStart, "start == auctionStart");
        assertEq(
            conclusion,
            auctionStart + auctionDuration,
            "conclusion == auctionStart + auctionDuration"
        );
        assertEq(
            quoteTokenDecimals, stablecoin.decimals(), "quoteTokenDecimals == stablecoin.decimals()"
        );
        assertEq(
            baseTokenDecimals, stablecoin.decimals(), "baseTokenDecimals == stablecoin.decimals()"
        );
        assertFalse(capacityInQuote, "!capacityInQuote");
        assertEq(capacity, auctionCapacity, "capacity == auctionCapacity");

        // EMP auction parameters
        {
            // minPrice is expected to be 1 quote token per base token, with the discount applied
            console2.log("maxDiscount", maxDiscount);
            uint256 expectedMinPrice = 1e18 * (100e2 - maxDiscount) / 100e2;
            console2.log("expectedMinPrice", expectedMinPrice);
            // minBidSize is in terms of quote tokens
            // It assumes the worst case scenario, where the auction has many small bids of quantity maxBids
            // Multiplying the minPrice (QT/BT) by the capacity (BT) gives the quantity of quote tokens at the minPrice
            // It is then divided by the underlying asset decimals to adjust the scale
            uint256 expectedMinBidSize = expectedMinPrice * auctionCapacity / (maxBids * 1e18);
            console2.log("expectedMinBidSize", expectedMinBidSize);
            // minFilled is the minFillPercent * capacity
            uint256 expectedMinFilled = minFillPercent * auctionCapacity / 100e2;
            console2.log("expectedMinFilled", expectedMinFilled);

            IEncryptedMarginalPrice.AuctionData memory empData = empa.getAuctionData(0);
            assertEq(empData.minPrice, expectedMinPrice, "minPrice");
            assertEq(empData.minBidSize, expectedMinBidSize, "minBidSize");
            assertEq(empData.minFilled, expectedMinFilled, "minFilled");
        }

        // Curation
        (address curator, bool curated,,,) = auctionHouse.lotFees(0);

        assertEq(curator, address(banker), "curator == banker");
        assertTrue(curated, "curated");

        // Convertible debt token
        assertEq(
            ERC20(baseToken).totalSupply(),
            auctionCapacity,
            "baseToken.totalSupply() == auctionCapacity"
        );

        ConvertibleDebtToken cdt = ConvertibleDebtToken(baseToken);
        (ERC20 underlying, ERC20 convertsTo, uint48 maturity, uint256 conversionPrice) =
            cdt.getTokenData();

        assertEq(cdt.decimals(), 18, "CDT decimals");
        assertEq(address(underlying), address(stablecoin), "CDT underlying");
        assertEq(address(convertsTo), address(mgst), "CDT convertsTo");
        assertEq(maturity, debtTokenParams.maturity, "CDT maturity");
        assertEq(conversionPrice, debtTokenConversionPrice, "CDT conversionPrice");
    }
}
