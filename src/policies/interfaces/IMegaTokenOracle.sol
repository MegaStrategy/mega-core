// SPDX-License-Identifier: TBD
pragma solidity ^0.8.19;

import {IOracle} from "morpho-blue-1.0.0/interfaces/IOracle.sol";

interface IMegaTokenOracle is IOracle {
    /// @notice The collateral token configured for this oracle
    function getCollateralToken() external view returns (address);

    /// @notice The loan token configured for this oracle
    function getLoanToken() external view returns (address);
}
