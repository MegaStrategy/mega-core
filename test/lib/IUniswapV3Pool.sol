// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.19;

interface IUniswapV3Pool {
    function initialize(
        uint160 sqrtPriceX96
    ) external;
}
