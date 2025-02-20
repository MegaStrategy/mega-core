// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import {ROLESv1} from "src/modules/ROLES/ROLES.v1.sol";
import {IBanker} from "src/policies/interfaces/IBanker.sol";
import {BankerTest} from "../BankerTest.sol";

contract BankerInitializeTest is BankerTest {
    // ======= Tests ======= //

    // given the caller is not permissioned
    //  [X] it reverts
    // given the contract is already active
    //  [X] it reverts
    // [X] it activates the policy
    // [X] it sets the values

    function test_callerIsNotPermissioned_reverts() public {
        // Expect revert
        vm.expectRevert(
            abi.encodeWithSelector(ROLESv1.ROLES_RequireRole.selector, bytes32("emergency"))
        );

        // Call
        banker.initialize(maxDiscount, minFillPercent, referrerFee, maxBids);
    }

    function test_policyAlreadyActive_reverts() public givenPolicyIsActive {
        // Expect revert
        vm.expectRevert(abi.encodeWithSelector(IBanker.InvalidState.selector));

        // Call
        vm.prank(emergency);
        banker.initialize(maxDiscount, minFillPercent, referrerFee, maxBids);
    }

    function test_success() public {
        vm.prank(emergency);
        banker.initialize(maxDiscount, minFillPercent, referrerFee, maxBids);

        assertEq(banker.locallyActive(), true, "active");
        assertEq(banker.maxDiscount(), maxDiscount, "maxDiscount");
        assertEq(banker.minFillPercent(), minFillPercent, "minFillPercent");
        assertEq(banker.referrerFee(), referrerFee, "referrerFee");
        assertEq(banker.maxBids(), maxBids, "maxBids");
    }
}
