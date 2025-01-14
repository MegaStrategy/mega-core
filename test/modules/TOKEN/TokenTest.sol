// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Test} from "@forge-std/Test.sol";
import {Kernel, Actions} from "src/Kernel.sol";
import {MegaToken} from "src/modules/TOKEN/MegaToken.sol";
import {ModuleTestFixtureGenerator} from "test/lib/ModuleTestFixtureGenerator.sol";

contract TokenTest is Test {
    using ModuleTestFixtureGenerator for MegaToken;

    Kernel public kernel;
    MegaToken public mgst;
    address public constant OWNER = address(1);
    address public godmode;
    address public constant USER = address(2);

    event IncreaseMintApproval(address indexed policy_, uint256 newAmount_);
    event DecreaseMintApproval(address indexed policy_, uint256 newAmount_);
    event Mint(address indexed policy_, address indexed to_, uint256 amount_);
    event Burn(address indexed policy_, address indexed from_, uint256 amount_);

    function setUp() public {
        vm.prank(OWNER);
        kernel = new Kernel();
        mgst = new MegaToken(kernel, "MGST", "MGST");

        // Generate fixtures
        {
            godmode = mgst.generateGodmodeFixture(type(MegaToken).name);
            vm.prank(OWNER);
            kernel.executeAction(Actions.ActivatePolicy, godmode);
        }
    }

    modifier givenModuleIsInstalled() {
        vm.prank(OWNER);
        kernel.executeAction(Actions.InstallModule, address(mgst));
        _;
    }

    modifier givenModuleIsActive() {
        vm.prank(godmode);
        mgst.activate();
        _;
    }

    modifier givenModuleIsInactive() {
        vm.prank(godmode);
        mgst.deactivate();
        _;
    }

    modifier increaseGodmodeMintApproval(
        uint256 amount_
    ) {
        vm.prank(godmode);
        mgst.increaseMintApproval(godmode, amount_);
        _;
    }

    modifier mint(address to_, uint256 amount_) {
        // Mint
        vm.prank(godmode);
        mgst.mint(to_, amount_);
        _;
    }
}
