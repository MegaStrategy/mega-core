// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import {ROLESv1} from "src/modules/ROLES/ROLES.v1.sol";
import {IBanker} from "src/policies/interfaces/IBanker.sol";
import {BankerTest} from "../BankerTest.sol";

contract BankerShutdownTest is BankerTest {
    // ======= Tests ======= //

    // when the caller is not permissioned
    //  [X] it reverts
    // when the policy is not active
    //  [X] it reverts
    // [X] it sets the policy to inactive

    function test_callerNotPermissioned_reverts() public {
        // Expect revert
        vm.expectRevert(
            abi.encodeWithSelector(ROLESv1.ROLES_RequireRole.selector, bytes32("admin"))
        );

        // Call
        banker.shutdown();
    }

    function test_policyNotActive_reverts() public {
        // Expect revert
        vm.expectRevert(abi.encodeWithSelector(IBanker.InvalidState.selector));

        // Call
        vm.prank(admin);
        banker.shutdown();
    }

    function test_policyActive() public givenPolicyIsActive {
        vm.prank(admin);
        banker.shutdown();

        // Assert
        assertEq(banker.locallyActive(), false, "policy should be inactive");
    }
}
