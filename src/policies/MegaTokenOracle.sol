// SPDX-License-Identifier: TBD
pragma solidity 0.8.19;

import {IOracle} from "morpho-blue-1.0.0/interfaces/IOracle.sol";
import {ERC20} from "solmate-6.8.0/tokens/ERC20.sol";

import {Kernel, Keycode, Permissions, Policy, toKeycode} from "src/Kernel.sol";
import {PRICEv2} from "src/modules/PRICE/PRICE.v2.sol";

/// @title MegaTokenOracle
/// @notice This policy provides an oracle price for the protocol token, compatible with the interface used by the Morpho protocol
contract MegaTokenOracle is Policy, IOracle {
    // =========  ERRORS ========= //

    error InvalidParams(string reason_);

    // =========  STATE ========= //

    address public immutable loanToken;

    // Modules
    address public TOKEN;
    PRICEv2 public PRICE;

    // =========  POLICY SETUP ========= //

    constructor(Kernel kernel_, address loanToken_) Policy(kernel_) {
        // Validate
        if (loanToken_ == address(0)) revert InvalidParams("loanToken");

        loanToken = loanToken_;
    }

    /// @inheritdoc Policy
    function configureDependencies() external override returns (Keycode[] memory dependencies) {
        dependencies = new Keycode[](2);
        dependencies[0] = toKeycode("PRICE");
        dependencies[1] = toKeycode("TOKEN");

        PRICE = PRICEv2(getModuleAddress(dependencies[0]));
        TOKEN = getModuleAddress(dependencies[1]);

        // Validate decimals
        if (PRICE.decimals() != 18) revert InvalidParams("price decimals");
        if (ERC20(TOKEN).decimals() != 18) revert InvalidParams("token decimals");

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

    // =========  PRICE FUNCTIONS ========= //

    /// @inheritdoc IOracle
    /// @dev        This function returns the price of 1 unit of the protocol token in terms of the loan token, scaled by 1e36.
    function price() external view returns (uint256) {
        uint256 collateralPriceInLoanToken = PRICE.getPriceIn(TOKEN, loanToken);
        uint256 loanTokenScale = 10 ** ERC20(loanToken).decimals();

        return 1e36 * collateralPriceInLoanToken / loanTokenScale;
    }
}
