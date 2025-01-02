// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @dev Extracted from the contract, to avoid importing and compiling all of the axis-periphery contracts
interface IBaseDirectToLiquidity {
    struct OnCreateParams {
        uint24 poolPercent;
        uint48 vestingStart;
        uint48 vestingExpiry;
        address recipient;
        bytes implParams;
    }
}
