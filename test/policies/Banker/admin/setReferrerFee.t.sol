// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import {ROLESv1} from "src/modules/ROLES/ROLES.v1.sol";
import {IBanker} from "src/policies/interfaces/IBanker.sol";
import {toKeycode} from "axis-core-1.0.1/modules/Keycode.sol";
import {IFeeManager} from "axis-core-1.0.1/interfaces/IFeeManager.sol";

import {BankerTest} from "../BankerTest.sol";

contract BankerSetReferrerFeeTest is BankerTest {
    // ======= Tests ======= //

    // given the caller is not permissioned
    //  [X] it reverts
    // when the referrer fee is greater than the auction house's max referrer fee
    //  [X] it reverts
    // when the referrer fee is valid
    //  [X] it sets the referrer fee

    function test_callerIsNotPermissioned_reverts() public {
        vm.expectRevert(
            abi.encodeWithSelector(ROLESv1.ROLES_RequireRole.selector, bytes32("admin"))
        );

        banker.setReferrerFee(referrerFee);
    }

    function test_greaterThanMaxReferrerFee_reverts() public {
        // Set the auction house's max referrer fee to 10%
        vm.prank(OWNER);
        auctionHouse.setFee(toKeycode("EMPA"), IFeeManager.FeeType.MaxReferrer, 10e2);

        vm.expectRevert(abi.encodeWithSelector(IBanker.InvalidParam.selector, "referrerFee"));

        vm.prank(admin);
        banker.setReferrerFee(10e2 + 1);
    }

    function test_success(
        uint48 referrerFee_
    ) public {
        uint48 referrerFee = uint48(bound(referrerFee_, 0, 10e2));

        // Set the auction house's max referrer fee to 10%
        vm.prank(OWNER);
        auctionHouse.setFee(toKeycode("EMPA"), IFeeManager.FeeType.MaxReferrer, 10e2);

        // Call
        vm.prank(admin);
        banker.setReferrerFee(referrerFee);

        // Assert
        assertEq(banker.referrerFee(), referrerFee, "referrerFee");
    }
}
