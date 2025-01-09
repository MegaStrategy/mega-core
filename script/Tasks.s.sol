// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.19;

import {Script} from "@forge-std/Script.sol";
import {WithEnvironment} from "./WithEnvironment.s.sol";
import {console2} from "@forge-std/console2.sol";
import {ERC20} from "solmate-6.8.0/tokens/ERC20.sol";

import {RolesAdmin} from "../src/policies/RolesAdmin.sol";
import {Banker} from "../src/policies/Banker.sol";
import {Issuer} from "../src/policies/Issuer.sol";
import {IUniswapV3Factory} from "test/lib/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "test/lib/IUniswapV3Pool.sol";
import {IUniswapV3NonfungiblePositionManager} from
    "test/lib/IUniswapV3NonfungiblePositionManager.sol";
import {SqrtPriceMath} from "test/lib/SqrtPriceMath.sol";
import {
    IMorpho,
    Id as MorphoId,
    MarketParams as MorphoMarketParams
} from "morpho-blue-1.0.0/interfaces/IMorpho.sol";
import {MarketParamsLib} from "morpho-blue-1.0.0/libraries/MarketParamsLib.sol";

contract TasksScript is Script, WithEnvironment {
    uint256 public constant LLTV = 945e15; // 94.5%

    function addAdmin(string calldata chain_, address admin_) external {
        _loadEnv(chain_);

        vm.startBroadcast();
        RolesAdmin(_envAddressNotZero("mega.policies.RolesAdmin")).grantRole(
            bytes32("admin"), admin_
        );
        vm.stopBroadcast();
    }

    function addManager(string calldata chain_, address manager_) external {
        _loadEnv(chain_);

        vm.startBroadcast();
        RolesAdmin(_envAddressNotZero("mega.policies.RolesAdmin")).grantRole(
            bytes32("manager"), manager_
        );
        vm.stopBroadcast();
    }

    function initialize(
        string calldata chain_
    ) external {
        _loadEnv(chain_);

        // Add as admin and manager first

        // Initialize the Banker
        vm.startBroadcast();
        Banker(_envAddressNotZero("mega.policies.Banker")).initialize(0, 0, 0, 1e18);
        vm.stopBroadcast();
    }

    function createDebtToken(string calldata chain_, uint256 conversionPrice_) external {
        _loadEnv(chain_);

        // Create the debt token
        uint48 maturity = uint48(block.timestamp + 1 days);
        vm.startBroadcast();
        address debtToken = Banker(_envAddressNotZero("mega.policies.Banker")).createDebtToken(
            address(_envAddressNotZero("external.tokens.USDC")), maturity, conversionPrice_
        );
        vm.stopBroadcast();
        console2.log("debtToken", debtToken);
    }

    function issueDebtToken(
        string calldata chain_,
        address debtToken_,
        address to_,
        uint256 amount_
    ) external {
        _loadEnv(chain_);

        // Transfer the USDC amount to the Treasury
        vm.startBroadcast();
        ERC20(address(_envAddressNotZero("external.tokens.USDC"))).transfer(
            address(_envAddressNotZero("mega.modules.OlympusTreasury")), amount_
        );
        vm.stopBroadcast();

        // Verify the USDC is in the Treasury
        console2.log(
            "USDC in Treasury",
            ERC20(address(_envAddressNotZero("external.tokens.USDC"))).balanceOf(
                _envAddressNotZero("mega.modules.OlympusTreasury")
            )
        );

        // Issue the debt token
        vm.startBroadcast();
        Banker(_envAddressNotZero("mega.policies.Banker")).issue(debtToken_, to_, amount_);
        vm.stopBroadcast();

        console2.log("Debt token issued", amount_);
    }

    function convertDebtToken(
        string calldata chain_,
        address debtToken_,
        uint256 amount_
    ) external {
        _loadEnv(chain_);

        // Approve the Banker to spend the debt token
        vm.startBroadcast();
        ERC20(debtToken_).approve(
            address(Banker(_envAddressNotZero("mega.policies.Banker"))), amount_
        );
        vm.stopBroadcast();

        // Convert the debt token to TOKEN
        vm.startBroadcast();
        Banker(_envAddressNotZero("mega.policies.Banker")).convert(debtToken_, amount_);
        vm.stopBroadcast();
    }

    function redeemDebtToken(
        string calldata chain_,
        address debtToken_,
        uint256 amount_
    ) external {
        _loadEnv(chain_);

        // Redeem the debt token
        vm.startBroadcast();
        Banker(_envAddressNotZero("mega.policies.Banker")).redeem(debtToken_, amount_);
        vm.stopBroadcast();
    }

    function createOptionToken(
        string calldata chain_
    ) external {
        _loadEnv(chain_);

        uint48 expiry = uint48(block.timestamp + 1 days);
        vm.startBroadcast();
        address optionToken = Issuer(_envAddressNotZero("mega.policies.Issuer")).createO(
            address(_envAddressNotZero("external.tokens.WETH")), expiry, 2e18
        );
        vm.stopBroadcast();
        console2.log("optionToken", optionToken);
    }

    function issueOptionToken(
        string calldata chain_,
        address optionToken_,
        address to_,
        uint256 amount_
    ) external {
        _loadEnv(chain_);

        // Issue the option token
        vm.startBroadcast();
        Issuer(_envAddressNotZero("mega.policies.Issuer")).issueO(optionToken_, to_, amount_);
        vm.stopBroadcast();

        console2.log("Option token issued", amount_);
    }

    function mintMgst(string calldata chain_, address to_, uint256 amount_) external {
        _loadEnv(chain_);

        vm.startBroadcast();
        Issuer(_envAddressNotZero("mega.policies.Issuer")).mint(to_, amount_);
        vm.stopBroadcast();

        console2.log("MGST minted", amount_);
    }

    /// @dev This is only useful for testing. The production pool is created by the launch auction.
    function createMgstWethPool(
        string calldata chain_,
        uint256 mgstAmount_,
        uint256 wethAmount_,
        uint24 swapFee_
    ) external {
        _loadEnv(chain_);

        address mgst = _envAddressNotZero("mega.modules.Token");
        address weth = _envAddressNotZero("external.tokens.WETH");

        // Create the pool. Will revert if the pool already exists.
        vm.startBroadcast();
        address pool = IUniswapV3Factory(_envAddressNotZero("external.uniswap.v3.factory"))
            .createPool(mgst, weth, swapFee_);
        vm.stopBroadcast();

        console2.log("MGST/WETH pool created at", pool);

        // Initialize the pool
        vm.startBroadcast();
        uint160 mgstWethSqrtPriceX96 =
            SqrtPriceMath.getSqrtPriceX96(mgst, weth, mgstAmount_, wethAmount_);
        IUniswapV3Pool(pool).initialize(mgstWethSqrtPriceX96);
        vm.stopBroadcast();

        console2.log("MGST/WETH pool initialized");
    }

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

        int24 tickSpacing = IUniswapV3Factory(_envAddressNotZero("external.uniswap.v3.factory"))
            .feeAmountTickSpacing(fee_);

        // Determine the tick lower and upper
        int24 tickLower = (-887_272 / tickSpacing) * tickSpacing;
        int24 tickUpper = (887_272 / tickSpacing) * tickSpacing;

        vm.startBroadcast();
        IUniswapV3NonfungiblePositionManager(
            _envAddressNotZero("external.uniswap.v3.positionManager")
        ).mint(
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
                recipient: msg.sender,
                deadline: block.timestamp
            })
        );
        vm.stopBroadcast();
    }

    function deployMgstWethLiquidity(
        string calldata chain_,
        uint256 mgstAmount_,
        uint256 wethAmount_,
        uint24 swapFee_
    ) external {
        _loadEnv(chain_);

        address mgst = _envAddressNotZero("mega.modules.Token");
        address weth = _envAddressNotZero("external.tokens.WETH");
        address positionManager = _envAddressNotZero("external.uniswap.v3.positionManager");

        // Mint MGST
        // Caller must be an admin
        vm.startBroadcast();
        Issuer(_envAddressNotZero("mega.policies.Issuer")).mint(msg.sender, mgstAmount_);
        console2.log("MGST minted", mgstAmount_);
        console2.log("MGST minted to", msg.sender);
        vm.stopBroadcast();

        // WETH should have been supplied to the caller

        // Approve the position manager to spend the MGST and WETH
        vm.startBroadcast();
        ERC20(mgst).approve(positionManager, mgstAmount_);
        ERC20(weth).approve(positionManager, wethAmount_);
        vm.stopBroadcast();
        console2.log("MGST and WETH spending approved");

        // Mint liquidity
        _mint(mgst, weth, mgstAmount_, wethAmount_, swapFee_);
        console2.log("Liquidity minted");
    }

    function _getMgstMorphoMarketParams()
        internal
        view
        returns (MorphoMarketParams memory marketParams)
    {
        address mgst = _envAddressNotZero("mega.modules.Token");
        address usdc = _envAddressNotZero("external.tokens.USDC");

        marketParams = MorphoMarketParams({
            loanToken: usdc,
            collateralToken: mgst,
            oracle: address(0), // TODO add oracle for MGST
            irm: address(0), // Disabled
            lltv: LLTV
        });

        return marketParams;
    }

    function createMgstMorphoMarket(
        string calldata chain_
    ) external {
        _loadEnv(chain_);

        MorphoMarketParams memory mgstMarketParams = _getMgstMorphoMarketParams();

        vm.startBroadcast();
        IMorpho(_envAddressNotZero("external.morpho")).createMarket(mgstMarketParams);
        vm.stopBroadcast();

        console2.log("MGST Morpho market created");
        console2.log("Id:", vm.toString(MorphoId.unwrap(MarketParamsLib.id(mgstMarketParams))));
    }

    function supplyMgstToMorphoMarket(string calldata chain_, uint256 amount_) external {
        _loadEnv(chain_);

        address mgst = _envAddressNotZero("mega.modules.Token");
        address morpho = _envAddressNotZero("external.morpho");

        // Mint MGST
        // Caller must be an admin
        vm.startBroadcast();
        Issuer(_envAddressNotZero("mega.policies.Issuer")).mint(msg.sender, amount_);
        console2.log("MGST minted", amount_);
        console2.log("MGST minted to", msg.sender);
        vm.stopBroadcast();

        // Approve the morpho market to spend the MGST
        vm.startBroadcast();
        ERC20(mgst).approve(address(morpho), amount_);
        vm.stopBroadcast();

        // Deposit MGST into the morpho market
        MorphoMarketParams memory mgstMarketParams = _getMgstMorphoMarketParams();

        vm.startBroadcast();
        IMorpho(_envAddressNotZero("external.morpho")).supply(
            mgstMarketParams, amount_, 0, msg.sender, ""
        );
        vm.stopBroadcast();

        console2.log("MGST supplied to Morpho market");
    }

    function createMgstDebtTokenMarket(string calldata chain_, address debtToken_) external {
        _loadEnv(chain_);

        address mgst = _envAddressNotZero("mega.modules.Token");

        MorphoMarketParams memory marketParams = MorphoMarketParams({
            loanToken: debtToken_,
            collateralToken: mgst,
            oracle: debtToken_,
            irm: address(0), // Disabled
            lltv: LLTV
        });

        vm.startBroadcast();
        IMorpho(_envAddressNotZero("external.morpho")).createMarket(marketParams);
        vm.stopBroadcast();

        console2.log("MGST debt token market created");
        console2.log("Id:", vm.toString(MorphoId.unwrap(MarketParamsLib.id(marketParams))));
    }
}
