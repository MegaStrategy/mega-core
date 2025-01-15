// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.19;

import {Kernel, Policy, Keycode, toKeycode, Permissions} from "src/Kernel.sol";

// Modules
import {TRSRYv1} from "src/modules/TRSRY/TRSRY.v1.sol";
import {TOKENv1} from "src/modules/TOKEN/TOKEN.v1.sol";
import {ROLESv1, RolesConsumer} from "src/modules/ROLES/OlympusRoles.sol";

import {ERC20} from "solmate-6.8.0/tokens/ERC20.sol";
import {Timestamp} from "axis-core-1.0.1/lib/Timestamp.sol";
import {TransferHelper} from "src/lib/TransferHelper.sol";

import {FixedStrikeOptionToken as oToken} from "src/lib/oTokens/FixedStrikeOptionToken.sol";
import {IFixedStrikeOptionTeller as oTeller} from "src/lib/oTokens/IFixedStrikeOptionTeller.sol";

import {IIssuer} from "src/policies/interfaces/IIssuer.sol";

/// @title  Issuer
/// @notice Policy that manages issuance of the protocol token and options tokens
contract Issuer is Policy, RolesConsumer, IIssuer {
    using Timestamp for uint48;
    using TransferHelper for ERC20;

    // ========== STATE ========== //

    // Modules
    TRSRYv1 internal TRSRY;
    TOKENv1 internal TOKEN;

    // Local state
    bool public locallyActive;
    oTeller public teller;

    /// @notice Whether an oToken was created by this contract
    mapping(address => bool) public createdBy;

    // ========= POLICY SETUP ========= //

    constructor(Kernel kernel_, address teller_) Policy(kernel_) {
        // Set the teller to create oTokens from
        teller = oTeller(teller_);

        // Enable by default
        locallyActive = true;
    }

    /// @inheritdoc Policy
    function configureDependencies() external override returns (Keycode[] memory dependencies) {
        dependencies = new Keycode[](3);
        dependencies[0] = toKeycode("TRSRY");
        dependencies[1] = toKeycode("TOKEN");
        dependencies[2] = toKeycode("ROLES");

        TRSRY = TRSRYv1(getModuleAddress(dependencies[0]));
        TOKEN = TOKENv1(getModuleAddress(dependencies[1]));
        ROLES = ROLESv1(getModuleAddress(dependencies[2]));
    }

    /// @inheritdoc Policy
    function requestPermissions()
        external
        view
        override
        returns (Permissions[] memory permissions)
    {
        Keycode TOKEN_KEYCODE = TOKEN.KEYCODE();

        permissions = new Permissions[](2);
        permissions[0] = Permissions(TOKEN_KEYCODE, TOKENv1.mint.selector);
        permissions[1] = Permissions(TOKEN_KEYCODE, TOKENv1.increaseMintApproval.selector);
    }

    // ========= MINT ========= //

    /// @inheritdoc IIssuer
    /// @dev    This function reverts if:
    ///         - The caller does not have the admin role
    ///         - The policy is not locally active
    ///         - The amount is zero
    ///         - The to address is zero
    function mint(
        address to_,
        uint256 amount_
    ) external override onlyRole("admin") onlyWhileActive {
        // Amount must be greater than zero
        if (amount_ == 0) revert InvalidParam("amount");

        // To address must not be zero
        if (to_ == address(0)) revert InvalidParam("to");

        // Increase mint allowance by provided amount
        TOKEN.increaseMintApproval(address(this), amount_);

        // Mint the protocol token
        TOKEN.mint(to_, amount_);
    }

    // ========== oTokens ========= //

    /// @inheritdoc IIssuer
    /// @dev    This function reverts if:
    ///         - The caller does not have the admin role
    ///         - Validation by the oToken teller fails
    ///
    ///         Note: the expiry timestamp is rounded down to the nearest day
    function createO(
        address quoteToken_,
        uint48 expiry_,
        uint256 convertiblePrice_
    ) external override onlyRole("admin") onlyWhileActive returns (address token) {
        // Create oToken on oTeller
        // Teller validates the inputs
        token = address(
            teller.deploy(
                ERC20(address(TOKEN)), // payoutToken_ = protocol token
                ERC20(quoteToken_), // quoteToken_ = quoteToken
                uint48(0), // eligible_ = immediately: TODO should we allow setting this?
                expiry_, // expiry_ = expiry
                address(TRSRY), // receiver_ = treasury (where funds go when options are exercised)
                true, // call_ = true
                convertiblePrice_ // strikePrice_ = convertiblePrice
            )
        );

        // Mark the oToken as created by this contract
        createdBy[token] = true;

        // Emit event
        emit oTokenCreated(token);
    }

    /// @inheritdoc IIssuer
    /// @dev    This function reverts if:
    ///         - The caller does not have the admin role
    ///         - `token_` is not an oToken created by this contract
    ///         - `to_` is zero
    ///         - `amount_` is zero
    function issueO(
        address token_,
        address to_,
        uint256 amount_
    ) external override onlyRole("admin") onlyWhileActive {
        // Validate that the oToken was created by this contract
        if (!createdBy[token_]) revert InvalidParam("token");

        // Cannot send to zero address
        if (to_ == address(0)) revert InvalidParam("to");

        // Amount must be greater than zero
        if (amount_ == 0) revert InvalidParam("amount");

        // Mint TOKENs to fund the oToken with
        TOKEN.increaseMintApproval(address(this), amount_);
        TOKEN.mint(address(this), amount_);

        // Mint the oToken from the teller
        // Approve the teller to pull the newly minted TOKENs
        ERC20(address(TOKEN)).safeApprove(address(teller), amount_);
        teller.create(oToken(token_), amount_);

        // Send the oTokens to the recipient
        ERC20(token_).safeTransfer(to_, amount_);

        // Emit event
        emit oTokenIssued(token_, to_, amount_);
    }

    // ========== ADMIN ========== //

    /// @notice Set the oToken teller
    /// @dev    This function reverts if:
    ///         - The caller does not have the admin role
    ///
    /// @param teller_ The new oToken teller
    function setTeller(
        address teller_
    ) external onlyRole("admin") {
        teller = oTeller(teller_);
    }

    /// @notice Enable the contract functionality
    /// @dev    This function reverts if:
    ///         - The caller does not have the admin role
    function activate() external onlyRole("admin") {
        locallyActive = true;
    }

    /// @notice Disable the contract functionality
    /// @dev    This function reverts if:
    ///         - The caller does not have the admin role
    function shutdown() external onlyRole("admin") {
        locallyActive = false;
    }

    modifier onlyWhileActive() {
        if (!locallyActive) revert Inactive();
        _;
    }
}
