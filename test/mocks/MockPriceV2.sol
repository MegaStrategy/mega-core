// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.19;

import {PRICEv2} from "src/modules/PRICE/PRICE.v2.sol";
import {Kernel, Keycode, Module, toKeycode} from "src/Kernel.sol";

contract MockPriceV2 is PRICEv2 {
    mapping(address => uint256) public assetPrices;

    constructor(Kernel kernel_, uint8 decimals_) Module(kernel_) {
        decimals = decimals_;
    }

    // ========== KERNEL FUNCTIONS ========== //

    /// @inheritdoc Module
    function KEYCODE() public pure override returns (Keycode) {
        return toKeycode("PRICE");
    }

    /// @inheritdoc Module
    function VERSION() external pure override returns (uint8 major, uint8 minor) {
        major = 2;
        minor = 0;
    }

    // ========== PRICE FUNCTIONS ========== //

    function getPrice(
        address asset_
    ) public view override returns (uint256) {
        return assetPrices[asset_];
    }

    function getPriceIn(address asset_, address base_) external view override returns (uint256) {
        uint256 assetPrice = getPrice(asset_);
        uint256 basePrice = getPrice(base_);

        return (assetPrice * 10 ** decimals) / basePrice;
    }

    function setPrice(address asset_, uint256 price_) public {
        assetPrices[asset_] = price_;
    }

    // =========  NOT IMPLEMENTED ========= //

    function getAssets() external view override returns (address[] memory) {}

    function getAssetData(
        address
    ) external pure override returns (Asset memory) {}

    function isAssetApproved(
        address
    ) external pure override returns (bool) {
        return false;
    }

    function getPrice(address asset_, uint48 maxAge_) external view override returns (uint256) {}

    function getPrice(
        address asset_,
        Variant variant_
    ) public view override returns (uint256 _price, uint48 _timestamp) {}

    function getPriceIn(
        address asset_,
        address base_,
        uint48 maxAge_
    ) external view override returns (uint256) {}

    function getPriceIn(
        address asset_,
        address base_,
        Variant variant_
    ) external view override returns (uint256 _price, uint48 _timestamp) {}

    function storePrice(
        address asset_
    ) external override {}

    function storeObservations() external override {}

    function addAsset(
        address asset_,
        bool storeMovingAverage_,
        bool useMovingAverage_,
        uint32 movingAverageDuration_,
        uint48 lastObservationTime_,
        uint256[] memory observations_,
        Component memory strategy_,
        Component[] memory feeds_
    ) external override {}

    function removeAsset(
        address asset_
    ) external override {}

    function updateAssetPriceFeeds(address asset_, Component[] memory feeds_) external override {}

    function updateAssetPriceStrategy(
        address asset_,
        Component memory strategy_,
        bool useMovingAverage_
    ) external override {}

    function updateAssetMovingAverage(
        address asset_,
        bool storeMovingAverage_,
        uint32 movingAverageDuration_,
        uint48 lastObservationTime_,
        uint256[] memory observations_
    ) external override {}
}
