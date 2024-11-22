// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.19;

import "src/Kernel.sol";

// Modules
import {TRSRYv1} from "src/modules/TRSRY/TRSRY.v1.sol";
import {TOKENv1} from "src/modules/TOKEN/TOKEN.v1.sol";
import {ROLESv1, RolesConsumer} from "src/modules/ROLES/OlympusRoles.sol";

import {ERC20} from "solmate-6.8.0/tokens/ERC20.sol";
import {Timestamp} from "axis-core-1.0.1/lib/Timestamp.sol";
import {TransferHelper} from "src/lib/TransferHelper.sol";

import {FixedStrikeOptionToken as oToken} from "src/lib/oTokens/FixedStrikeOptionToken.sol";
import {IFixedStrikeOptionTeller as oTeller} from "src/lib/oTokens/IFixedStrikeOptionTeller.sol";

/// @title  Issuer
/// @notice Policy that manages issuance of MSTR and options tokens
contract Issuer is Policy, RolesConsumer {
    using Timestamp for uint48;
    using TransferHelper for ERC20;

    // ========== ERRORS ========== //

    error InvalidParam(string name);

    // ========== EVENTS ========== //

    event oTokenCreated(address indexed oToken);

    // ========== STATE ========== //

    // Modules
    TRSRYv1 internal TRSRY;
    TOKENv1 internal TOKEN;
    uint8 internal _tokenDecimals;

    // Local state
    bool public active;
    oTeller public teller;

    /// @notice Whether an oToken was created by this contract
    mapping(address => bool) public createdBy;

    // ========= POLICY SETUP ========= //

    constructor(Kernel kernel_, address teller_) Policy(kernel_) {
        // Set the teller to create oTokens from
        teller = oTeller(teller_);
    }

    /// @inheritdoc Policy
    function configureDependencies() external override returns (Keycode[] memory dependencies) {
        dependencies = new Keycode[](2);
        dependencies[0] = toKeycode("TRSRY");
        dependencies[1] = toKeycode("TOKEN");
        dependencies[2] = toKeycode("ROLES");

        TRSRY = TRSRYv1(getModuleAddress(dependencies[0]));
        TOKEN = TOKENv1(getModuleAddress(dependencies[1]));
        ROLES = ROLESv1(getModuleAddress(dependencies[2]));

        _tokenDecimals = TOKEN.decimals();
    }

    /// @inheritdoc Policy
    function requestPermissions()
        external
        view
        override
        returns (Permissions[] memory permissions)
    {
        Keycode TOKEN_KEYCODE = TOKEN.KEYCODE();

        permissions = new Permissions[](3);
        permissions[0] = Permissions(TOKEN_KEYCODE, TOKENv1.mint.selector);
        permissions[1] = Permissions(TOKEN_KEYCODE, TOKENv1.increaseMintApproval.selector);
        permissions[2] = Permissions(TOKEN_KEYCODE, TOKENv1.decreaseMintApproval.selector);
    }

    // ========= MINT ========= //

    /// @notice Mint MSTR to an address
    /// @param to_ Address to mint to
    /// @param amount_ Amount to mint
    function mint(address to_, uint256 amount_) external onlyRole("admin") {
        // Increase mint allowance by provided amount
        TOKEN.increaseMintApproval(address(this), amount_);

        // Mint the MSTR
        TOKEN.mint(to_, amount_);
    }

    // ========== oTokens ========= //

    function createO(
        address quoteToken_,
        uint48 expiry_,
        uint256 convertiblePrice_
    ) external onlyRole("admin") returns (address token) {
        // Create oToken on oTeller
        // Teller validates the inputs
        token = address(
            teller.deploy(
                address(TOKEN), // payoutToken_ = MSTR
                quoteToken_, // quoteToken_ = quoteToken
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

    function issueO(address token_, address to_, uint256 amount_) external onlyRole("admin") {
        // Validate that the oToken was created by this contract
        if (!createdBy[token_]) revert InvalidParam("token");

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
    }

    function setTeller(
        address teller_
    ) external onlyRole("admin") {
        teller = oTeller(teller_);
    }
}
