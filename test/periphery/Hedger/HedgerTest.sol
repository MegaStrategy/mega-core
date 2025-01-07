// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";

import {MockERC20} from "solmate-6.8.0/test/utils/mocks/MockERC20.sol";

import {
    IMorpho,
    Id as MorphoId,
    MarketParams as MorphoMarketParams
} from "morpho-blue-1.0.0/interfaces/IMorpho.sol";
import {MarketParamsLib} from "morpho-blue-1.0.0/libraries/MarketParamsLib.sol";

import {Kernel, Actions} from "src/Kernel.sol";
import {MSTR} from "src/modules/TOKEN/MSTR.sol";
import {Banker} from "src/policies/Banker.sol";
import {Hedger} from "src/periphery/Hedger.sol";

contract HedgerTest is Test {
    Kernel public kernel;
    MSTR public mstr;
    Banker public banker;
    MockERC20 public weth;
    MockERC20 public reserve;
    Hedger public hedger;
    IMorpho public morpho;
    MorphoId public mgstMarket;

    address public constant MORPHO = address(0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb);
    address public constant AUCTION_HOUSE = address(0xBA0000c59d144f2a9aEa064dcb2f963e1a0B3212);
    address public constant SWAP_ROUTER = address(0x2626664c2603336E57B271c5C0b26F421741e481);

    address public constant OWNER = address(1);
    address public constant USER = address(2);

    function setUp() public {
        // Use a Base fork
        vm.createSelectFork(vm.envString("FORK_RPC_URL"), 24_698_617);

        vm.prank(OWNER);
        kernel = new Kernel();

        mstr = new MSTR(kernel, "MSTR", "MSTR");
        banker = new Banker(kernel, AUCTION_HOUSE);

        weth = new MockERC20("WETH", "WETH", 18);
        reserve = new MockERC20("RESERVE", "RESERVE", 18);

        // Install modules and policies
        vm.startPrank(OWNER);
        kernel.executeAction(Actions.InstallModule, address(mstr));
        kernel.executeAction(Actions.ActivatePolicy, address(banker));
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
            SWAP_ROUTER
        );
    }
}
