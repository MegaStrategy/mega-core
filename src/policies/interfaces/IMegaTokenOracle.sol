// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IOracle} from "@morpho-blue-1.0.0/interfaces/IOracle.sol";

interface IMegaTokenOracle is IOracle {
    // =========  ERRORS ========= //

    error InvalidParams(string reason_);

    // =========  FUNCTIONS ========= //

    /// @notice The collateral token configured for this oracle
    function getCollateralToken() external view returns (address);

    /// @notice The loan token configured for this oracle
    function getLoanToken() external view returns (address);
}
