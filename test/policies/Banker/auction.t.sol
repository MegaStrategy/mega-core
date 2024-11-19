// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Banker} from "src/policies/Banker.sol";
import {ROLESv1} from "src/modules/ROLES/ROLES.v1.sol";
import {IAuction} from "axis-core-1.0.1/interfaces/modules/IAuction.sol";
import {ConvertibleDebtToken} from "src/misc/ConvertibleDebtToken.sol";
import {Veecode, fromKeycode, keycodeFromVeecode} from "axis-core-1.0.1/modules/Keycode.sol";
import {ICallback} from "axis-core-1.0.1/interfaces/ICallback.sol";

import {BankerTest} from "./BankerTest.sol";

contract BankerAuctionTest is BankerTest {
    event DebtAuction(uint96 lotId);

    // ======= Modifiers ======= //

    // ======= Tests ======= //

    // when the policy is not active
    // [X] it reverts
    // when the caller is not permissioned
    // [X] it reverts
    // when the auction parameters are invalid
    // [X] it reverts
    // when the debt token maturity date is now or in the past
    // [X] it reverts
    // when the debt token asset is the zero address
    // [X] it reverts
    // given the parameters are valid
    // [ ] it creates an EMP auction with the given auction parameters
    // [ ] the AuctionHouse receives the capacity in debt tokens
    // [ ] the policy is the curator
    // [ ] the policy has accepted curation
    // [ ] the DebtAuction event is emitted

    function test_policyNotActive() public {
        vm.expectRevert(Banker.Inactive.selector);

        // Call
        vm.prank(manager);
        banker.auction(debtTokenParams, auctionParams);
    }

    function test_callerNotPermissioned() public {
        vm.expectRevert(
            abi.encodeWithSelector(ROLESv1.ROLES_RequireRole.selector, bytes32("manager"))
        );

        // Call
        vm.prank(admin);
        banker.auction(debtTokenParams, auctionParams);
    }

    function test_debtToken_zeroAddress()
        public
        givenPolicyIsActive
        givenDebtTokenAsset(address(0))
    {
        vm.expectRevert();

        // Call
        vm.prank(manager);
        banker.auction(debtTokenParams, auctionParams);
    }

    function test_auctionParameters_invalid() public givenPolicyIsActive {
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

    function test_debtTokenMaturity_invalid(
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
        // Expect emit
        emit DebtAuction(1);
        vm.expectEmit(address(banker));

        // Call
        vm.prank(manager);
        banker.auction(debtTokenParams, auctionParams);

        // Assertions
        // EMP auction is created
        (
            address seller,
            ,
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
            fromKeycode(keycodeFromVeecode(auctionReference)), "EMPA", "auction module == EMPA"
        );
        assertEq(funding, auctionCapacity, "funding == 100");
        assertEq(address(callbacks), address(banker), "callbacks == banker");
        assertEq(fromKeycode(keycodeFromVeecode(derivativeReference)), "", "no derivative");

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
    }
}
