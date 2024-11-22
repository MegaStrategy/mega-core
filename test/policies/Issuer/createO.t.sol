// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {ROLESv1} from "src/modules/ROLES/ROLES.v1.sol";
import {FixedStrikeOptionTeller as oTeller} from "src/lib/oTokens/FixedStrikeOptionTeller.sol";
import {FixedStrikeOptionToken as oToken} from "src/lib/oTokens/FixedStrikeOptionToken.sol";

import {IssuerTest} from "./IssuerTest.sol";

contract IssuerCreateOTest is IssuerTest {
    // test cases
    // [X] when the caller does not have the admin role
    //    [X] it reverts
    // [X] when the quote token is the zero address
    //    [X] it reverts
    // [X] when the quote token is not a contract
    //    [X] it reverts
    // [X] when the expiry is not in the future by min option duration
    //    [X] it reverts
    // [X] when the convertible price is below the minimum from the teller
    //    [X] it reverts
    // [X] otherwise
    //    [X] it creates an oToken with the given parameters (and hardcoded ones)
    //    [X] it sets the createdBy mapping on the issuer to true for the oToken address

    function test_callerNotPermissioned_reverts(
        address caller_
    ) public {
        vm.assume(caller_ != admin);

        vm.prank(caller_);
        vm.expectRevert(
            abi.encodeWithSelector(ROLESv1.ROLES_RequireRole.selector, bytes32("admin"))
        );
        issuer.createO(address(quoteToken), uint48(block.timestamp + 1 days), 1e18);
    }

    function test_quoteToken_zeroAddress_reverts() public {
        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(
                oTeller.Teller_InvalidParams.selector, 1, abi.encodePacked(address(0))
            )
        );
        issuer.createO(address(0), uint48(block.timestamp + 1 days), 1e18);
    }

    function test_quoteToken_notContract_reverts() public {
        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(
                oTeller.Teller_InvalidParams.selector, 1, abi.encodePacked(address(1000))
            )
        );
        issuer.createO(address(1000), uint48(block.timestamp + 1 days), 1e18);
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
        issuer.createO(address(quoteToken), uint48(block.timestamp), 1e18);
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
        issuer.createO(address(quoteToken), uint48(block.timestamp + 1 days), price);
    }

    function test_success(uint48 expiry_, uint256 price_) public {
        uint48 expiry = uint48(bound(expiry_, block.timestamp + 1 days, type(uint48).max));
        uint256 price = bound(price_, 1e9, type(uint256).max);

        vm.prank(admin);
        oToken token = oToken(issuer.createO(address(quoteToken), expiry, price));

        // Check that the created by mapping is set on the issuer
        assertTrue(issuer.createdBy(address(token)));

        // Check that the oToken's parameters are correct
        assertEq(address(token.payout()), address(TOKEN));
        assertEq(address(token.quote()), address(quoteToken));
        assertEq(token.eligible(), uint48(block.timestamp) / 1 days * 1 days);
        assertEq(token.expiry(), expiry / 1 days * 1 days);
        assertEq(token.strike(), price);
        assertTrue(token.call());
        assertEq(token.receiver(), address(TRSRY));
        assertEq(token.teller(), address(teller));
    }
}
