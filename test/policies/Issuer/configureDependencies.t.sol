// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import {IssuerTest} from "./IssuerTest.sol";
import {MegaToken} from "src/modules/TOKEN/MegaToken.sol";
import {Kernel} from "src/Kernel.sol";
import {Actions} from "src/Kernel.sol";
import {IIssuer} from "src/policies/interfaces/IIssuer.sol";
import {OlympusTreasury} from "src/modules/TRSRY/OlympusTreasury.sol";

contract MockTokenModule is MegaToken {
    constructor(
        Kernel kernel_
    ) MegaToken(kernel_, "MGST", "MGST") {}
}

contract MockTreasuryModule is OlympusTreasury {
    constructor(
        Kernel kernel_
    ) OlympusTreasury(kernel_) {}
}

contract IssuerConfigureDependenciesTest is IssuerTest {
    // given token module is changed
    //  [X] it reverts
    // given another module is changed
    //  [X] it succeeds

    function test_tokenModuleChanged_reverts() public {
        // Create a new token module
        MockTokenModule newModule = new MockTokenModule(kernel);

        // Expect revert
        vm.expectRevert(abi.encodeWithSelector(IIssuer.InvalidState.selector));

        // Install the new module
        kernel.executeAction(Actions.UpgradeModule, address(newModule));
    }

    function test_treasuryModuleChanged() public {
        // Create a new TRSRY module
        MockTreasuryModule newModule = new MockTreasuryModule(kernel);

        // Upgrade the module
        kernel.executeAction(Actions.UpgradeModule, address(newModule));

        // Assert that the TOKEN module address is the same
        assertEq(
            issuer.getUnderlyingToken(), address(mgst), "TOKEN module address should be the same"
        );
    }
}
