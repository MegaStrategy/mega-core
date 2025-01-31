// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import {TokenTest} from "./TokenTest.sol";
import {Module} from "src/Kernel.sol";

contract DecreaseMintApprovalTest is TokenTest {
    // when the caller is not permissioned
    //  [X] it reverts
    // when the amount would cause the mint approval to go below 0
    //  [X] the mint approval is set to 0
    // when the module is not locally active
    //  [X] the mint approval is decreased by the amount
    // when the recipient of the approval is not the caller
    //  [X] the mint approval for the recipient is decreased by the amount
    // [X] the mint approval is decreased by the amount
    // [X] the DecreaseMintApproval event is emitted

    function test_callerNotPermissioned_reverts()
        public
        givenModuleIsInstalled
        givenModuleIsActive
    {
        vm.expectRevert(abi.encodeWithSelector(Module.Module_PolicyNotPermitted.selector, USER));

        vm.prank(USER);
        mgst.decreaseMintApproval(USER, 100);
    }

    function test_newAmountLessThanZero(
        uint256 decreaseAmount_
    ) public givenModuleIsInstalled givenModuleIsActive increaseGodmodeMintApproval(1e18) {
        uint256 decreaseAmount = bound(decreaseAmount_, 1e18 + 1, 2e18);

        // Expect event
        vm.expectEmit();
        emit DecreaseMintApproval(godmode, 0);

        // Call
        vm.prank(godmode);
        mgst.decreaseMintApproval(godmode, decreaseAmount);

        // Assert
        assertEq(mgst.mintApproval(godmode), 0, "mintApproval");
    }

    function test_success(
        uint256 decreaseAmount_
    ) public givenModuleIsInstalled givenModuleIsActive increaseGodmodeMintApproval(1e18) {
        uint256 decreaseAmount = bound(decreaseAmount_, 1, 1e18);

        // Expect event
        vm.expectEmit();
        emit DecreaseMintApproval(godmode, 1e18 - decreaseAmount);

        // Call
        vm.prank(godmode);
        mgst.decreaseMintApproval(godmode, decreaseAmount);

        // Assert
        assertEq(mgst.mintApproval(godmode), 1e18 - decreaseAmount, "mintApproval");
    }

    function test_recipientIsNotCaller(
        uint256 decreaseAmount_
    ) public givenModuleIsInstalled givenModuleIsActive {
        uint256 decreaseAmount = bound(decreaseAmount_, 1, 1e18);

        // Increase mint approval
        vm.prank(godmode);
        mgst.increaseMintApproval(USER, 1e18);

        // Expect event
        vm.expectEmit();
        emit DecreaseMintApproval(USER, 1e18 - decreaseAmount);

        // Call
        vm.prank(godmode);
        mgst.decreaseMintApproval(USER, decreaseAmount);

        // Assert
        assertEq(mgst.mintApproval(USER), 1e18 - decreaseAmount, "mintApproval");
        assertEq(mgst.mintApproval(godmode), 0, "mintApproval");
    }
}
