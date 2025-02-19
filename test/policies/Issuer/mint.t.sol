// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import {ROLESv1} from "src/modules/ROLES/ROLES.v1.sol";

import {IssuerTest} from "./IssuerTest.sol";
import {IIssuer} from "src/policies/interfaces/IIssuer.sol";

contract IssuerMintTest is IssuerTest {
    // test cases
    // when the caller does not have the admin role
    //  [X] it reverts
    // when the policy is not locally active
    //  [X] it reverts
    // when the to address is zero
    //  [X] it reverts
    // when the amount is zero
    //  [X] it reverts
    // otherwise
    //  [X] it mints the given amount of TOKEN to the given address

    function test_callerNotPermissioned_reverts(
        address caller_
    ) public {
        vm.assume(caller_ != admin);

        vm.prank(caller_);
        vm.expectRevert(
            abi.encodeWithSelector(ROLESv1.ROLES_RequireRole.selector, bytes32("admin"))
        );
        issuer.mint(address(this), 1e18);
    }

    function test_shutdown_reverts() public givenLocallyInactive {
        vm.expectRevert(abi.encodeWithSelector(IIssuer.Inactive.selector));

        vm.prank(admin);
        issuer.mint(address(this), 1e18);
    }

    function test_toAddressZero_reverts() public {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(IIssuer.InvalidParam.selector, "to"));
        issuer.mint(address(0), 1e18);
    }

    function test_amountZero_reverts() public {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(IIssuer.InvalidParam.selector, "amount"));
        issuer.mint(address(this), 0);
    }

    function test_success(address to_, uint128 amount_) public {
        vm.assume(amount_ != 0);
        vm.assume(to_ != address(0));

        vm.prank(admin);
        issuer.mint(to_, amount_);
        assertEq(mgst.balanceOf(to_), amount_);
    }
}
