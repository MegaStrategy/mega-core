// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {ROLESv1} from "src/modules/ROLES/ROLES.v1.sol";

import {IssuerTest} from "./IssuerTest.sol";

contract IssuerSetVestingModuleTest is IssuerTest {
    // test cases
    // when the caller does not have the admin role
    //  [X] it reverts
    // otherwise
    //  [X] it sets the vesting module address

    function test_callerNotPermissioned_reverts(
        address caller_
    ) public {
        vm.assume(caller_ != admin);

        vm.prank(caller_);
        vm.expectRevert(
            abi.encodeWithSelector(ROLESv1.ROLES_RequireRole.selector, bytes32("admin"))
        );
        issuer.setVestingModule(address(1000));
    }

    function test_success(
        address vestingModule_
    ) public {
        vm.prank(admin);
        issuer.setVestingModule(vestingModule_);
        assertEq(address(issuer.vestingModule()), vestingModule_);
    }
}
