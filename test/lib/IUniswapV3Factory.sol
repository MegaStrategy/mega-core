// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.19;

interface IUniswapV3Factory {
    function createPool(
        address token0,
        address token1,
        uint24 fee
    ) external returns (address pool);
}
