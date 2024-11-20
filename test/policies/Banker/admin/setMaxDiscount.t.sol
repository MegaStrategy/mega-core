// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {ROLESv1} from "src/modules/ROLES/ROLES.v1.sol";
import {Banker} from "src/policies/Banker.sol";

import {BankerTest} from "../BankerTest.sol";

contract BankerSetMaxDiscountTest is BankerTest {
    // ======= Tests ======= //

    // given the caller is not permissioned
    //  [X] it reverts
    // when the max discount is greater than 100%
    //  [X] it reverts
    // when the max discount is <= 100%
    //  [X] it sets the max discount

    function test_callerIsNotPermissioned_reverts() public {
        vm.expectRevert(
            abi.encodeWithSelector(ROLESv1.ROLES_RequireRole.selector, bytes32("admin"))
        );

        banker.setMaxDiscount(maxDiscount);
    }

    function test_maxDiscount_greaterThan100Percent_reverts() public {
        vm.expectRevert(abi.encodeWithSelector(Banker.InvalidParam.selector, "discount"));

        vm.prank(admin);
        banker.setMaxDiscount(100e2 + 1);
    }

    function test_success(
        uint48 maxDiscount_
    ) public {
        uint48 maxDiscount = uint48(bound(maxDiscount_, 0, 100e2));

        // Call
        vm.prank(admin);
        banker.setMaxDiscount(maxDiscount);

        // Assert
        assertEq(banker.maxDiscount(), maxDiscount, "maxDiscount");
    }
}
