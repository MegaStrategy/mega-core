// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import {TokenTest} from "./TokenTest.sol";
import {Module} from "src/Kernel.sol";

contract IncreaseMintApprovalTest is TokenTest {
    // when the caller is not permissioned
    //  [X] it reverts
    // when the amount causes the mint approval to exceed type(uint256).max
    //  [X] the value is set to type(uint256).max
    // when the module is not locally active
    //  [X] the mint approval is increased by the amount
    // when the recipient of the approval is not the caller
    //  [X] the mint approval for the recipient is increased by the amount
    // [X] the mint approval is increased by the amount
    // [X] the IncreaseMintApproval event is emitted

    function test_callerNotPermissioned_reverts()
        public
        givenModuleIsInstalled
        givenModuleIsActive
    {
        vm.expectRevert(abi.encodeWithSelector(Module.Module_PolicyNotPermitted.selector, USER));

        vm.prank(USER);
        mgst.increaseMintApproval(USER, 100);
    }

    function test_moduleNotActive() public givenModuleIsInstalled givenModuleIsInactive {
        // Call
        vm.prank(godmode);
        mgst.increaseMintApproval(godmode, 100);

        // Assert
        assertEq(mgst.mintApproval(godmode), 100, "mintApproval");
    }

    function test_newAmountExceedsMax(
        uint256 increaseAmount_
    )
        public
        givenModuleIsInstalled
        givenModuleIsActive
        increaseGodmodeMintApproval(type(uint256).max - 1)
    {
        uint256 increaseAmount = bound(increaseAmount_, 1, type(uint256).max);

        // Expect event
        vm.expectEmit();
        emit IncreaseMintApproval(godmode, type(uint256).max);

        // Call
        vm.prank(godmode);
        mgst.increaseMintApproval(godmode, increaseAmount);

        // Assert
        assertEq(mgst.mintApproval(godmode), type(uint256).max, "mintApproval");
    }

    function test_success(
        uint256 increaseAmount_
    ) public givenModuleIsInstalled givenModuleIsActive increaseGodmodeMintApproval(100) {
        uint256 increaseAmount = bound(increaseAmount_, 1, 10e18);

        // Expect event
        vm.expectEmit();
        emit IncreaseMintApproval(godmode, 100 + increaseAmount);

        // Call
        vm.prank(godmode);
        mgst.increaseMintApproval(godmode, increaseAmount);

        // Assert
        assertEq(mgst.mintApproval(godmode), 100 + increaseAmount, "mintApproval");
    }

    function test_recipientIsNotCaller() public givenModuleIsInstalled givenModuleIsActive {
        // Call
        vm.prank(godmode);
        mgst.increaseMintApproval(USER, 100);

        // Assert
        assertEq(mgst.mintApproval(USER), 100, "mintApproval");
        assertEq(mgst.mintApproval(godmode), 0, "mintApproval");
    }
}
