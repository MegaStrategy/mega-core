// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {ROLESv1} from "src/modules/ROLES/ROLES.v1.sol";

import {BankerTest} from "../BankerTest.sol";

contract BankerInitializeTest is BankerTest {
    // ======= Tests ======= //

    // given the caller is not permissioned
    //  [X] it reverts
    // [X] it activates the policy
    // [X] it sets the values

    function test_callerIsNotPermissioned_reverts() public {
        vm.expectRevert(
            abi.encodeWithSelector(ROLESv1.ROLES_RequireRole.selector, bytes32("admin"))
        );

        // Call
        banker.initialize(maxDiscount, minFillPercent, referrerFee, maxBids);
    }

    function test_success() public {
        vm.prank(admin);
        banker.initialize(maxDiscount, minFillPercent, referrerFee, maxBids);

        assertEq(banker.active(), true, "active");
        assertEq(banker.maxDiscount(), maxDiscount, "maxDiscount");
        assertEq(banker.minFillPercent(), minFillPercent, "minFillPercent");
        assertEq(banker.referrerFee(), referrerFee, "referrerFee");
        assertEq(banker.maxBids(), maxBids, "maxBids");
    }
}
