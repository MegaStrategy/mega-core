// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "src/Kernel.sol";

import "src/policies/Banker.sol";
import "src/policies/RolesAdmin.sol";
import "src/modules/ROLES/OlympusRoles.sol";
import "src/modules/TRSRY/OlympusTreasury.sol";
import "src/modules/TOKEN/MSTR.sol";

import {Test} from "@forge-std/Test.sol";
import {ERC20, MockERC20} from "solmate-6.8.0/test/utils/mocks/MockERC20.sol";

import {BatchAuctionHouse} from "axis-core-1.0.1/BatchAuctionHouse.sol";
import {EncryptedMarginalPrice} from "axis-core-1.0.1/modules/batch/EMP.sol";

abstract contract BankerTest is Test, WithSalts {
    
    // System contracts
    Kernel public kernel;
    OlympusRoles public ROLES;
    OlympusTreasury public TRSRY;
    MSTR public MSTR;
    Banker public banker;
    RolesAdmin public rolesAdmin;

    // Test ERC20 tokens
    MockERC20 public stablecoin;

    // External contracts (axis)
    address public constant OWNER = address(0x1);
    address public constant PROTOCOL = address(0x2);
    address public constant PERMIT2 = address(0x3);

    BatchAuctionHouse public auctionHouse;
    EncryptedMarginalPrice public empa;

    // Permissioned addresses
    address public manager = address(0x4);
    address public admin = address(0x5);

    address public buyer = address(0x6);

    // System parameters
    uint256 public maxDiscount = 10e2;
    uint256 public minFillPercent = 100e2;
    uint256 public referrerFee = 0;
    uint256 public maxBids = 1000;

    function setUp() public {
        // Set block timestamp to be non-zero
        vm.warp(1_000_000);

        // Fund the addresses that we'll use to call the contracts
        vm.mint(manager, 1e18);
        vm.mint(admin, 1e18);
        vm.mint(buyer, 1e18);

        // Deploy axis contracts
        // We don't use permit2 here because it's not needed for the tests
        // Create a BatchAuctionHouse at a deterministic address, since it is used as input to callbacks
        BatchAuctionHouse _auctionHouse = new BatchAuctionHouse(OWNER, PROTOCOL, PERMIT2);
        auctionHouse = BatchAuctionHouse(address(0x000000000000000000000000000000000000000A));
        vm.etch(address(auctionHouse), address(_auctionHouse).code);
        vm.store(address(auctionHouse), bytes32(uint256(0)), bytes32(abi.encode(OWNER))); // Owner
        vm.store(address(auctionHouse), bytes32(uint256(6)), bytes32(abi.encode(1))); // Reentrancy
        vm.store(address(auctionHouse), bytes32(uint256(7)), bytes32(abi.encode(PROTOCOL))); // Protocol

        empa = new EncryptedMarginalPrice(address(auctionHouse));

        // Deploy system contracts

        // This contract will be the kernel executor since it is set to msg.sender on creation
        kernel = new Kernel();

        // Modules
        ROLES = new OlympusRoles(kernel);
        TRSRY = new OlympusTreasury(kernel);
        MSTR = new MSTR(kernel, "Master Strategy", "MSTR");

        // Policies
        rolesAdmin = new RolesAdmin(kernel);
        bytes32 salt; // TODO need salt since the Banker policy is a callback
        banker = new Banker{salt: salt}(
            kernel,
            address(auctionHouse)
        );

        // Install the modules and policies in the Kernel
        kernel.executeAction(Actions.InstallModule, address(ROLES));
        kernel.executeAction(Actions.InstallModule, address(TRSRY));
        kernel.executeAction(Actions.InstallModule, address(MSTR));
        kernel.executeAction(Actions.InstallPolicy, address(rolesAdmin));
        kernel.executeAction(Actions.ActivatePolicy, address(banker));

        // Set permissioned roles
        rolesAdmin.grantRole("manager", manager);
        rolesAdmin.grantRole("admin", admin);

        // Deploy test ERC20 tokens
        stablecoin = new MockERC20("Stablecoin", "STBL", 18);
    }


}