// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {IssuerTest} from "./IssuerTest.sol";
import {ROLESv1} from "src/modules/ROLES/ROLES.v1.sol";

contract IssuerActivateTest is IssuerTest {
    // when the caller does not have the admin role
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

    function test_activate() public {
        vm.prank(admin);
        issuer.activate();

        assertEq(issuer.locallyActive(), true, "locallyActive");
    }
}
