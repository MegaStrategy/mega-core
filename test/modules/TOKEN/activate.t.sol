// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {TokenTest} from "./TokenTest.sol";
import {Module} from "src/Kernel.sol";

contract ActivateTest is TokenTest {
    // when the caller is not permissioned
    //  [X] it reverts
    // when the module is locally active
    //  [X] the module is set to active
    // [X] the module is set to active

    function test_callerNotPermissioned_reverts() public givenModuleIsInstalled {
        vm.expectRevert(abi.encodeWithSelector(Module.Module_PolicyNotPermitted.selector, USER));

        vm.prank(USER);
        mstr.activate();
    }

    function test_moduleAlreadyActive() public givenModuleIsInstalled givenModuleIsActive {
        // Assert
        assertEq(mstr.active(), true, "active");
    }

    function test_success() public givenModuleIsInstalled givenModuleIsInactive {
        // Call
        vm.prank(godmode);
        mstr.activate();

        // Assert
        assertEq(mstr.active(), true, "active");
    }
}
