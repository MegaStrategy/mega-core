// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import {ROLESv1} from "src/modules/ROLES/ROLES.v1.sol";
import {FixedStrikeOptionToken as oToken} from "src/lib/oTokens/FixedStrikeOptionToken.sol";

import {IssuerTest} from "./IssuerTest.sol";
import {IIssuer} from "src/policies/interfaces/IIssuer.sol";
import {ERC20} from "@solmate-6.8.0/tokens/ERC20.sol";

contract IssuerIssueOTest is IssuerTest {
    // test cases
    // when the caller does not have the admin role
    //  [X] it reverts
    // when the policy is not locally active
    //  [X] it reverts
    // when the oToken is not created by the issuer
    //  [X] it reverts
    // when the to address is zero
    //  [X] it reverts
    // when the amount is zero
    //  [X] it reverts
    // otherwise
    //  [X] it mints the amount of TOKENs
    //  [X] it mints oTokens using the minted TOKENs as collateral (these are held by the teller)
    //  [X] it transfers the oTokens to the recipient
    // given the oToken was created with vesting
    //  [X] the vesting token is issued to the recipient

    address public token;
    address public recipient = address(200);
    uint256 public amount = 1e18;

    modifier givenOTokenCreated() {
        vm.prank(admin);
        token = issuer.createO(address(quoteToken), uint48(block.timestamp + 1 days), 1e18, 0, 0);
        _;
    }

    modifier givenOTokenVestingCreated() {
        uint48 optionExpiry_ = uint48(block.timestamp + 30 days);

        vm.prank(admin);
        token = issuer.createO(
            address(quoteToken),
            optionExpiry_,
            1e18,
            uint48(block.timestamp),
            uint48(optionExpiry_ - 10 days)
        );
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

    function test_toAddressZero_reverts() public givenOTokenCreated {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(IIssuer.InvalidParam.selector, "to"));
        issuer.issueO(token, address(0), amount);
    }

    function test_amountZero_reverts() public givenOTokenCreated {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(IIssuer.InvalidParam.selector, "amount"));
        issuer.issueO(token, recipient, 0);
    }

    function test_success(
        uint128 amount_
    ) public givenOTokenCreated {
        vm.assume(amount_ != 0);
        address to_ = address(0xFFFFFFFF);

        vm.prank(admin);
        issuer.issueO(token, to_, amount_);

        assertEq(mgst.balanceOf(address(teller)), amount_, "teller: MGST balance");
        assertEq(oToken(token).balanceOf(to_), amount_, "to: oToken balance");
    }

    function test_vestingEnabled_success(
        uint128 amount_
    ) public givenOTokenVestingCreated {
        vm.assume(amount_ != 0);
        address to_ = address(0xFFFFFFFF);

        // Get the address of the vesting token
        address vestingToken = issuer.optionTokenToVestingToken(address(token));

        // Call function
        vm.prank(admin);
        issuer.issueO(token, to_, amount_);

        // MGST
        assertEq(mgst.balanceOf(address(vestingModule)), 0, "vesting module: MGST balance");
        assertEq(mgst.balanceOf(address(teller)), amount_, "teller: MGST balance");
        assertEq(mgst.balanceOf(to_), 0, "to: MGST balance");

        // oToken
        assertEq(
            oToken(token).balanceOf(address(vestingModule)),
            amount_,
            "vesting module: oToken balance"
        );
        assertEq(oToken(token).balanceOf(address(teller)), 0, "teller: oToken balance");
        assertEq(oToken(token).balanceOf(to_), 0, "to: oToken balance");

        // Vesting token
        assertEq(
            ERC20(vestingToken).balanceOf(address(vestingModule)),
            0,
            "vesting module: vesting token balance"
        );
        assertEq(ERC20(vestingToken).balanceOf(address(teller)), 0, "teller: vesting token balance");
        assertEq(ERC20(vestingToken).balanceOf(to_), amount_, "to: vesting token balance");
    }
}
