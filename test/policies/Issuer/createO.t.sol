// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {ROLESv1} from "src/modules/ROLES/ROLES.v1.sol";
import {FixedStrikeOptionTeller as oTeller} from "src/lib/oTokens/FixedStrikeOptionTeller.sol";
import {FixedStrikeOptionToken as oToken} from "src/lib/oTokens/FixedStrikeOptionToken.sol";

import {IssuerTest} from "./IssuerTest.sol";

import {IIssuer} from "src/policies/interfaces/IIssuer.sol";

contract IssuerCreateOTest is IssuerTest {
    // test cases
    // when the caller does not have the admin role
    //  [X] it reverts
    // when the policy is not locally active
    //  [X] it reverts
    // when the quote token is the zero address
    //  [X] it reverts
    // when the quote token is not a contract
    //  [X] it reverts
    // when the expiry is not in the future by min option duration
    //  [X] it reverts
    // when the convertible price is below the minimum from the teller
    //  [X] it reverts
    // otherwise
    //  [X] it creates an oToken with the given parameters (and hardcoded ones)
    //  [X] it sets the createdBy mapping on the issuer to true for the oToken address
    //  [X] it sets the oToken recipient to the Issuer policy
    // when vestingStart and vestingExpiry are provided
    //  when vestingExpiry is after the option token expiry
    //   [X] it reverts
    //  [X] a vesting token is deployed with the oToken as the underlying token
    //  [X] the vesting token has the start and expiry set

    function test_callerNotPermissioned_reverts(
        address caller_
    ) public {
        vm.assume(caller_ != admin);

        vm.prank(caller_);
        vm.expectRevert(
            abi.encodeWithSelector(ROLESv1.ROLES_RequireRole.selector, bytes32("admin"))
        );
        issuer.createO(address(quoteToken), uint48(block.timestamp + 1 days), 1e18, 0, 0);
    }

    function test_shutdown_reverts() public givenLocallyInactive {
        vm.expectRevert(abi.encodeWithSelector(IIssuer.Inactive.selector));

        vm.prank(admin);
        issuer.createO(address(quoteToken), uint48(block.timestamp + 1 days), 1e18, 0, 0);
    }

    function test_quoteToken_zeroAddress_reverts() public {
        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(
                oTeller.Teller_InvalidParams.selector, 1, abi.encodePacked(address(0))
            )
        );
        issuer.createO(address(0), uint48(block.timestamp + 1 days), 1e18, 0, 0);
    }

    function test_quoteToken_notContract_reverts() public {
        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(
                oTeller.Teller_InvalidParams.selector, 1, abi.encodePacked(address(1000))
            )
        );
        issuer.createO(address(1000), uint48(block.timestamp + 1 days), 1e18, 0, 0);
    }

    function test_expiryNotFuture_reverts() public {
        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(
                oTeller.Teller_InvalidParams.selector,
                3,
                abi.encodePacked(uint48(block.timestamp) / 1 days * 1 days)
            )
        );
        issuer.createO(address(quoteToken), uint48(block.timestamp), 1e18, 0, 0);
    }

    function test_convertiblePriceTooLow_reverts(
        uint256 price_
    ) public {
        uint256 price = bound(price_, 0, 1e9 - 1);

        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(
                oTeller.Teller_InvalidParams.selector, 6, abi.encodePacked(price)
            )
        );
        issuer.createO(address(quoteToken), uint48(block.timestamp + 1 days), price, 0, 0);
    }

    function test_success(uint48 expiry_, uint256 price_) public {
        uint48 expiry = uint48(bound(expiry_, block.timestamp + 1 days, type(uint48).max));
        uint256 price = bound(price_, 1e9, type(uint256).max);

        vm.prank(admin);
        oToken token = oToken(issuer.createO(address(quoteToken), expiry, price, 0, 0));

        // Check that the created by mapping is set on the issuer
        assertTrue(issuer.createdBy(address(token)));

        // No vesting token should be deployed
        assertEq(issuer.optionTokenToVestingTokenId(address(token)), 0, "vestingTokenId");
        assertEq(issuer.optionTokenToVestingToken(address(token)), address(0), "vestingToken");

        // Check that the oToken's parameters are correct
        assertEq(address(token.payout()), address(mgst));
        assertEq(address(token.quote()), address(quoteToken));
        assertEq(token.eligible(), uint48(block.timestamp) / 1 days * 1 days);
        assertEq(token.expiry(), expiry / 1 days * 1 days);
        assertEq(token.strike(), price);
        assertTrue(token.call());
        assertEq(token.receiver(), address(issuer));
        assertEq(token.teller(), address(teller));
    }

    function test_vestingEnabled_vestingExpiryAfterOptionExpiry_reverts(
        uint48 vestingExpiryDuration_
    ) public {
        uint48 optionExpiry_ = uint48(block.timestamp + 30 days);
        uint256 price_ = 20e18;
        uint48 vestingStart_ = uint48(block.timestamp + 1 days);
        uint48 vestingExpiry_ = uint48(
            bound(vestingExpiryDuration_, uint48(optionExpiry_ - 1 weeks + 1), type(uint48).max)
        );

        vm.expectRevert(abi.encodeWithSelector(IIssuer.InvalidParam.selector, "vesting expiry"));

        vm.prank(admin);
        issuer.createO(address(quoteToken), optionExpiry_, price_, vestingStart_, vestingExpiry_);
    }

    function test_vestingEnabled_success(
        uint48 vestingExpiryDuration_
    ) public {
        uint48 optionExpiry_ = uint48(block.timestamp + 30 days);
        uint256 price_ = 20e18;
        uint48 vestingStart_ = uint48(block.timestamp + 1 days);
        uint48 vestingExpiry_ = uint48(
            bound(vestingExpiryDuration_, vestingStart_ + 1, uint48(optionExpiry_ - 1 weeks))
        );

        vm.prank(admin);
        oToken token = oToken(
            issuer.createO(
                address(quoteToken), optionExpiry_, price_, vestingStart_, vestingExpiry_
            )
        );

        // Determine the vesting token ID
        uint256 vestingTokenId =
            vestingModule.computeId(address(token), abi.encode(vestingStart_, vestingExpiry_));

        // Check that the created by mapping is set on the issuer
        assertTrue(issuer.createdBy(address(token)), "createdBy");

        // Check that the vesting token ID is set on the issuer
        assertEq(
            issuer.optionTokenToVestingTokenId(address(token)), vestingTokenId, "vestingTokenId"
        );

        // Check that the vesting token's parameters are correct
        (
            bool vestingTokenExists,
            address vestingToken,
            address vestingUnderlyingToken,
            uint256 vestingSupply,
            bytes memory vestingData
        ) = vestingModule.tokenMetadata(vestingTokenId);
        assertTrue(vestingTokenExists, "exists");
        assertEq(vestingUnderlyingToken, address(token), "vesting token underlying");
        assertEq(vestingSupply, 0, "vesting supply");
        (uint48 vestingStart, uint48 vestingExpiry) = abi.decode(vestingData, (uint48, uint48));
        assertEq(vestingStart, vestingStart_, "vesting start");
        assertEq(vestingExpiry, vestingExpiry_, "vesting expiry");

        // Check that the vesting token is set on the issuer
        assertEq(issuer.optionTokenToVestingToken(address(token)), vestingToken, "vestingToken");

        // Check that the oToken's parameters are correct
        assertEq(address(token.payout()), address(mgst), "payout");
        assertEq(address(token.quote()), address(quoteToken), "quote");
        assertEq(token.eligible(), uint48(block.timestamp) / 1 days * 1 days, "eligible");
        assertEq(token.expiry(), optionExpiry_ / 1 days * 1 days, "expiry");
        assertEq(token.strike(), price_, "strike");
        assertTrue(token.call(), "call");
        assertEq(token.receiver(), address(issuer), "receiver");
        assertEq(token.teller(), address(teller), "teller");
    }
}
