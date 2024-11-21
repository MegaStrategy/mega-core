// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {ROLESv1} from "src/modules/ROLES/ROLES.v1.sol";
import {Banker} from "src/policies/Banker.sol";

import {BankerTest} from "../BankerTest.sol";

contract BankerSetMinFillPercentTest is BankerTest {
    // ======= Tests ======= //

    // given the caller is not permissioned
    //  [X] it reverts
    // when the min fill percent is zero
    //  [X] it reverts
    // when the min fill percent is > 100%
    //  [X] it reverts
    // when the min fill percent is <= 100%
    //  [X] it sets the min fill percent

    function test_callerIsNotPermissioned_reverts() public {
        vm.expectRevert(
            abi.encodeWithSelector(ROLESv1.ROLES_RequireRole.selector, bytes32("admin"))
        );

        banker.setMinFillPercent(minFillPercent);
    }

    function test_minFillPercent_zero_reverts() public {
        vm.expectRevert(abi.encodeWithSelector(Banker.InvalidParam.selector, "minFillPercent"));

        vm.prank(admin);
        banker.setMinFillPercent(0);
    }

    function test_minFillPercent_greaterThan100Percent_reverts() public {
        vm.expectRevert(abi.encodeWithSelector(Banker.InvalidParam.selector, "minFillPercent"));

        vm.prank(admin);
        banker.setMinFillPercent(100e2 + 1);
    }

    function test_success(
        uint24 minFillPercent_
    ) public {
        uint24 minFillPercent = uint24(bound(minFillPercent_, 1, 100e2));

        // Call
        vm.prank(admin);
        banker.setMinFillPercent(minFillPercent);

        // Assert
        assertEq(banker.minFillPercent(), minFillPercent, "minFillPercent");
    }
}
