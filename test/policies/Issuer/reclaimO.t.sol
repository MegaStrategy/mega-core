// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {IssuerTest} from "./IssuerTest.sol";

import {ROLESv1} from "src/modules/ROLES/ROLES.v1.sol";
import {FixedStrikeOptionToken as oToken} from "src/lib/oTokens/FixedStrikeOptionToken.sol";
import {FixedStrikeOptionTeller} from "src/lib/oTokens/FixedStrikeOptionTeller.sol";

import {IIssuer} from "src/policies/interfaces/IIssuer.sol";
import {ERC20} from "solmate-6.8.0/tokens/ERC20.sol";

contract IssuerReclaimOTest is IssuerTest {
    event oTokenReclaimed(address indexed token, uint256 amount);

    // test cases
    // when the caller does not have the admin role
    //  [X] it reverts
    // when the policy is not locally active
    //  [X] it reverts
    // when the oToken was not created by this contract
    //  [X] it reverts
    // when the oToken has not expired
    //  [X] it reverts
    // when oTokens were exercised
    //  [X] it burns the protocol tokens that were reclaimed
    //  [X] it transfers the quote tokens to the treasury
    //  [X] it emits an oTokenReclaimed event
    // [X] it burns the protocol tokens that were reclaimed
    // [X] it transfers the quote tokens to the treasury
    // [X] it emits an oTokenReclaimed event

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
        vm.assume(caller_ != admin);

        vm.prank(caller_);
        vm.expectRevert(
            abi.encodeWithSelector(ROLESv1.ROLES_RequireRole.selector, bytes32("admin"))
        );
        issuer.issueO(token, recipient, amount);
    }

    function test_shutdown_reverts() public givenOTokenCreated givenLocallyInactive {
        vm.expectRevert(abi.encodeWithSelector(IIssuer.Inactive.selector));

        vm.prank(admin);
        issuer.issueO(token, recipient, amount);
    }

    function test_oTokenNotCreatedByIssuer_reverts() public givenOTokenCreated {
        address _token = address(1000);

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(IIssuer.InvalidParam.selector, "token"));
        issuer.issueO(_token, recipient, amount);
    }

    function test_oTokenNotExpired_reverts() public givenOTokenCreated {
        // Expect revert
        vm.expectRevert(
            abi.encodeWithSelector(FixedStrikeOptionTeller.Teller_NotExpired.selector, expiry)
        );

        // Reclaim the oToken
        vm.prank(admin);
        issuer.reclaimO(token);
    }

    function test_oTokensExercised_reclaim() public givenOTokenCreated {
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

        uint256 reclaimedAmount = amount - exercisedAmount;

        uint256 mgstTotalSupplyBefore = mgst.totalSupply();

        // Warp to expiry
        vm.warp(expiry);

        // Expect event
        vm.expectEmit(true, true, true, true);
        emit oTokenReclaimed(token, reclaimedAmount);

        // Reclaim the oToken
        vm.prank(admin);
        issuer.reclaimO(token);

        // Check the balances
        assertEq(mgst.balanceOf(address(teller)), 0, "teller: MGST balance");
        assertEq(mgst.balanceOf(address(issuer)), 0, "issuer: MGST balance");
        assertEq(mgst.balanceOf(address(TRSRY)), 0, "treasury: MGST balance");
        assertEq(mgst.totalSupply(), mgstTotalSupplyBefore - reclaimedAmount, "MGST total supply");

        assertEq(quoteToken.balanceOf(address(teller)), 0, "teller: quoteToken balance");
        assertEq(quoteToken.balanceOf(address(issuer)), 0, "issuer: quoteToken balance");
        assertEq(
            quoteToken.balanceOf(address(TRSRY)), exercisedAmount, "treasury: quoteToken balance"
        );
    }

    function test_reclaim() public givenOTokenCreated {
        // Issue the oToken
        vm.prank(admin);
        issuer.issueO(token, recipient, amount);

        uint256 exercisedAmount = 0;
        uint256 reclaimedAmount = amount - exercisedAmount;

        uint256 mgstTotalSupplyBefore = mgst.totalSupply();

        // Warp to expiry
        vm.warp(expiry);

        // Expect event
        vm.expectEmit(true, true, true, true);
        emit oTokenReclaimed(token, reclaimedAmount);

        // Reclaim the oToken
        vm.prank(admin);
        issuer.reclaimO(token);

        // Check the balances
        assertEq(mgst.balanceOf(address(teller)), 0, "teller: MGST balance");
        assertEq(mgst.balanceOf(address(issuer)), 0, "issuer: MGST balance");
        assertEq(mgst.balanceOf(address(TRSRY)), 0, "treasury: MGST balance");
        assertEq(mgst.totalSupply(), mgstTotalSupplyBefore - reclaimedAmount, "MGST total supply");

        assertEq(quoteToken.balanceOf(address(teller)), 0, "teller: quoteToken balance");
        assertEq(quoteToken.balanceOf(address(issuer)), 0, "issuer: quoteToken balance");
        assertEq(
            quoteToken.balanceOf(address(TRSRY)), exercisedAmount, "treasury: quoteToken balance"
        );
    }
}
