// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.19;

import {IOracle} from "morpho-blue-1.0.0/interfaces/IOracle.sol";
import {ERC20} from "solmate-6.8.0/tokens/ERC20.sol";

import {Kernel, Keycode, Permissions, Policy, toKeycode} from "src/Kernel.sol";
import {PRICEv2} from "src/modules/PRICE/PRICE.v2.sol";
import {IMegaTokenOracle} from "./interfaces/IMegaTokenOracle.sol";

/// @title MegaTokenOracle
/// @notice This policy provides an oracle price for the protocol token, compatible with the interface used by the Morpho protocol
contract MegaTokenOracle is Policy, IMegaTokenOracle {
    // =========  STATE ========= //

    uint256 internal _priceScale;
    uint256 internal _tokenScale;
    address internal immutable _LOAN_TOKEN;
    uint256 internal immutable _LOAN_TOKEN_SCALE;

    // Modules
    address public TOKEN;
    PRICEv2 public PRICE;

    // =========  POLICY SETUP ========= //

    constructor(Kernel kernel_, address loanToken_) Policy(kernel_) {
        // Validate
        if (loanToken_ == address(0)) revert InvalidParams("loanToken");

        _LOAN_TOKEN = loanToken_;
        _LOAN_TOKEN_SCALE = 10 ** ERC20(loanToken_).decimals();
    }

    /// @inheritdoc Policy
    function configureDependencies() external override returns (Keycode[] memory dependencies) {
        dependencies = new Keycode[](2);
        dependencies[0] = toKeycode("PRICE");
        dependencies[1] = toKeycode("TOKEN");

        PRICE = PRICEv2(getModuleAddress(dependencies[0]));
        TOKEN = getModuleAddress(dependencies[1]);

        // Check that PRICE is 18 decimals
        // TOKEN is hard-coded to 18 decimals
        if (PRICE.decimals() != 18) revert InvalidParams("PRICE decimals");

        return dependencies;
    }

    /// @inheritdoc Policy
    function requestPermissions()
        external
        pure
        override
        returns (Permissions[] memory permissions)
    {
        permissions = new Permissions[](0);

        return permissions;
    }

    function VERSION() external pure returns (uint8 major, uint8 minor) {
        major = 1;
        minor = 0;

        return (major, minor);
    }

    // ========= TOKEN FUNCTIONS ========= //

    /// @inheritdoc IMegaTokenOracle
    function getCollateralToken() external view override returns (address) {
        return TOKEN;
    }

    /// @inheritdoc IMegaTokenOracle
    function getLoanToken() external view override returns (address) {
        return _LOAN_TOKEN;
    }

    // =========  PRICE FUNCTIONS ========= //

    /// @inheritdoc IOracle
    /// @dev        This function returns the price of 1 unit of the protocol token in terms of the loan token, scaled by 1e36.
    function price() external view returns (uint256) {
        // Scale: PRICE decimals
        // We know that PRICE decimals == TOKEN decimals == 18
        uint256 collateralPriceInLoanToken = PRICE.getPriceIn(TOKEN, _LOAN_TOKEN);

        // Adjust to the expected scale
        // Scale = 36 + loan decimals - collateral decimals (always 18)
        // = 18 + loan decimals
        // Price is always in 18 decimals, so we just need to add the loan decimal scale
        return _LOAN_TOKEN_SCALE * collateralPriceInLoanToken;
    }
}
