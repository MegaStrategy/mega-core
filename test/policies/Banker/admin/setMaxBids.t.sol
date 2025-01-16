// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {IBanker} from "src/policies/interfaces/IBanker.sol";
import {ROLESv1} from "src/modules/ROLES/ROLES.v1.sol";

import {BankerTest} from "../BankerTest.sol";

contract BankerSetMaxBidsTest is BankerTest {
    // ======= Tests ======= //

    // given the caller is not permissioned
    //  [X] it reverts
    // when the max bids is zero
    //  [X] it reverts
    // when the max bids is > 0
    //  [X] it sets the max bids

    function test_callerIsNotPermissioned_reverts() public {
        vm.expectRevert(
            abi.encodeWithSelector(ROLESv1.ROLES_RequireRole.selector, bytes32("admin"))
        );

        banker.setMaxBids(maxBids);
    }

    function test_maxBids_zero_reverts() public {
        vm.expectRevert(abi.encodeWithSelector(IBanker.InvalidParam.selector, "maxBids"));

        // Call
        vm.prank(admin);
        banker.setMaxBids(0);
    }

    function test_success(
        uint256 maxBids_
    ) public {
        uint256 maxBids = bound(maxBids_, 1, type(uint256).max);

        // Call
        vm.prank(admin);
        banker.setMaxBids(maxBids);

        // Assert
        assertEq(banker.maxBids(), maxBids, "maxBids");
    }
}
