// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @dev Extracted from the contract, to avoid importing and compiling all of the axis-periphery contracts
interface IUniswapV3DirectToLiquidity {
    struct UniswapV3OnCreateParams {
        uint24 poolFee;
        uint24 maxSlippage;
    }
}
