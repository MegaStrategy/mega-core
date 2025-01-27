// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {IssuerTest} from "./IssuerTest.sol";
import {ROLESv1} from "src/modules/ROLES/ROLES.v1.sol";
import {IIssuer} from "src/policies/interfaces/IIssuer.sol";

contract IssuerShutdownTest is IssuerTest {
    // when the caller does not have the admin role
    //  [X] it reverts
    // given the contract is already inactive
    //  [X] it reverts
    // [X] it disables the contract

    function test_callerNotPermissioned_reverts(
        address caller_
    ) public {
        vm.assume(caller_ != admin);

        vm.expectRevert(
            abi.encodeWithSelector(ROLESv1.ROLES_RequireRole.selector, bytes32("admin"))
        );

        vm.prank(caller_);
        issuer.shutdown();
    }

    function test_policyNotActive_reverts() public givenLocallyInactive {
        // Expect revert
        vm.expectRevert(abi.encodeWithSelector(IIssuer.InvalidState.selector));

        // Call
        vm.prank(admin);
        issuer.shutdown();
    }

    function test_shutdown() public {
        vm.prank(admin);
        issuer.shutdown();

        assertEq(issuer.locallyActive(), false, "locallyActive");
    }
}
