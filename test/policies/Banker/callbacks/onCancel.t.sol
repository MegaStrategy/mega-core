// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {BaseCallback} from "axis-core-1.0.1/bases/BaseCallback.sol";
import {ERC20} from "solmate-6.8.0/tokens/ERC20.sol";

import {BankerTest} from "../BankerTest.sol";

contract BankerCallbackOnCancelTest is BankerTest {
    // ======= Tests ======= //

    // given the lot does not exist
    //  [X] it reverts
    // given the caller is not the auction house
    //  [X] it reverts
    // [X] it burns the refunded amount of debt tokens

    function test_lotDoesNotExist_reverts() public givenPolicyIsActive {
        vm.expectRevert(abi.encodeWithSelector(BaseCallback.Callback_NotAuthorized.selector));

        // Call
        vm.prank(address(auctionHouse));
        banker.onCancel(0, 0, true, "");
    }

    function test_callerIsNotAuctionHouse_reverts() public givenPolicyIsActive {
        vm.expectRevert(abi.encodeWithSelector(BaseCallback.Callback_NotAuthorized.selector));

        // Call
        vm.prank(address(this));
        banker.onCancel(0, 0, true, "");
    }

    function test_success() public givenPolicyIsActive givenAuctionIsCreated {
        // Provide base tokens to the callback from the AuctionHouse
        // This is expected to be provided by the auction house
        vm.prank(address(auctionHouse));
        ERC20(debtToken).transfer(address(banker), auctionCapacity);

        // Call
        vm.prank(address(auctionHouse));
        banker.onCancel(0, auctionCapacity, true, "");

        // Assert
        assertEq(ERC20(debtToken).balanceOf(address(banker)), 0, "banker: debtToken.balance == 0");
        assertEq(
            ERC20(debtToken).balanceOf(address(auctionHouse)),
            0,
            "auctionHouse: debtToken.balance == auctionCapacity"
        );
    }
}
