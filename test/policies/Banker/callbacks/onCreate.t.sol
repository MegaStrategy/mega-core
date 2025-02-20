// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import {IBanker} from "src/policies/interfaces/IBanker.sol";
import {BaseCallback} from "@axis-core-1.0.1/bases/BaseCallback.sol";
import {ConvertibleDebtToken} from "src/lib/ConvertibleDebtToken.sol";
import {ERC20} from "@solmate-6.8.0/tokens/ERC20.sol";

import {BankerTest} from "../BankerTest.sol";

contract BankerCallbackOnCreateTest is BankerTest {
    // ======= Tests ======= //

    // given the seller is not the Banker
    //  [X] it reverts
    // given prefund is false
    //  [X] it reverts
    // given the callback has already been called
    //  [X] it reverts
    // given the amount is zero
    //  [X] it reverts
    // given the debt token is not created by this issuer
    //  [X] it reverts
    // given the debt token has not matured
    //  [X] it reverts
    // [X] it issues the convertible debt token to the auction house

    function test_sellerIsNotBanker_reverts() public givenPolicyIsActive givenDebtTokenCreated {
        vm.expectRevert(abi.encodeWithSelector(IBanker.OnlyLocal.selector));

        // Call
        vm.prank(address(auctionHouse));
        banker.onCreate(0, address(this), debtToken, address(0), auctionCapacity, true, "");
    }

    function test_prefundIsFalse_reverts() public givenPolicyIsActive givenDebtTokenCreated {
        vm.expectRevert(abi.encodeWithSelector(IBanker.InvalidParam.selector, "prefund"));

        vm.prank(address(auctionHouse));
        banker.onCreate(0, address(banker), debtToken, address(0), auctionCapacity, false, "");
    }

    function test_callbackAlreadyCalled_reverts()
        public
        givenPolicyIsActive
        givenAuctionIsCreated
    {
        vm.expectRevert(abi.encodeWithSelector(BaseCallback.Callback_InvalidParams.selector));

        vm.prank(address(auctionHouse));
        banker.onCreate(0, address(banker), debtToken, address(0), auctionCapacity, true, "");
    }

    function test_amountIsZero_reverts() public givenPolicyIsActive givenDebtTokenCreated {
        vm.expectRevert(abi.encodeWithSelector(IBanker.InvalidParam.selector, "amount"));

        vm.prank(address(auctionHouse));
        banker.onCreate(0, address(banker), debtToken, address(0), 0, true, "");
    }

    function test_debtTokenIsNotCreatedByIssuer_reverts() public givenPolicyIsActive {
        // Create another token
        ConvertibleDebtToken anotherDebtToken = new ConvertibleDebtToken(
            "Another Debt Token",
            "ADT",
            address(stablecoin),
            address(mgst),
            debtTokenMaturity,
            debtTokenConversionPrice,
            OWNER
        );

        vm.expectRevert(abi.encodeWithSelector(IBanker.InvalidDebtToken.selector));

        vm.prank(address(auctionHouse));
        banker.onCreate(
            0, address(banker), address(anotherDebtToken), address(0), auctionCapacity, true, ""
        );
    }

    function test_debtTokenHasMatured_reverts(
        uint48 maturityElapsed_
    ) public givenPolicyIsActive givenDebtTokenCreated {
        uint48 maturityElapsed = uint48(bound(maturityElapsed_, 0, 1 weeks));
        vm.warp(debtTokenMaturity + maturityElapsed);

        vm.expectRevert(abi.encodeWithSelector(IBanker.DebtTokenMatured.selector));

        vm.prank(address(auctionHouse));
        banker.onCreate(0, address(banker), debtToken, address(0), auctionCapacity, true, "");
    }

    function test_success() public givenPolicyIsActive givenDebtTokenCreated {
        // Call
        vm.prank(address(auctionHouse));
        banker.onCreate(0, address(banker), debtToken, address(0), auctionCapacity, true, "");

        // Assert
        assertEq(ERC20(debtToken).balanceOf(address(banker)), 0, "banker: debtToken.balance == 0");
        assertEq(
            ERC20(debtToken).balanceOf(address(auctionHouse)),
            auctionCapacity,
            "auctionHouse: debtToken.balance == auctionCapacity"
        );
    }
}
