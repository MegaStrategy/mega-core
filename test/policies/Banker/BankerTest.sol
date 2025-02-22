// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import {Kernel, Actions} from "src/Kernel.sol";

import {Banker} from "src/policies/Banker.sol";
import {RolesAdmin} from "src/policies/RolesAdmin.sol";
import {MegaRoles} from "src/modules/ROLES/MegaRoles.sol";
import {MegaTreasury} from "src/modules/TRSRY/MegaTreasury.sol";
import {MegaToken} from "src/modules/TOKEN/MegaToken.sol";

import {Test} from "@forge-std/Test.sol";
import {MockERC20} from "@solmate-6.8.0/test/utils/mocks/MockERC20.sol";
import {WithSalts} from "../../lib/WithSalts.sol";
import {ERC20} from "@solmate-6.8.0/tokens/ERC20.sol";
import {BatchAuctionHouse} from "@axis-core-1.0.1/BatchAuctionHouse.sol";
import {IBatchAuctionHouse} from "@axis-core-1.0.1/interfaces/IBatchAuctionHouse.sol";
import {IEncryptedMarginalPrice} from
    "@axis-core-1.0.1/interfaces/modules/auctions/IEncryptedMarginalPrice.sol";
import {EncryptedMarginalPrice} from "@axis-core-1.0.1/modules/auctions/batch/EMP.sol";
import {toKeycode} from "@axis-core-1.0.1/modules/Keycode.sol";
import {Point, ECIES} from "@axis-core-1.0.1/lib/ECIES.sol";
import {EncryptedMarginalPriceBid} from "@axis-utils-1.0.0/lib/EncryptedMarginalPriceBid.sol";
import {IAuction} from "@axis-core-1.0.1/interfaces/modules/IAuction.sol";
import {ConvertibleDebtToken} from "src/lib/ConvertibleDebtToken.sol";

import {console2} from "@forge-std/console2.sol";

// solhint-disable max-states-count

abstract contract BankerTest is Test, WithSalts {
    // System contracts
    Kernel public kernel;
    MegaRoles public ROLES;
    MegaTreasury public TRSRY;
    MegaToken public mgst;
    Banker public banker;
    RolesAdmin public rolesAdmin;

    // Test ERC20 tokens
    MockERC20 public stablecoin;

    // External contracts (axis)
    address public constant OWNER = address(0x1111);
    address public constant PROTOCOL = address(0x2222);
    address public constant PERMIT2 = address(0x3333);

    BatchAuctionHouse public auctionHouse;
    EncryptedMarginalPrice public empa;

    // Permissioned addresses
    address public manager = address(0xAAAA);
    address public admin = address(0xBBBB);
    address public buyer = address(0x000000000000000000000000000000000000CcCc);
    address public emergency = address(0xCCCC);

    // System parameters
    uint48 public maxDiscount = 10e2;
    uint24 public minFillPercent = 50e2;
    uint48 public referrerFee = 0;
    uint256 public maxBids = 1000;

    uint48 public constant debtTokenMaturity = 1_000_000 + 100;
    uint256 public constant debtTokenConversionPrice = 5e18;
    address public debtTokenExpectedAddress;
    bytes32 public debtTokenSalt;

    Banker.DebtTokenParams public debtTokenParams;
    Banker.AuctionParams public auctionParams;

    uint256 public constant auctionPrivateKey = 112_233_445_566;

    uint256 public constant auctionCapacity = 100e18;
    uint48 public constant auctionStart = 1_000_000 + 1;
    uint48 public constant auctionDuration = 1 days;

    address public debtToken;

    function setUp() public {
        // Set block timestamp to be non-zero
        vm.warp(1_000_000);

        // Deploy axis contracts
        // We don't use permit2 here because it's not needed for the tests
        // Create a BatchAuctionHouse at a deterministic address, since it is used as input to callbacks
        BatchAuctionHouse _auctionHouse = new BatchAuctionHouse(OWNER, PROTOCOL, PERMIT2);
        auctionHouse = BatchAuctionHouse(address(0x00000000000000000000000000000000000000AA));
        vm.etch(address(auctionHouse), address(_auctionHouse).code);
        vm.store(address(auctionHouse), bytes32(uint256(0)), bytes32(abi.encode(OWNER))); // Owner
        vm.store(address(auctionHouse), bytes32(uint256(6)), bytes32(abi.encode(1))); // Reentrancy
        vm.store(address(auctionHouse), bytes32(uint256(7)), bytes32(abi.encode(PROTOCOL))); // Protocol

        // Install the EMP auction module
        empa = new EncryptedMarginalPrice(address(auctionHouse));
        vm.prank(OWNER);
        auctionHouse.installModule(empa);

        // Deploy system contracts

        // This contract will be the kernel executor since it is set to msg.sender on creation
        Kernel _kernel = new Kernel();
        kernel = Kernel(address(0xBB));
        vm.etch(address(kernel), address(_kernel).code);
        vm.store(address(kernel), bytes32(uint256(0)), bytes32(abi.encode(address(this))));

        // Modules
        ROLES = new MegaRoles(kernel);
        TRSRY = new MegaTreasury(kernel);
        mgst = new MegaToken(kernel, "MegaStrategy", "MGST");

        // Policies
        rolesAdmin = new RolesAdmin(kernel);

        // Deploy Banker at a deterministic address
        bytes memory args = abi.encode(kernel, address(auctionHouse));
        bytes32 salt = _getTestSalt("Banker", type(Banker).creationCode, args);
        vm.broadcast();
        Banker _banker = new Banker{salt: salt}(kernel, address(auctionHouse));
        banker = Banker(address(0xE700000000000000000000000000000000000000));
        vm.etch(address(banker), address(_banker).code);
        vm.store(address(banker), bytes32(uint256(0)), bytes32(abi.encode(address(kernel)))); // Kernel
        vm.store(address(banker), bytes32(uint256(1)), bytes32(abi.encode(address(auctionHouse)))); // AuctionHouse

        // Install the modules and policies in the Kernel
        kernel.executeAction(Actions.InstallModule, address(ROLES));
        kernel.executeAction(Actions.InstallModule, address(TRSRY));
        kernel.executeAction(Actions.InstallModule, address(mgst));
        kernel.executeAction(Actions.ActivatePolicy, address(rolesAdmin));
        kernel.executeAction(Actions.ActivatePolicy, address(banker));

        // Set permissioned roles
        rolesAdmin.grantRole("manager", manager);
        rolesAdmin.grantRole("admin", admin);
        rolesAdmin.grantRole("emergency", emergency);

        // Deploy test ERC20 tokens
        stablecoin = new MockERC20("Stablecoin", "STBL", 18);

        // Set debt token defaults
        debtTokenParams.underlying = address(stablecoin);
        debtTokenParams.expectedAddress = debtTokenExpectedAddress;
        debtTokenParams.maturity = debtTokenMaturity;
        debtTokenParams.conversionPrice = debtTokenConversionPrice;
        debtTokenParams.salt = debtTokenSalt;

        // Set auction defaults
        auctionParams.start = auctionStart;
        auctionParams.duration = auctionDuration;
        auctionParams.capacity = auctionCapacity;
        auctionParams.auctionPublicKey = ECIES.calcPubKey(Point(1, 2), auctionPrivateKey);
        auctionParams.infoHash = "ipfsHash";
    }

    // ======= Modifiers ======= //

    modifier givenPolicyIsActive() {
        vm.prank(admin);
        banker.initialize(maxDiscount, minFillPercent, referrerFee, maxBids);
        _;
    }

    modifier givenCuratorFeeIsSet(
        uint48 curatorFee_
    ) {
        auctionHouse.setCuratorFee(toKeycode("EMPA"), curatorFee_);
        _;
    }

    modifier givenDebtTokenAsset(
        address asset_
    ) {
        debtTokenParams.underlying = asset_;
        _;
    }

    modifier givenDebtTokenMaturity(
        uint48 maturity_
    ) {
        debtTokenParams.maturity = maturity_;
        _;
    }

    modifier givenDebtTokenConversionPrice(
        uint256 conversionPrice_
    ) {
        debtTokenParams.conversionPrice = conversionPrice_;
        _;
    }

    function _createDebtToken() internal {
        vm.prank(manager);
        debtToken = banker.createDebtToken(
            debtTokenParams.underlying,
            debtTokenParams.expectedAddress,
            debtTokenParams.conversionPrice,
            debtTokenParams.maturity,
            debtTokenParams.salt
        );
    }

    modifier givenUnderlyingAssetDecimals(
        uint8 decimals_
    ) {
        stablecoin = new MockERC20("Stablecoin", "STBL", decimals_);
        debtTokenParams.underlying = address(stablecoin);
        _;
    }

    modifier givenAuctionCapacity(
        uint256 capacity_
    ) {
        auctionParams.capacity = capacity_;
        _;
    }

    modifier givenDebtTokenCreated() {
        _createDebtToken();
        _;
    }

    function _issueDebtToken(address to_, uint256 amount_) internal {
        // Mint the underlying asset to the recipient
        stablecoin.mint(to_, amount_);

        // Approve spending of the underlying asset
        vm.startPrank(to_);
        stablecoin.approve(address(banker), amount_);
        vm.stopPrank();

        // Issue debt tokens
        vm.prank(manager);
        banker.issue(debtToken, to_, amount_);
    }

    modifier givenIssuedDebtTokens(address to_, uint256 amount_) {
        _issueDebtToken(to_, amount_);
        _;
    }

    function _fundTreasury(
        uint256 amount_
    ) internal {
        deal(debtTokenParams.underlying, address(TRSRY), amount_);
    }

    modifier givenTreasuryFunded(
        uint256 amount_
    ) {
        _fundTreasury(amount_);
        _;
    }

    modifier givenAuctionIsCreated() {
        vm.prank(manager);
        banker.auction(debtTokenParams, auctionParams);

        // Set the debt token based on the auction
        (, address baseToken,,,,,,,) = auctionHouse.lotRouting(0);
        debtToken = baseToken;
        _;
    }

    modifier givenAuctionHasBid(uint96 amountIn_, uint96 amountOut_) {
        // Fund the buyer
        stablecoin.mint(buyer, amountIn_);

        // Approve spending of the underlying asset
        vm.startPrank(buyer);
        stablecoin.approve(address(auctionHouse), amountIn_);
        vm.stopPrank();

        // Encrypt the bid
        IEncryptedMarginalPrice.BidParams memory empBidParams;
        {
            uint256 bidPrivateKey = 112_233_445_566_778;
            uint128 bidSeed = uint128(12_345_678_901_234_567_890_123_456_789_012_345_678);
            uint256 encryptedAmountOut = EncryptedMarginalPriceBid.encryptAmountOut(
                0,
                buyer,
                amountIn_,
                amountOut_,
                auctionParams.auctionPublicKey,
                bidSeed,
                bidPrivateKey
            );
            Point memory bidPubKey = ECIES.calcPubKey(Point(1, 2), bidPrivateKey);

            empBidParams = IEncryptedMarginalPrice.BidParams({
                encryptedAmountOut: encryptedAmountOut,
                bidPublicKey: bidPubKey
            });
        }

        // Prepare bid
        IBatchAuctionHouse.BidParams memory bidParams = IBatchAuctionHouse.BidParams({
            lotId: 0,
            bidder: buyer,
            referrer: address(0),
            amount: amountIn_,
            auctionData: abi.encode(empBidParams),
            permit2Data: bytes("")
        });

        // Bid
        vm.startPrank(buyer);
        auctionHouse.bid(bidParams, bytes(""));
        vm.stopPrank();
        _;
    }

    modifier givenAuctionHasStarted() {
        // Get the conclusion timestamp
        IAuction.Lot memory lot = empa.getLot(0);

        // Warp to the conclusion timestamp
        vm.warp(lot.start);
        _;
    }

    modifier givenAuctionHasConcluded() {
        // Get the conclusion timestamp
        IAuction.Lot memory lot = empa.getLot(0);

        // Warp to the conclusion timestamp
        vm.warp(lot.conclusion);
        _;
    }

    modifier givenAuctionHasSettled() {
        // Submit the private key (and decrypt the bids)
        bytes32[] memory sortHints = new bytes32[](1);
        sortHints[0] = bytes32(0x0000000000000000ffffffffffffffffffffffff000000000000000000000001);
        empa.submitPrivateKey(0, auctionPrivateKey, 1, sortHints);

        uint256 bidAmountOut = empa.decryptBid(0, 1);
        console2.log("bid amount out", bidAmountOut);

        // Settle the auction
        auctionHouse.settle(0, 1, bytes(""));
        _;
    }

    modifier givenBidIsClaimed(
        uint64 bidId_
    ) {
        uint64[] memory bidIds = new uint64[](1);
        bidIds[0] = bidId_;

        // Claim the bid
        vm.prank(buyer);
        auctionHouse.claimBids(0, bidIds);
        _;
    }

    modifier givenSalt(
        bytes32 salt_
    ) {
        debtTokenParams.salt = salt_;

        // Determine the expected address
        bytes32 bytecodeHash = keccak256(
            abi.encodePacked(
                type(ConvertibleDebtToken).creationCode,
                abi.encode(
                    "Convertible Stablecoin - Series 1",
                    "cvSTBL-1",
                    debtTokenParams.underlying,
                    address(mgst),
                    debtTokenParams.maturity,
                    debtTokenParams.conversionPrice,
                    address(banker)
                )
            )
        );
        address expectedAddress =
            _computeAddress(address(banker), debtTokenParams.salt, bytecodeHash);
        console2.log("Expected address:", expectedAddress);

        debtTokenParams.expectedAddress = expectedAddress;
        _;
    }

    // ======= ASSERTIONS ======= //

    function _assertBalances(
        uint256 debtTokenIssued,
        uint256 debtTokenConverted,
        uint256 debtTokenRedeemed,
        uint256 mgstBalance
    ) internal view {
        assertEq(
            ERC20(debtToken).balanceOf(buyer),
            debtTokenIssued - debtTokenConverted - debtTokenRedeemed,
            "debtToken balance after"
        );
        assertEq(
            ERC20(debtTokenParams.underlying).balanceOf(buyer),
            debtTokenRedeemed,
            "underlying balance after"
        );
        assertEq(
            ERC20(debtTokenParams.underlying).balanceOf(address(TRSRY)),
            debtTokenIssued - debtTokenRedeemed,
            "treasury balance after"
        );
        assertEq(mgst.balanceOf(buyer), mgstBalance, "mgst balance after");
    }

    function _assertApprovals(
        uint256 debtTokenIssued,
        uint256 debtTokenConverted,
        uint256 debtTokenRedeem,
        uint256 mgstApprovalBefore,
        uint256 mgstBalance
    ) internal view {
        assertEq(
            TRSRY.withdrawApproval(address(banker), ERC20(debtTokenParams.underlying)),
            debtTokenIssued - debtTokenConverted - debtTokenRedeem,
            "underlying withdraw approval after"
        );
        assertEq(
            mgst.mintApproval(address(banker)),
            mgstApprovalBefore - mgstBalance,
            "mgst mint approval after"
        );
    }
}
