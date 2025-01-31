// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {IssuerTest} from "./IssuerTest.sol";

import {ROLESv1} from "src/modules/ROLES/ROLES.v1.sol";
import {FixedStrikeOptionToken as oToken} from "src/lib/oTokens/FixedStrikeOptionToken.sol";

import {IIssuer} from "src/policies/interfaces/IIssuer.sol";

contract IssuerSweepToTreasuryTest is IssuerTest {
    event SweptToTreasury(address indexed token, uint256 amount);

    // test cases
    // when the caller does not have the manager role
    //  [X] it reverts
    // when the policy is not locally active
    //  [X] it reverts
    // when there is no token balance
    //  [X] it does nothing
    // [X] it transfers the token balance to the treasury
    // [X] it emits a SweptToTreasury event

    address public token;
    address public recipient = address(200);
    uint256 public amount = 1e18;
    uint48 public expiry;

    modifier givenOTokenCreated() {
        expiry = uint48(block.timestamp + 1 days);

        vm.prank(admin);
        token = issuer.createO(address(quoteToken), expiry, 1e18, 0, 0);

        // Set the expiry as it can be changed by the teller
        expiry = oToken(token).expiry();
        _;
    }

    function test_callerNotPermissioned_reverts(
        address caller_
    ) public givenOTokenCreated {
        vm.assume(caller_ != manager);

        vm.prank(caller_);
        vm.expectRevert(
            abi.encodeWithSelector(ROLESv1.ROLES_RequireRole.selector, bytes32("manager"))
        );
        issuer.sweepToTreasury(address(quoteToken));
    }

    function test_shutdown_reverts() public givenOTokenCreated givenLocallyInactive {
        vm.expectRevert(abi.encodeWithSelector(IIssuer.Inactive.selector));

        vm.prank(manager);
        issuer.sweepToTreasury(address(quoteToken));
    }

    function test_givenTokenBalance() public givenOTokenCreated {
        // Issue the oToken
        vm.prank(admin);
        issuer.issueO(token, recipient, amount);

        uint256 exercisedAmount = 5e17;

        // Approve the teller to spend the oToken
        vm.prank(recipient);
        oToken(token).approve(address(teller), exercisedAmount);

        // Approve the teller to spend the quote token
        uint256 quoteAmount = exercisedAmount * oToken(token).strike() / 1e18;
        vm.prank(recipient);
        quoteToken.approve(address(teller), quoteAmount);

        // Mint quote token to the recipient
        quoteToken.mint(recipient, quoteAmount);

        // Exercise the oToken
        vm.prank(recipient);
        teller.exercise(oToken(token), exercisedAmount);

        uint256 mgstTotalSupplyBefore = mgst.totalSupply();

        // Expect event
        vm.expectEmit(true, true, true, true);
        emit SweptToTreasury(address(quoteToken), quoteAmount);

        // Sweep the proceeds
        vm.prank(manager);
        issuer.sweepToTreasury(address(quoteToken));

        // Check the balances
        assertEq(
            mgst.balanceOf(address(teller)),
            mgstTotalSupplyBefore - exercisedAmount,
            "teller: MGST balance"
        );
        assertEq(mgst.balanceOf(address(issuer)), 0, "issuer: MGST balance");
        assertEq(mgst.balanceOf(address(TRSRY)), 0, "treasury: MGST balance");
        assertEq(mgst.totalSupply(), mgstTotalSupplyBefore, "MGST total supply");

        assertEq(quoteToken.balanceOf(address(teller)), 0, "teller: quoteToken balance");
        assertEq(quoteToken.balanceOf(address(issuer)), 0, "issuer: quoteToken balance");
        assertEq(quoteToken.balanceOf(address(TRSRY)), quoteAmount, "treasury: quoteToken balance");
    }

    function test_withNoBalance() public givenOTokenCreated {
        // Issue the oToken
        vm.prank(admin);
        issuer.issueO(token, recipient, amount);

        uint256 mgstTotalSupplyBefore = mgst.totalSupply();

        // Sweep the proceeds
        vm.prank(manager);
        issuer.sweepToTreasury(address(quoteToken));

        // Check the balances
        assertEq(mgst.balanceOf(address(teller)), mgstTotalSupplyBefore, "teller: MGST balance");
        assertEq(mgst.balanceOf(address(issuer)), 0, "issuer: MGST balance");
        assertEq(mgst.balanceOf(address(TRSRY)), 0, "treasury: MGST balance");
        assertEq(mgst.totalSupply(), mgstTotalSupplyBefore, "MGST total supply");

        assertEq(quoteToken.balanceOf(address(teller)), 0, "teller: quoteToken balance");
        assertEq(quoteToken.balanceOf(address(issuer)), 0, "issuer: quoteToken balance");
        assertEq(quoteToken.balanceOf(address(TRSRY)), 0, "treasury: quoteToken balance");
    }
}
