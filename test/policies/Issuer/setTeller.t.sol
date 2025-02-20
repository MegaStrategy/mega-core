// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import {ROLESv1} from "src/modules/ROLES/ROLES.v1.sol";

import {IssuerTest} from "./IssuerTest.sol";

contract IssuerSetTellerTest is IssuerTest {
    // test cases
    // when the caller does not have the admin role
    //  [X] it reverts
    // otherwise
    //  [X] it sets the teller address

    function test_callerNotPermissioned_reverts(
        address caller_
    ) public {
        vm.assume(caller_ != admin);

        vm.prank(caller_);
        vm.expectRevert(
            abi.encodeWithSelector(ROLESv1.ROLES_RequireRole.selector, bytes32("admin"))
        );
        issuer.setTeller(address(1000));
    }

    function test_success(
        address teller_
    ) public {
        vm.prank(admin);
        issuer.setTeller(teller_);
        assertEq(address(issuer.teller()), teller_);
    }
}
