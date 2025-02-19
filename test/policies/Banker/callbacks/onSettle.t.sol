// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import {BaseCallback} from "axis-core-1.0.1/bases/BaseCallback.sol";
import {ERC20} from "solmate-6.8.0/tokens/ERC20.sol";

import {BankerTest} from "../BankerTest.sol";

contract BankerCallbackOnSettleTest is BankerTest {
    event AuctionSucceeded(address debtToken, uint256 refund, address asset, uint256 proceeds);

    // ======= Tests ======= //

    // given the lot does not exist
    //  [X] it reverts
    // given the caller is not the auction house
    //  [X] it reverts
    // given the lot exists
    //  [X] it burns the refund
    //  [X] it sends the proceeds to the treasury
    //  [X] the AuctionSucceeded event is emitted

    function test_lotDoesNotExist_reverts() public givenPolicyIsActive {
        vm.expectRevert(abi.encodeWithSelector(BaseCallback.Callback_NotAuthorized.selector));

        // Call
        vm.prank(address(auctionHouse));
        banker.onSettle(0, 50e18, 10e18, "");
    }

    function test_callerIsNotAuctionHouse_reverts()
        public
        givenPolicyIsActive
        givenAuctionIsCreated
    {
        vm.expectRevert(abi.encodeWithSelector(BaseCallback.Callback_NotAuthorized.selector));

        // Call
        vm.prank(address(this));
        banker.onSettle(0, 50e18, 10e18, "");
    }

    function test_success() public givenPolicyIsActive givenAuctionIsCreated {
        uint256 proceedsAmount = 50e18;
        uint256 refundAmount = 10e18;

        // Provide quote tokens to the callback
        // This is expected to be provided by the auction house
        stablecoin.mint(address(banker), proceedsAmount);

        // Provide base tokens to the callback from the AuctionHouse
        // This is expected to be provided by the auction house
        vm.prank(address(auctionHouse));
        ERC20(debtToken).transfer(address(banker), refundAmount);

        // Expect event
        vm.expectEmit(address(banker));
        emit AuctionSucceeded(debtToken, refundAmount, address(stablecoin), proceedsAmount);

        // Call
        vm.prank(address(auctionHouse));
        banker.onSettle(0, proceedsAmount, refundAmount, "");

        // Assert
        // Debt Token Balances
        assertEq(ERC20(debtToken).balanceOf(address(banker)), 0, "banker: baseToken.balance == 0");
        assertEq(
            ERC20(debtToken).balanceOf(address(auctionHouse)),
            auctionCapacity - refundAmount,
            "auctionHouse: baseToken.balance == auctionCapacity - refundAmount"
        );

        // Stablecoin Balances
        assertEq(stablecoin.balanceOf(address(banker)), 0, "banker: quoteToken.balance == 0");
        assertEq(
            stablecoin.balanceOf(address(TRSRY)),
            proceedsAmount,
            "TRSRY: quoteToken.balance == 50e18"
        );
        assertEq(
            stablecoin.balanceOf(address(auctionHouse)), 0, "auctionHouse: quoteToken.balance == 0"
        );

        // Refund is burnt
        assertEq(
            ERC20(debtToken).totalSupply(),
            auctionCapacity - refundAmount,
            "debtToken: totalSupply == auctionCapacity - refundAmount"
        );
    }
}
