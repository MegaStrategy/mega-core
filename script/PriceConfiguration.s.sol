// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import {Script} from "@forge-std/Script.sol";
import {WithEnvironment} from "./WithEnvironment.s.sol";
import {console2} from "@forge-std/console2.sol";

import {toSubKeycode} from "src/Submodules.sol";
import {PRICEv2} from "src/modules/PRICE/PRICE.v2.sol";
import {PriceConfigV2} from "src/policies/PriceConfig.v2.sol";

import {ChainlinkPriceFeeds} from "src/modules/PRICE/submodules/feeds/ChainlinkPriceFeeds.sol";
import {UniswapV3Price} from "src/modules/PRICE/submodules/feeds/UniswapV3Price.sol";
import {SimplePriceFeedStrategy} from
    "src/modules/PRICE/submodules/strategies/SimplePriceFeedStrategy.sol";

import {IUniswapV3Pool} from
    "@uniswap-v3-core-1.0.2-solc-0.8-simulate/interfaces/IUniswapV3Pool.sol";
import {AggregatorV2V3Interface} from "src/lib/Chainlink/AggregatorV2V3Interface.sol";

contract PriceConfiguration is Script, WithEnvironment {
    uint48 internal constant DEFAULT_CHAINLINK_UPDATE_THRESHOLD = 24 hours;

    /// @notice Installs PRICEv2 submodules
    /// @dev    This must be run by an address with the "admin" role
    function installSubmodules(
        string calldata chain_
    ) public {
        _loadEnv(chain_);

        PriceConfigV2 priceConfigV2 =
            PriceConfigV2(_envAddressNotZero("mega.policies.PriceConfigV2"));

        // Chainlink
        {
            ChainlinkPriceFeeds chainlinkPriceFeeds = ChainlinkPriceFeeds(
                _envAddressNotZero("mega.submodules.PriceV2.ChainlinkPriceFeeds")
            );

            console2.log("Installing submodule: Chainlink Price Feeds");
            vm.startBroadcast();
            priceConfigV2.installSubmodule(chainlinkPriceFeeds);
            vm.stopBroadcast();
        }

        // Uniswap V3
        {
            UniswapV3Price uniswapV3Price =
                UniswapV3Price(_envAddressNotZero("mega.submodules.PriceV2.UniswapV3Price"));

            console2.log("Installing submodule: Uniswap V3 Price");
            vm.startBroadcast();
            priceConfigV2.installSubmodule(uniswapV3Price);
            vm.stopBroadcast();
        }

        // SimplePriceFeedStrategy
        {
            SimplePriceFeedStrategy simplePriceFeedStrategy = SimplePriceFeedStrategy(
                _envAddressNotZero("mega.submodules.PriceV2.SimplePriceFeedStrategy")
            );

            console2.log("Installing submodule: Simple Price Feed Strategy");
            vm.startBroadcast();
            priceConfigV2.installSubmodule(simplePriceFeedStrategy);
            vm.stopBroadcast();
        }
    }

    /// @notice Configures assets in the PRICE module
    /// @dev    This must be run by an address with the "manager" role
    function configureAssets(
        string calldata chain_
    ) public {
        _loadEnv(chain_);

        PriceConfigV2 priceConfigV2 =
            PriceConfigV2(_envAddressNotZero("mega.policies.PriceConfigV2"));

        // MGST
        {
            PRICEv2.Component[] memory mgstFeeds = new PRICEv2.Component[](1);
            mgstFeeds[0] = PRICEv2.Component(
                toSubKeycode("PRICE.UNIV3"),
                UniswapV3Price.getTokenTWAP.selector,
                abi.encode(
                    UniswapV3Price.UniswapV3Params({
                        pool: IUniswapV3Pool(_envAddressNotZero("external.pools.mgstWeth")),
                        observationWindowSeconds: 15 minutes
                    })
                )
            );

            PRICEv2.Component memory mgstStrategy = PRICEv2.Component(
                toSubKeycode("PRICE.SIMPLESTRATEGY"),
                SimplePriceFeedStrategy.getAveragePrice.selector,
                abi.encode(0)
            );

            console2.log("Configuring asset: MGST");
            vm.startBroadcast();
            priceConfigV2.addAssetPrice(
                _envAddressNotZero("mega.modules.Token"),
                false, // Don't store moving average
                false, // Don't use moving average
                0, // No moving average duration
                0, // No last observation time
                new uint256[](0), // No observations
                mgstStrategy, // Strategy
                mgstFeeds // Feeds
            );
            vm.stopBroadcast();
        }

        // WETH
        {
            PRICEv2.Component[] memory wethFeeds = new PRICEv2.Component[](1);
            wethFeeds[0] = PRICEv2.Component(
                toSubKeycode("PRICE.CHAINLINK"),
                ChainlinkPriceFeeds.getOneFeedPrice.selector,
                abi.encode(
                    ChainlinkPriceFeeds.OneFeedParams(
                        AggregatorV2V3Interface(_envAddressNotZero("external.chainlink.usdPerEth")),
                        DEFAULT_CHAINLINK_UPDATE_THRESHOLD
                    )
                )
            );

            PRICEv2.Component memory wethStrategy = PRICEv2.Component(
                toSubKeycode("PRICE.SIMPLESTRATEGY"),
                SimplePriceFeedStrategy.getAveragePrice.selector,
                abi.encode(0)
            );

            console2.log("Configuring asset: WETH");
            vm.startBroadcast();
            priceConfigV2.addAssetPrice(
                _envAddressNotZero("external.tokens.WETH"),
                false, // Don't store moving average
                false, // Don't use moving average
                0, // No moving average duration
                0, // No last observation time
                new uint256[](0), // No observations
                wethStrategy, // Strategy
                wethFeeds // Feeds
            );
            vm.stopBroadcast();
        }

        // USDC
        {
            PRICEv2.Component[] memory usdcFeeds = new PRICEv2.Component[](1);
            usdcFeeds[0] = PRICEv2.Component(
                toSubKeycode("PRICE.CHAINLINK"),
                ChainlinkPriceFeeds.getOneFeedPrice.selector,
                abi.encode(
                    ChainlinkPriceFeeds.OneFeedParams(
                        AggregatorV2V3Interface(_envAddressNotZero("external.chainlink.usdPerUsdc")),
                        DEFAULT_CHAINLINK_UPDATE_THRESHOLD
                    )
                )
            );

            PRICEv2.Component memory usdcStrategy = PRICEv2.Component(
                toSubKeycode("PRICE.SIMPLESTRATEGY"),
                SimplePriceFeedStrategy.getAveragePrice.selector,
                abi.encode(0)
            );

            console2.log("Configuring asset: USDC");
            vm.startBroadcast();
            priceConfigV2.addAssetPrice(
                _envAddressNotZero("external.tokens.USDC"),
                false, // Don't store moving average
                false, // Don't use moving average
                0, // No moving average duration
                0, // No last observation time
                new uint256[](0), // No observations
                usdcStrategy, // Strategy
                usdcFeeds // Feeds
            );
            vm.stopBroadcast();
        }
    }
}
