// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import {Kernel, Actions} from "src/Kernel.sol";

import {Issuer} from "src/policies/Issuer.sol";
import {RolesAdmin} from "src/policies/RolesAdmin.sol";
import {MegaRoles} from "src/modules/ROLES/MegaRoles.sol";
import {MegaTreasury} from "src/modules/TRSRY/MegaTreasury.sol";
import {MegaToken} from "src/modules/TOKEN/MegaToken.sol";

import {Test} from "@forge-std/Test.sol";
import {MockERC20} from "@solmate-6.8.0/test/utils/mocks/MockERC20.sol";

import {FixedStrikeOptionTeller as oTeller} from "src/lib/oTokens/FixedStrikeOptionTeller.sol";
import {Authority} from "@solmate-6.8.0/auth/Auth.sol";

import {LinearVesting} from "@axis-core-1.0.1/modules/derivatives/LinearVesting.sol";

// solhint-disable max-states-count
abstract contract IssuerTest is Test {
    // Note: block.timestamp starts at 1

    // System contracts
    Kernel public kernel;
    MegaRoles public ROLES;
    MegaTreasury public TRSRY;
    MegaToken public mgst;
    Issuer public issuer;
    RolesAdmin public rolesAdmin;

    // Axis contracts
    LinearVesting public vestingModule;

    // External contracts (bond protocol options)
    oTeller public teller;

    // Test ERC20 tokens
    MockERC20 public quoteToken;

    // Permissioned addresses
    address public admin = address(0xAAAA);
    address public manager = address(0xBBBB);
    address public emergency = address(0xCCCC);

    function setUp() public {
        // Set the block timestamp to some time in 2024
        vm.warp(1_709_481_600);

        // Deploy the option teller
        teller = new oTeller(address(this), Authority(address(0)));

        // Deploy a mock erc20 to use as a quote token
        quoteToken = new MockERC20("Quote Token", "QT", 18);

        // Deploy system contracts
        kernel = new Kernel();

        // Set up the vesting module
        // We can pass anything to the constructor, even if it isn't correct
        vestingModule = new LinearVesting(address(kernel));

        // Modules
        ROLES = new MegaRoles(kernel);
        TRSRY = new MegaTreasury(kernel);
        mgst = new MegaToken(kernel, "MGST", "MGST");

        // Policies
        issuer = new Issuer(kernel, address(teller), address(vestingModule));
        rolesAdmin = new RolesAdmin(kernel);

        // Install the modules and policies in the kernel
        kernel.executeAction(Actions.InstallModule, address(ROLES));
        kernel.executeAction(Actions.InstallModule, address(TRSRY));
        kernel.executeAction(Actions.InstallModule, address(mgst));
        kernel.executeAction(Actions.ActivatePolicy, address(issuer));
        kernel.executeAction(Actions.ActivatePolicy, address(rolesAdmin));

        // Set permissioned roles
        rolesAdmin.grantRole(bytes32("admin"), admin);
        rolesAdmin.grantRole(bytes32("manager"), manager);
        rolesAdmin.grantRole(bytes32("emergency"), emergency);
    }

    modifier givenLocallyInactive() {
        vm.prank(emergency);
        issuer.shutdown();
        _;
    }
}
