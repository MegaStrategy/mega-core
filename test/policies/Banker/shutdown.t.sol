// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {ROLESv1} from "src/modules/ROLES/ROLES.v1.sol";
import {BankerTest} from "./BankerTest.sol";

contract BankerShutdownTest is BankerTest {
    // ======= Tests ======= //

    // when the caller is not permissioned
    // [X] it reverts
    // when the policy is not active
    // [X] the policy is still inactive
    // when the policy is active
    // [X] it sets the policy to inactive

    function test_callerNotPermissioned_reverts() public {
        vm.expectRevert(
            abi.encodeWithSelector(ROLESv1.ROLES_RequireRole.selector, bytes32("admin"))
        );
        banker.shutdown();
    }

    function test_policyNotActive() public {
        vm.prank(admin);
        banker.shutdown();

        // Assert
        assertEq(banker.active(), false, "policy should be inactive");
    }

    function test_policyActive() public givenPolicyIsActive {
        vm.prank(admin);
        banker.shutdown();

        // Assert
        assertEq(banker.active(), false, "policy should be inactive");
    }
}
