// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import {Test} from "@forge-std/Test.sol";

import {stdError} from "@forge-std/StdError.sol";

import {ERC20} from "@solmate-6.8.0/tokens/ERC20.sol";
import {MockERC20} from "@solmate-6.8.0/test/utils/mocks/MockERC20.sol";
import {WithSalts} from "../../lib/WithSalts.sol";

import {
    IMorpho,
    Id as MorphoId,
    MarketParams as MorphoMarketParams,
    Position as MorphoPosition
} from "@morpho-blue-1.0.0/interfaces/IMorpho.sol";
import {MarketParamsLib} from "@morpho-blue-1.0.0/libraries/MarketParamsLib.sol";

import {IUniswapV3Factory} from "test/lib/IUniswapV3Factory.sol";
import {IUniswapV3NonfungiblePositionManager} from
    "test/lib/IUniswapV3NonfungiblePositionManager.sol";
import {IUniswapV3Pool} from "test/lib/IUniswapV3Pool.sol";
import {SqrtPriceMath} from "test/lib/SqrtPriceMath.sol";

import {SafeTransferLib} from "@solmate-6.8.0/utils/SafeTransferLib.sol";

import {Kernel, Actions} from "src/Kernel.sol";
import {MegaToken} from "src/modules/TOKEN/MegaToken.sol";
import {OlympusRoles} from "src/modules/ROLES/OlympusRoles.sol";
import {OlympusTreasury} from "src/modules/TRSRY/OlympusTreasury.sol";
import {Banker} from "src/policies/Banker.sol";
import {Hedger} from "src/periphery/Hedger.sol";
import {Issuer} from "src/policies/Issuer.sol";
import {RolesAdmin} from "src/policies/RolesAdmin.sol";
import {SharesMathLib} from "@morpho-blue-1.0.0/libraries/SharesMathLib.sol";

contract HedgerTest is Test, WithSalts {
    using SafeTransferLib for ERC20;

    Kernel public kernel;
    MegaToken public mgst;
    OlympusRoles public roles;
    OlympusTreasury public treasury;
    Banker public banker;
    Issuer public issuer;
    RolesAdmin public rolesAdmin;

    address public debtToken;

    MockERC20 public weth;
    MockERC20 public reserve;
    Hedger public hedger;
    IMorpho public morpho;
    MorphoId public mgstMarket;
    MorphoId public debtTokenMarket;

    address public constant KERNEL = address(0xBB);
    address public constant MORPHO = address(0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb);
    address public constant AUCTION_HOUSE = address(0xBA0000c59d144f2a9aEa064dcb2f963e1a0B3212);
    address public constant SWAP_ROUTER = address(0x2626664c2603336E57B271c5C0b26F421741e481);
    address public constant SWAP_QUOTER = address(0x3d4e44Eb1374240CE5F1B871ab261CD16335B76a);
    address public constant UNISWAP_V3_FACTORY = address(0x33128a8fC17869897dcE68Ed026d694621f6FDfD);
    address public constant UNISWAP_V3_POSITION_MANAGER =
        address(0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1);

    address public constant OWNER = address(0xAAAA);
    address public constant USER = address(0xBBBB);
    address public constant MANAGER = address(0xCCCC);
    address public constant ADMIN = address(0xDDDD);
    address public constant OPERATOR = address(0xEEEE);

    uint24 public constant RESERVE_WETH_SWAP_FEE = 500;
    uint24 public constant MGST_WETH_SWAP_FEE = 3000;

    uint256 public constant WETH_RESERVE_WETH_AMOUNT = 1000e18;
    uint256 public constant WETH_RESERVE_RESERVE_AMOUNT = 3_600_000e6;
    uint256 public constant MGST_WETH_MGST_AMOUNT = 1000e18;
    uint256 public constant MGST_WETH_WETH_AMOUNT = 100e18;

    uint256 public constant LLTV = 945e15; // 94.5%

    uint256 public constant DEBT_TOKEN_AMOUNT = 20e18;
    uint256 public constant DEBT_TOKEN_CONVERSION_PRICE = 2e18;

    function setUp() public {
        // Use a Base fork
        vm.createSelectFork(vm.envString("FORK_RPC_URL"), 24_698_617);

        Kernel _kernel = new Kernel();
        kernel = Kernel(KERNEL);
        vm.etch(KERNEL, address(_kernel).code);
        vm.store(KERNEL, bytes32(uint256(0)), bytes32(abi.encode(OWNER)));

        vm.startPrank(OWNER);
        mgst = new MegaToken(kernel, "MGST", "MGST");
        roles = new OlympusRoles(kernel);
        treasury = new OlympusTreasury(kernel);
        issuer = new Issuer(kernel, address(0), address(0)); // No oToken teller needed
        rolesAdmin = new RolesAdmin(kernel);
        vm.stopPrank();

        // Deploy Banker with salt
        bytes memory args = abi.encode(kernel, AUCTION_HOUSE);
        bytes32 salt = _getTestSalt("Banker", type(Banker).creationCode, args);
        vm.broadcast();
        banker = new Banker{salt: salt}(kernel, AUCTION_HOUSE);

        weth = new MockERC20("WETH", "WETH", 18);
        reserve = new MockERC20("RESERVE", "RESERVE", 6);

        // Install modules and policies
        vm.startPrank(OWNER);
        kernel.executeAction(Actions.InstallModule, address(roles));
        kernel.executeAction(Actions.InstallModule, address(mgst));
        kernel.executeAction(Actions.InstallModule, address(treasury));
        kernel.executeAction(Actions.ActivatePolicy, address(rolesAdmin));
        kernel.executeAction(Actions.ActivatePolicy, address(banker));
        kernel.executeAction(Actions.ActivatePolicy, address(issuer));
        vm.stopPrank();

        // Assign roles
        vm.startPrank(OWNER);
        rolesAdmin.grantRole("manager", MANAGER);
        rolesAdmin.grantRole("admin", ADMIN);
        vm.stopPrank();

        // Activate policies
        vm.startPrank(ADMIN);
        banker.initialize(0, 0, 0, 1e18);
        vm.stopPrank();

        // Create a Uniswap V3 pool for WETH/RESERVE
        vm.startPrank(OWNER);
        address wethReservePool = IUniswapV3Factory(UNISWAP_V3_FACTORY).createPool(
            address(weth), address(reserve), RESERVE_WETH_SWAP_FEE
        );

        // Initialize WETH/RESERVE
        uint160 wethReserveSqrtPriceX96 = SqrtPriceMath.getSqrtPriceX96(
            address(weth), address(reserve), WETH_RESERVE_WETH_AMOUNT, WETH_RESERVE_RESERVE_AMOUNT
        );
        IUniswapV3Pool(wethReservePool).initialize(wethReserveSqrtPriceX96);
        vm.stopPrank();

        // Create a Uniswap V3 pool for MGST/WETH
        vm.startPrank(OWNER);
        address mgstWethPool = IUniswapV3Factory(UNISWAP_V3_FACTORY).createPool(
            address(mgst), address(weth), MGST_WETH_SWAP_FEE
        );

        // Initialize MGST/WETH
        uint160 mgstWethSqrtPriceX96 = SqrtPriceMath.getSqrtPriceX96(
            address(mgst), address(weth), MGST_WETH_MGST_AMOUNT, MGST_WETH_WETH_AMOUNT
        );
        IUniswapV3Pool(mgstWethPool).initialize(mgstWethSqrtPriceX96);
        vm.stopPrank();

        // Mint tokens for WETH/RESERVE
        weth.mint(OWNER, WETH_RESERVE_WETH_AMOUNT);
        reserve.mint(OWNER, WETH_RESERVE_RESERVE_AMOUNT);
        vm.startPrank(OWNER);
        ERC20(address(weth)).safeApprove(UNISWAP_V3_POSITION_MANAGER, WETH_RESERVE_WETH_AMOUNT);
        ERC20(address(reserve)).safeApprove(
            UNISWAP_V3_POSITION_MANAGER, WETH_RESERVE_RESERVE_AMOUNT
        );
        vm.stopPrank();

        // Deploy liquidity into the WETH/RESERVE pool
        _mint(
            address(weth),
            address(reserve),
            WETH_RESERVE_WETH_AMOUNT,
            WETH_RESERVE_RESERVE_AMOUNT,
            RESERVE_WETH_SWAP_FEE
        );

        // Mint tokens for MGST/WETH
        vm.startPrank(ADMIN);
        issuer.mint(OWNER, MGST_WETH_MGST_AMOUNT);
        weth.mint(OWNER, MGST_WETH_WETH_AMOUNT);
        vm.stopPrank();

        vm.startPrank(OWNER);
        ERC20(address(mgst)).safeApprove(UNISWAP_V3_POSITION_MANAGER, MGST_WETH_MGST_AMOUNT);
        ERC20(address(weth)).safeApprove(UNISWAP_V3_POSITION_MANAGER, MGST_WETH_WETH_AMOUNT);
        vm.stopPrank();

        // Deploy liquidity into the MGST/WETH pool
        _mint(
            address(mgst),
            address(weth),
            MGST_WETH_MGST_AMOUNT,
            MGST_WETH_WETH_AMOUNT,
            MGST_WETH_SWAP_FEE
        );

        // Create a morpho market for MGST<>RESERVE
        MorphoMarketParams memory mgstMarketParams = MorphoMarketParams({
            loanToken: address(reserve),
            collateralToken: address(mgst),
            oracle: address(0), // TODO add oracle for MGST
            irm: address(0), // Disabled
            lltv: LLTV
        });
        mgstMarket = MarketParamsLib.id(mgstMarketParams);

        morpho = IMorpho(MORPHO);
        morpho.createMarket(mgstMarketParams);

        // Create a hedger
        vm.startPrank(OWNER);
        hedger = new Hedger(
            address(mgst),
            address(weth),
            address(reserve),
            MorphoId.unwrap(mgstMarket),
            MORPHO,
            SWAP_ROUTER,
            SWAP_QUOTER,
            RESERVE_WETH_SWAP_FEE,
            MGST_WETH_SWAP_FEE
        );
        vm.stopPrank();

        // Create the debt token
        vm.prank(MANAGER);
        debtToken = banker.createDebtToken(
            address(reserve), uint48(block.timestamp + 30 days), DEBT_TOKEN_CONVERSION_PRICE
        );
    }

    // ========== HELPERS ========== //

    function _mint(
        address tokenA_,
        address tokenB_,
        uint256 amountA_,
        uint256 amountB_,
        uint24 fee_
    ) internal {
        // Get correct orientation of tokens
        address token0 = tokenA_ < tokenB_ ? tokenA_ : tokenB_;
        address token1 = tokenA_ < tokenB_ ? tokenB_ : tokenA_;
        uint256 amount0 = tokenA_ < tokenB_ ? amountA_ : amountB_;
        uint256 amount1 = tokenA_ < tokenB_ ? amountB_ : amountA_;

        int24 tickSpacing = IUniswapV3Factory(UNISWAP_V3_FACTORY).feeAmountTickSpacing(fee_);

        // Determine the tick lower and upper
        int24 tickLower = (-887_272 / tickSpacing) * tickSpacing;
        int24 tickUpper = (887_272 / tickSpacing) * tickSpacing;

        vm.startPrank(OWNER);
        IUniswapV3NonfungiblePositionManager(UNISWAP_V3_POSITION_MANAGER).mint(
            IUniswapV3NonfungiblePositionManager.MintParams({
                token0: token0,
                token1: token1,
                fee: fee_,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: amount0,
                amount1Desired: amount1,
                amount0Min: 0,
                amount1Min: 0,
                recipient: OWNER,
                deadline: block.timestamp
            })
        );
        vm.stopPrank();
    }

    // ========== MODIFIERS ========== //

    function _getMorphoMarketId(
        address loanToken_,
        address collateralToken_,
        address oracle_
    ) internal pure returns (MorphoMarketParams memory marketParams, MorphoId marketId) {
        marketParams = MorphoMarketParams({
            loanToken: loanToken_,
            collateralToken: collateralToken_,
            oracle: oracle_,
            irm: address(0), // Disabled
            lltv: LLTV
        });
        marketId = MarketParamsLib.id(marketParams);

        return (marketParams, marketId);
    }

    function _createMorphoMarket(
        address loanToken_,
        address collateralToken_,
        address oracle_
    ) internal returns (MorphoId) {
        (MorphoMarketParams memory marketParams, MorphoId marketId) =
            _getMorphoMarketId(loanToken_, collateralToken_, oracle_);

        morpho.createMarket(marketParams);
        return marketId;
    }

    modifier givenDebtTokenMorphoMarketIsCreated() {
        debtTokenMarket = _createMorphoMarket(address(mgst), debtToken, debtToken);
        _;
    }

    modifier givenDebtTokenMorphoMarketHasSupply(
        uint256 amount_
    ) {
        // Mint MGST
        vm.startPrank(ADMIN);
        issuer.mint(OWNER, amount_);
        vm.stopPrank();

        // Approve the morpho market to transfer the MGST
        vm.startPrank(OWNER);
        ERC20(address(mgst)).safeApprove(MORPHO, amount_);
        vm.stopPrank();

        // Deposit MGST into the morpho market
        vm.startPrank(OWNER);
        morpho.supply(morpho.idToMarketParams(debtTokenMarket), amount_, 0, OWNER, "");
        vm.stopPrank();
        _;
    }

    modifier givenDebtTokenIsIssued(
        uint256 amount_
    ) {
        // Mint the underlying asset to the user
        reserve.mint(USER, amount_);

        // Approve the banker to spend the underlying asset
        vm.startPrank(USER);
        ERC20(address(reserve)).safeApprove(address(banker), amount_);
        vm.stopPrank();

        vm.prank(MANAGER);
        banker.issue(debtToken, USER, amount_);
        _;
    }

    modifier givenOperatorDebtTokenIsIssued(
        uint256 amount_
    ) {
        // Mint the underlying asset to the operator
        reserve.mint(OPERATOR, amount_);

        // Approve the banker to spend the underlying asset
        vm.startPrank(OPERATOR);
        ERC20(address(reserve)).safeApprove(address(banker), amount_);
        vm.stopPrank();

        vm.prank(MANAGER);
        banker.issue(debtToken, OPERATOR, amount_);
        _;
    }

    modifier givenDebtTokenIsWhitelisted() {
        vm.prank(OWNER);
        hedger.addCvToken(debtToken, MorphoId.unwrap(debtTokenMarket));
        _;
    }

    function _mintReserve(
        uint256 amount_
    ) internal {
        reserve.mint(USER, amount_);
    }

    modifier givenUserHasReserve(
        uint256 amount_
    ) {
        reserve.mint(USER, amount_);
        _;
    }

    modifier givenOperatorHasReserve(
        uint256 amount_
    ) {
        reserve.mint(OPERATOR, amount_);
        _;
    }

    function _approveReserveSpendingByHedger(
        uint256 amount_
    ) internal {
        vm.prank(USER);
        reserve.approve(address(hedger), amount_);
    }

    modifier givenReserveSpendingIsApproved(
        uint256 amount_
    ) {
        _approveReserveSpendingByHedger(amount_);
        _;
    }

    modifier givenOperatorReserveSpendingIsApproved(
        uint256 amount_
    ) {
        vm.prank(OPERATOR);
        reserve.approve(address(hedger), amount_);
        _;
    }

    modifier givenDebtTokenSpendingIsApproved(
        uint256 amount_
    ) {
        vm.prank(USER);
        ERC20(debtToken).safeApprove(address(hedger), amount_);
        _;
    }

    modifier givenOperatorDebtTokenSpendingIsApproved(
        uint256 amount_
    ) {
        vm.prank(OPERATOR);
        ERC20(debtToken).safeApprove(address(hedger), amount_);
        _;
    }

    modifier givenUserHasApprovedOperator() {
        vm.prank(USER);
        hedger.setOperatorStatus(OPERATOR, true);
        _;
    }

    modifier givenUserHasDepositedDebtToken(
        uint256 amount_
    ) {
        vm.prank(USER);
        hedger.deposit(debtToken, amount_);
        _;
    }

    modifier givenUserHasAuthorizedHedger() {
        vm.prank(USER);
        morpho.setAuthorization(address(hedger), true);
        _;
    }

    modifier givenUserHasUnauthorizedHedger() {
        vm.prank(USER);
        morpho.setAuthorization(address(hedger), false);
        _;
    }

    function _getMaximumHedgeAmount(
        uint256 collateralAmount_
    ) internal pure returns (uint256) {
        // Maximum hedge amount is what can be borrowed against the collateral
        // = (collateral * collateralPrice / 1e36) * lltv / 1e18

        uint256 collateralPrice = 1e36 * 1e18 / DEBT_TOKEN_CONVERSION_PRICE;

        return (collateralAmount_ * collateralPrice / 1e36) * LLTV / 1e18;
    }

    function _getReserveOut(
        uint256 mgstAmount_
    ) internal pure returns (uint256) {
        // 1 WETH : 10 MGST
        uint256 wethAmount = mgstAmount_ * 1e17 / 1e18;

        // 1 WETH : 3600 RESERVE
        uint256 reserveAmount = wethAmount * 3600 * 1e6 / 1e18;

        return reserveAmount;
    }

    function _getMgstOut(
        uint256 reserveAmount_
    ) internal pure returns (uint256) {
        // 1 WETH : 3600 RESERVE
        uint256 wethAmount = reserveAmount_ * 1e18 / (3600 * 1e6);

        // 1 WETH : 10 MGST
        uint256 mgstAmount = wethAmount * 1e18 / 1e17;

        return mgstAmount;
    }

    modifier givenUserHasIncreasedMgstHedge(
        uint256 amount_
    ) {
        vm.prank(USER);
        hedger.increaseHedge(address(debtToken), amount_, _getReserveOut(amount_) * 95 / 100);
        _;
    }

    function _approveMorphoReserveDeposit(
        uint256 amount_
    ) internal {
        vm.prank(USER);
        reserve.approve(address(morpho), amount_);
    }

    modifier givenUserHasApprovedMorphoReserveDeposit(
        uint256 amount_
    ) {
        _approveMorphoReserveDeposit(amount_);
        _;
    }

    function _depositReservesToMorphoMarket(
        uint256 amount_
    ) internal {
        vm.startPrank(USER);
        morpho.supply(morpho.idToMarketParams(mgstMarket), amount_, 0, USER, "");
        vm.stopPrank();
    }

    modifier givenUserHasDepositedReserves(
        uint256 amount_
    ) {
        _depositReservesToMorphoMarket(amount_);
        _;
    }

    // ========== ASSERTIONS ========== //

    function _expectInvalidDebtToken() internal {
        vm.expectRevert(abi.encodeWithSelector(Hedger.InvalidParam.selector, "cvToken"));
    }

    function _expectInvalidParam(
        string memory reason_
    ) internal {
        vm.expectRevert(abi.encodeWithSelector(Hedger.InvalidParam.selector, reason_));
    }

    function _expectInvalidOperator() internal {
        vm.expectRevert(abi.encodeWithSelector(Hedger.NotAuthorized.selector));
    }

    function _expectNotOwner() internal {
        vm.expectRevert("Ownable: caller is not the owner");
    }

    function _expectUnauthorized() internal {
        vm.expectRevert("unauthorized");
    }

    function _expectArithmeticError() internal {
        vm.expectRevert(stdError.arithmeticError);
    }

    function _expectSafeTransferFailure() internal {
        vm.expectRevert(bytes("STF"));
    }

    function _assertUserBalances(
        uint256 reserveBalance_,
        uint256 debtTokenBalance_
    ) internal view {
        assertEq(reserve.balanceOf(USER), reserveBalance_, "user: reserve balance");
        assertEq(ERC20(debtToken).balanceOf(USER), debtTokenBalance_, "user: debt token balance");
    }

    function _assertUserReserveBalanceLt(
        uint256 reserveBalance_
    ) internal view {
        assertLt(reserve.balanceOf(USER), reserveBalance_, "user: reserve balance");
    }

    function _assertUserDebtTokenBalance(
        uint256 debtTokenBalance_
    ) internal view {
        assertEq(ERC20(debtToken).balanceOf(USER), debtTokenBalance_, "user: debt token balance");
    }

    function _assertOperatorBalances(
        uint256 reserveBalance_,
        uint256 debtTokenBalance_
    ) internal view {
        assertEq(reserve.balanceOf(OPERATOR), reserveBalance_, "operator: reserve balance");
        assertEq(
            ERC20(debtToken).balanceOf(OPERATOR), debtTokenBalance_, "operator: debt token balance"
        );
    }

    function _assertMorphoDebtTokenCollateral(
        uint256 amount_
    ) internal view {
        MorphoPosition memory position = morpho.position(debtTokenMarket, USER);

        assertEq(position.collateral, amount_, "morpho: collateral");

        // Check that the getter is consistent
        assertEq(
            hedger.getCollateralPositionFor(debtToken, USER), amount_, "getCollateralPositionFor"
        );
    }

    function _assertMorphoReserveBalance(
        uint256 amount_
    ) internal view {
        MorphoPosition memory position = morpho.position(mgstMarket, USER);

        uint256 borrowAssets = SharesMathLib.toAssetsDown(
            position.borrowShares,
            morpho.market(mgstMarket).totalBorrowAssets,
            morpho.market(mgstMarket).totalBorrowShares
        );

        assertEq(borrowAssets, amount_, "morpho: reserve balance");
    }

    function _assertMorphoBorrowed(
        uint256 amount_
    ) internal view {
        MorphoPosition memory position = morpho.position(debtTokenMarket, USER);

        uint256 borrowAssets = SharesMathLib.toAssetsDown(
            position.borrowShares,
            morpho.market(debtTokenMarket).totalBorrowAssets,
            morpho.market(debtTokenMarket).totalBorrowShares
        );

        assertEq(borrowAssets, amount_, "morpho: borrow amount");
    }

    function _assertMorphoBorrowedLessThan(
        uint256 amount_
    ) internal view {
        MorphoPosition memory position = morpho.position(debtTokenMarket, USER);

        uint256 borrowAssets = SharesMathLib.toAssetsDown(
            position.borrowShares,
            morpho.market(debtTokenMarket).totalBorrowAssets,
            morpho.market(debtTokenMarket).totalBorrowShares
        );

        assertLt(borrowAssets, amount_, "morpho: borrow amount");
    }
}
