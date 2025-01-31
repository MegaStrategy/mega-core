// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {IssuerTest} from "./IssuerTest.sol";
import {ROLESv1} from "src/modules/ROLES/ROLES.v1.sol";
import {IIssuer} from "src/policies/interfaces/IIssuer.sol";

contract IssuerActivateTest is IssuerTest {
    // when the caller does not have the admin role
    //  [X] it reverts
    // given the contract is already active
    //  [X] it reverts
    // [X] it enables the contract

    function test_callerNotPermissioned_reverts(
        address caller_
    ) public {
        vm.assume(caller_ != admin);

        vm.expectRevert(
            abi.encodeWithSelector(ROLESv1.ROLES_RequireRole.selector, bytes32("admin"))
        );

        vm.prank(caller_);
        issuer.activate();
    }

    function test_policyAlreadyActive_reverts() public {
        // Expect revert
        vm.expectRevert(abi.encodeWithSelector(IIssuer.InvalidState.selector));

        // Call
        vm.prank(admin);
        issuer.activate();
    }

    function test_activate() public givenLocallyInactive {
        vm.prank(admin);
        issuer.activate();

        assertEq(issuer.locallyActive(), true, "locallyActive");
    }
}
