// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";

import {ERC20} from "solmate-6.8.0/tokens/ERC20.sol";
import {MockERC20} from "solmate-6.8.0/test/utils/mocks/MockERC20.sol";

import {
    IMorpho,
    Id as MorphoId,
    MarketParams as MorphoMarketParams
} from "morpho-blue-1.0.0/interfaces/IMorpho.sol";
import {MarketParamsLib} from "morpho-blue-1.0.0/libraries/MarketParamsLib.sol";

import {IUniswapV3Factory} from "test/lib/IUniswapV3Factory.sol";
import {IUniswapV3NonfungiblePositionManager} from
    "test/lib/IUniswapV3NonfungiblePositionManager.sol";
import {IUniswapV3Pool} from "test/lib/IUniswapV3Pool.sol";
import {SqrtPriceMath} from "test/lib/SqrtPriceMath.sol";

import {SafeTransferLib} from "solmate-6.8.0/utils/SafeTransferLib.sol";

import {Kernel, Actions} from "src/Kernel.sol";
import {MSTR} from "src/modules/TOKEN/MSTR.sol";
import {Banker} from "src/policies/Banker.sol";
import {Hedger} from "src/periphery/Hedger.sol";
import {Issuer} from "src/policies/Issuer.sol";

contract HedgerTest is Test {
    using SafeTransferLib for ERC20;

    Kernel public kernel;
    MSTR public mstr;
    Banker public banker;
    Issuer public issuer;
    MockERC20 public weth;
    MockERC20 public reserve;
    Hedger public hedger;
    IMorpho public morpho;
    MorphoId public mgstMarket;

    address public constant MORPHO = address(0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb);
    address public constant AUCTION_HOUSE = address(0xBA0000c59d144f2a9aEa064dcb2f963e1a0B3212);
    address public constant SWAP_ROUTER = address(0x2626664c2603336E57B271c5C0b26F421741e481);
    address public constant UNISWAP_V3_FACTORY = address(0x33128a8fC17869897dcE68Ed026d694621f6FDfD);
    address public constant UNISWAP_V3_POSITION_MANAGER =
        address(0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1);

    address public constant OWNER = address(1);
    address public constant USER = address(2);

    uint24 public constant RESERVE_WETH_SWAP_FEE = 500;
    uint24 public constant MGST_WETH_SWAP_FEE = 3000;

    uint256 public constant WETH_RESERVE_WETH_AMOUNT = 1000e18;
    uint256 public constant WETH_RESERVE_RESERVE_AMOUNT = 3_600_000e18;
    uint256 public constant MGST_WETH_MGST_AMOUNT = 1000e18;
    uint256 public constant MGST_WETH_WETH_AMOUNT = 100e18;

    function setUp() public {
        // Use a Base fork
        vm.createSelectFork(vm.envString("FORK_RPC_URL"), 24_698_617);

        vm.prank(OWNER);
        kernel = new Kernel();

        mstr = new MSTR(kernel, "MSTR", "MSTR");
        banker = new Banker(kernel, AUCTION_HOUSE);
        issuer = new Issuer(kernel, address(0)); // No oToken teller needed

        weth = new MockERC20("WETH", "WETH", 18);
        reserve = new MockERC20("RESERVE", "RESERVE", 18);

        // Install modules and policies
        vm.startPrank(OWNER);
        kernel.executeAction(Actions.InstallModule, address(mstr));
        kernel.executeAction(Actions.ActivatePolicy, address(banker));
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
            address(mstr), address(weth), MGST_WETH_SWAP_FEE
        );

        // Initialize MGST/WETH
        uint160 mgstWethSqrtPriceX96 = SqrtPriceMath.getSqrtPriceX96(
            address(mstr), address(weth), MGST_WETH_MGST_AMOUNT, MGST_WETH_WETH_AMOUNT
        );
        IUniswapV3Pool(mgstWethPool).initialize(mgstWethSqrtPriceX96);
        vm.stopPrank();

        // Deploy liquidity into the WETH/RESERVE pool
        vm.startPrank(OWNER);
        weth.mint(OWNER, WETH_RESERVE_WETH_AMOUNT);
        reserve.mint(OWNER, WETH_RESERVE_RESERVE_AMOUNT);
        ERC20(address(weth)).safeApprove(UNISWAP_V3_POSITION_MANAGER, WETH_RESERVE_WETH_AMOUNT);
        ERC20(address(reserve)).safeApprove(
            UNISWAP_V3_POSITION_MANAGER, WETH_RESERVE_RESERVE_AMOUNT
        );

        IUniswapV3NonfungiblePositionManager(UNISWAP_V3_POSITION_MANAGER).mint(
            IUniswapV3NonfungiblePositionManager.MintParams({
                token0: address(weth),
                token1: address(reserve),
                fee: RESERVE_WETH_SWAP_FEE,
                tickLower: -887_272,
                tickUpper: 887_272,
                amount0Desired: WETH_RESERVE_WETH_AMOUNT,
                amount1Desired: WETH_RESERVE_RESERVE_AMOUNT,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp
            })
        );
        vm.stopPrank();

        // Deploy liquidity into the MGST/WETH pool
        vm.startPrank(OWNER);
        issuer.mint(OWNER, MGST_WETH_MGST_AMOUNT);
        weth.mint(OWNER, MGST_WETH_WETH_AMOUNT);
        ERC20(address(mstr)).safeApprove(UNISWAP_V3_POSITION_MANAGER, MGST_WETH_MGST_AMOUNT);
        ERC20(address(weth)).safeApprove(UNISWAP_V3_POSITION_MANAGER, MGST_WETH_WETH_AMOUNT);

        IUniswapV3NonfungiblePositionManager(UNISWAP_V3_POSITION_MANAGER).mint(
            IUniswapV3NonfungiblePositionManager.MintParams({
                token0: address(mstr),
                token1: address(weth),
                fee: MGST_WETH_SWAP_FEE,
                tickLower: -887_272,
                tickUpper: 887_272,
                amount0Desired: MGST_WETH_MGST_AMOUNT,
                amount1Desired: MGST_WETH_WETH_AMOUNT,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp
            })
        );
        vm.stopPrank();

        // Create a morpho market
        MorphoMarketParams memory mgstMarketParams = MorphoMarketParams({
            loanToken: address(reserve),
            collateralToken: address(mstr),
            oracle: address(mstr), // ConvertibleDebtToken implements IOracle, given that it has a fixed conversion price
            irm: address(0), // Disabled
            lltv: 0 // Disabled
        });
        mgstMarket = MarketParamsLib.id(mgstMarketParams);

        morpho = IMorpho(MORPHO);
        morpho.createMarket(mgstMarketParams);

        // Create a hedger
        hedger = new Hedger(
            address(mstr),
            address(weth),
            address(reserve),
            MorphoId.unwrap(mgstMarket),
            MORPHO,
            SWAP_ROUTER,
            RESERVE_WETH_SWAP_FEE,
            MGST_WETH_SWAP_FEE
        );
    }
}
