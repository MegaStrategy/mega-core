// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import {BankerTest} from "../BankerTest.sol";
import {MegaToken} from "src/modules/TOKEN/MegaToken.sol";
import {Kernel, Keycode, Module, toKeycode} from "src/Kernel.sol";
import {Actions} from "src/Kernel.sol";
import {IBanker} from "src/policies/interfaces/IBanker.sol";
import {MegaTreasury} from "src/modules/TRSRY/MegaTreasury.sol";

contract MockTokenModule is MegaToken {
    constructor(
        Kernel kernel_
    ) MegaToken(kernel_, "MGST", "MGST") {}
}

contract MockTreasuryModule is MegaTreasury {
    constructor(
        Kernel kernel_
    ) MegaTreasury(kernel_) {}
}

contract MockModule is Module {
    constructor(
        Kernel kernel_
    ) Module(kernel_) {}

    function KEYCODE() public pure override returns (Keycode) {
        return toKeycode("MOCKM");
    }

    function VERSION() public pure override returns (uint8 major, uint8 minor) {
        major = 1;
        minor = 0;
    }
}

contract BankerConfigureDependenciesTest is BankerTest {
    // given TOKEN module is changed
    //  [X] it reverts
    // given TRSRY module is changed
    //  [X] it succeeds
    // [X] it succeeds

    function test_tokenModuleChanged_reverts() public givenPolicyIsActive {
        // Create a new token module
        MockTokenModule newModule = new MockTokenModule(kernel);

        // Expect revert
        vm.expectRevert(abi.encodeWithSelector(IBanker.InvalidState.selector));

        // Install the new module
        kernel.executeAction(Actions.UpgradeModule, address(newModule));
    }

    function test_treasuryModuleChanged_reverts() public givenPolicyIsActive {
        // Create a new TRSRY module
        MockTreasuryModule newModule = new MockTreasuryModule(kernel);

        // Upgrade the module
        kernel.executeAction(Actions.UpgradeModule, address(newModule));

        // No revert
        assertEq(
            banker.getConvertedToken(), address(mgst), "TOKEN module address should be the same"
        );
    }

    function test_otherModuleChanged() public givenPolicyIsActive {
        // Create a new mock module
        MockModule newModule = new MockModule(kernel);

        // Install the module
        kernel.executeAction(Actions.InstallModule, address(newModule));

        // No revert
        assertEq(
            banker.getConvertedToken(), address(mgst), "TOKEN module address should be the same"
        );
    }
}
