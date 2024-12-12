// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Banker} from "src/policies/Banker.sol";
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

import {BankerTest} from "./BankerTest.sol";

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
    // given the parameters are valid
    //  [X] it creates an EMP auction with the given auction parameters
    //  [X] the AuctionHouse receives the capacity in debt tokens
    //  [X] the policy is the curator
    //  [X] the policy has accepted curation
    //  [X] the DebtAuction event is emitted

    function test_policyNotActive_reverts() public {
        vm.expectRevert(Banker.Inactive.selector);

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
    }
}
