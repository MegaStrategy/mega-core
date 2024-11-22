// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Issuer} from "src/policies/Issuer.sol";
import {ROLESv1} from "src/modules/ROLES/ROLES.v1.sol";
import {FixedStrikeOptionTeller as oTeller} from "src/lib/oTokens/FixedStrikeOptionTeller.sol";
import {FixedStrikeOptionToken as oToken} from "src/lib/oTokens/FixedStrikeOptionToken.sol";

import {IssuerTest} from "./IssuerTest.sol";

contract IssuerIssueOTest is IssuerTest {
    // test cases
    // [X] when the caller does not have the admin role
    //    [X] it reverts
    // [X] when the oToken is not created by the issuer
    //    [X] it reverts
    // [X] when the to address is zero
    //    [X] it reverts
    // [X] when the amount is zero
    //    [X] it reverts
    // [X] otherwise
    //    [X] it mints the amount of TOKENs
    //    [X] it mints oTokens using the minted TOKENs as collateral (these are held by the teller)
    //    [X] it transfers the oTokens to the recipient

    address public token;
    address public recipient = address(200);
    uint256 public amount = 1e18;

    modifier givenOTokenCreated() {
        vm.prank(admin);
        token = issuer.createO(address(quoteToken), uint48(block.timestamp + 1 days), 1e18);
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

    function test_oTokenNotCreatedByIssuer_reverts() public givenOTokenCreated {
        address _token = address(1000);

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(Issuer.InvalidParam.selector, "token"));
        issuer.issueO(_token, recipient, amount);
    }

    function test_toAddressZero_reverts() public givenOTokenCreated {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(Issuer.InvalidParam.selector, "to"));
        issuer.issueO(token, address(0), amount);
    }

    function test_amountZero_reverts() public givenOTokenCreated {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(Issuer.InvalidParam.selector, "amount"));
        issuer.issueO(token, recipient, 0);
    }

    function test_success(address to_, uint128 amount_) public givenOTokenCreated {
        vm.assume(amount_ != 0);
        vm.assume(to_ != address(0));

        vm.prank(admin);
        issuer.issueO(token, to_, amount_);
        assertEq(TOKEN.balanceOf(address(teller)), amount_);
        assertEq(oToken(token).balanceOf(to_), amount_);
    }
}
