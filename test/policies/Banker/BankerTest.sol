// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Kernel, Actions} from "src/Kernel.sol";

import {Banker} from "src/policies/Banker.sol";
import {RolesAdmin} from "src/policies/RolesAdmin.sol";
import {OlympusRoles} from "src/modules/ROLES/OlympusRoles.sol";
import {OlympusTreasury} from "src/modules/TRSRY/OlympusTreasury.sol";
import {MSTR as MasterStrategy} from "src/modules/TOKEN/MSTR.sol";

import {Test} from "@forge-std/Test.sol";
import {ERC20} from "solmate-6.8.0/tokens/ERC20.sol";
import {MockERC20} from "solmate-6.8.0/test/utils/mocks/MockERC20.sol";
import {WithSalts} from "../../lib/WithSalts.sol";

import {BatchAuctionHouse} from "axis-core-1.0.1/BatchAuctionHouse.sol";
import {EncryptedMarginalPrice} from "axis-core-1.0.1/modules/auctions/batch/EMP.sol";
import {toKeycode} from "axis-core-1.0.1/modules/Keycode.sol";
import {Point, ECIES} from "axis-core-1.0.1/lib/ECIES.sol";

abstract contract BankerTest is Test, WithSalts {
    // System contracts
    Kernel public kernel;
    OlympusRoles public ROLES;
    OlympusTreasury public TRSRY;
    MasterStrategy public MSTR;
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
    uint48 public maxDiscount = 10e2;
    uint24 public minFillPercent = 100e2;
    uint48 public referrerFee = 0;
    uint256 public maxBids = 1000;

    uint48 public constant debtTokenMaturity = 1_000_000 + 100;
    uint256 public constant debtTokenConversionPrice = 5e18;

    Banker.DebtTokenParams public debtTokenParams;
    Banker.AuctionParams public auctionParams;

    uint256 public constant auctionPrivateKey = 1234e18;

    function setUp() public {
        // Set block timestamp to be non-zero
        vm.warp(1_000_000);

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
        Kernel _kernel = new Kernel();
        kernel = Kernel(address(0xB));
        vm.etch(address(kernel), address(_kernel).code);
        vm.store(address(kernel), bytes32(uint256(0)), bytes32(abi.encode(address(this))));

        // Modules
        ROLES = new OlympusRoles(kernel);
        TRSRY = new OlympusTreasury(kernel);
        MSTR = new MasterStrategy(kernel, "Master Strategy", "MSTR");

        // Policies
        rolesAdmin = new RolesAdmin(kernel);
        bytes memory args = abi.encode(kernel, address(auctionHouse));
        bytes32 salt = _getTestSalt(
            "Banker", type(Banker).creationCode, args
        );
        banker = new Banker{salt: salt}(kernel, address(auctionHouse));

        // Install the modules and policies in the Kernel
        kernel.executeAction(Actions.InstallModule, address(ROLES));
        kernel.executeAction(Actions.InstallModule, address(TRSRY));
        kernel.executeAction(Actions.InstallModule, address(MSTR));
        kernel.executeAction(Actions.ActivatePolicy, address(rolesAdmin));
        kernel.executeAction(Actions.ActivatePolicy, address(banker));

        // Set permissioned roles
        rolesAdmin.grantRole("manager", manager);
        rolesAdmin.grantRole("admin", admin);

        // Deploy test ERC20 tokens
        stablecoin = new MockERC20("Stablecoin", "STBL", 18);

        // Fund the addresses that we'll use to call the contracts
        deal(address(stablecoin), manager, 1e18);
        deal(address(stablecoin), admin, 1e18);
        deal(address(stablecoin), buyer, 1e18);

        // Set debt token defaults
        debtTokenParams.asset = address(stablecoin);
        debtTokenParams.maturity = debtTokenMaturity;
        debtTokenParams.conversionPrice = debtTokenConversionPrice;

        // Set auction defaults
        auctionParams.start = uint48(block.timestamp + 1);
        auctionParams.duration = 10;
        auctionParams.capacity = 1e18;
        auctionParams.auctionPublicKey = ECIES.calcPubKey(Point(0, 0), auctionPrivateKey);
        auctionParams.infoHash = "ipfsHash";
    }

    // ======= Modifiers ======= //

    modifier givenPolicyIsActive() {
        banker.initialize(maxDiscount, minFillPercent, referrerFee, maxBids);
        _;
    }

    modifier givenCuratorFeeIsSet(uint48 curatorFee_) {
        auctionHouse.setCuratorFee(toKeycode("EMPA"), curatorFee_);
        _;
    }

    modifier givenDebtTokenAsset(address asset_) {
        debtTokenParams.asset = asset_;
        _;
    }

    modifier givenDebtTokenMaturity(uint48 maturity_) {
        debtTokenParams.maturity = maturity_;
        _;
    }

    modifier givenDebtTokenConversionPrice(uint256 conversionPrice_) {
        debtTokenParams.conversionPrice = conversionPrice_;
        _;
    }
}
