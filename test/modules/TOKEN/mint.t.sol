// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import {TokenTest} from "./TokenTest.sol";
import {TOKENv1} from "src/modules/TOKEN/TOKEN.v1.sol";
import {Module} from "src/Kernel.sol";

contract MintTest is TokenTest {
    // when the module is not locally active
    //  [X] it reverts
    // when the caller is not permissioned
    //  [X] it reverts
    // when the amount is 0
    //  [X] it reverts
    // when the caller's mint approval is insufficient
    //  [X] it reverts
    // [X] the caller's mint approval is reduced by the amount
    // [X] the total supply is increased by the amount
    // [X] the amount is minted to the recipient
    // [X] the Mint event is emitted

    function test_moduleNotActive_reverts() public givenModuleIsInstalled givenModuleIsInactive {
        vm.expectRevert(abi.encodeWithSelector(TOKENv1.TOKEN_NotActive.selector));

        // Call
        vm.prank(godmode);
        mgst.mint(USER, 100);
    }

    function test_callerNotPermissioned_reverts() public givenModuleIsActive {
        vm.expectRevert(abi.encodeWithSelector(Module.Module_PolicyNotPermitted.selector, USER));

        // Call
        vm.prank(USER);
        mgst.mint(USER, 100);
    }

    function test_amountIsZero_reverts() public givenModuleIsActive {
        vm.expectRevert(abi.encodeWithSelector(TOKENv1.TOKEN_ZeroAmount.selector));

        // Call
        vm.prank(godmode);
        mgst.mint(USER, 0);
    }

    function test_callerMintApprovalIsInsufficient_reverts()
        public
        givenModuleIsActive
        increaseGodmodeMintApproval(1e18)
    {
        vm.expectRevert(abi.encodeWithSelector(TOKENv1.TOKEN_NotApproved.selector));

        // Call
        vm.prank(godmode);
        mgst.mint(USER, 1e18 + 1);
    }

    function test_success(
        uint256 mintAmount_
    ) public givenModuleIsActive increaseGodmodeMintApproval(1e18) {
        uint256 mintAmount = bound(mintAmount_, 1, 1e18);

        // Expect event
        vm.expectEmit();
        emit Mint(godmode, USER, mintAmount);

        // Call
        vm.prank(godmode);
        mgst.mint(USER, mintAmount);

        // Assert
        assertEq(mgst.balanceOf(USER), mintAmount, "balanceOf(USER)");
        assertEq(mgst.totalSupply(), mintAmount, "totalSupply");
        assertEq(mgst.mintApproval(godmode), 1e18 - mintAmount, "mintApproval(godmode)");
    }
}
