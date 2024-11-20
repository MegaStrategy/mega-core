// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {BaseCallback} from "axis-core-1.0.1/bases/BaseCallback.sol";
import {ERC20} from "solmate-6.8.0/tokens/ERC20.sol";

import {BankerTest} from "../BankerTest.sol";

contract BankerCallbackOnCurateTest is BankerTest {
    // ======= Tests ======= //

    // given the lot does not exist
    //  [X] it reverts
    // given the caller is not the auction house
    //  [X] it reverts
    // given the curator has a fee
    //  [X] it mints the required base tokens
    // given the curator has no fee
    //  [X] it does not mint any base tokens

    function test_lotDoesNotExist() public givenPolicyIsActive {
        vm.expectRevert(abi.encodeWithSelector(BaseCallback.Callback_NotAuthorized.selector));

        vm.prank(address(auctionHouse));
        banker.onCurate(0, 0, true, "");
    }

    function test_callerIsNotAuctionHouse() public givenPolicyIsActive givenAuctionIsCreated {
        vm.expectRevert(abi.encodeWithSelector(BaseCallback.Callback_NotAuthorized.selector));

        vm.prank(address(this));
        banker.onCurate(0, 0, true, "");
    }

    function test_curatorHasFee() public givenPolicyIsActive givenDebtTokenCreated givenAuctionIsCreated {
        vm.prank(address(auctionHouse));
        banker.onCurate(0, 100, true, "");

        // Assert
        assertEq(ERC20(debtToken).balanceOf(address(banker)), 0, "banker: debtToken.balance == 0");
        assertEq(
            ERC20(debtToken).balanceOf(address(auctionHouse)),
            100,
            "auctionHouse: debtToken.balance == 100"
        );
    }

    function test_curatorHasNoFee() public givenPolicyIsActive givenDebtTokenCreated givenAuctionIsCreated {
        vm.prank(address(auctionHouse));
        banker.onCurate(0, 0, false, "");

        // Assert
        assertEq(ERC20(debtToken).balanceOf(address(banker)), 0, "banker: debtToken.balance == 0");
        assertEq(
            ERC20(debtToken).balanceOf(address(auctionHouse)),
            0,
            "auctionHouse: debtToken.balance == 0"
        );
    }
}
