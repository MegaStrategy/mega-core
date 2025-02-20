// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import {TokenTest} from "./TokenTest.sol";
import {Module} from "src/Kernel.sol";

contract DeactivateTest is TokenTest {
    // when the caller is not permissioned
    //  [X] it reverts
    // when the module is not locally active
    //  [X] the module is set to not active
    // [X] the module is set to not active

    function test_callerNotPermissioned_reverts()
        public
        givenModuleIsInstalled
        givenModuleIsActive
    {
        vm.expectRevert(abi.encodeWithSelector(Module.Module_PolicyNotPermitted.selector, USER));

        vm.prank(USER);
        mgst.deactivate();
    }

    function test_moduleAlreadyInactive() public givenModuleIsInstalled givenModuleIsInactive {
        // Call
        vm.prank(godmode);
        mgst.deactivate();

        // Assert
        assertEq(mgst.active(), false, "active");
    }

    function test_success() public givenModuleIsInstalled givenModuleIsActive {
        // Call
        vm.prank(godmode);
        mgst.deactivate();

        // Assert
        assertEq(mgst.active(), false, "active");
    }
}
