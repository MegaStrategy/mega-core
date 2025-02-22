// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.19;

import {Kernel, Policy, Keycode, toKeycode, Permissions} from "src/Kernel.sol";

// Modules
import {TRSRYv1} from "src/modules/TRSRY/TRSRY.v1.sol";
import {TOKENv1} from "src/modules/TOKEN/TOKEN.v1.sol";
import {ROLESv1, RolesConsumer} from "src/modules/ROLES/MegaRoles.sol";

// Policies
import {IIssuer} from "src/policies/interfaces/IIssuer.sol";

// Libraries
import {ERC20} from "@solmate-6.8.0/tokens/ERC20.sol";
import {Timestamp} from "@axis-core-1.0.1/lib/Timestamp.sol";
import {TransferHelper} from "src/lib/TransferHelper.sol";

// Option tokens
import {FixedStrikeOptionToken as oToken} from "src/lib/oTokens/FixedStrikeOptionToken.sol";
import {IFixedStrikeOptionTeller as oTeller} from "src/lib/oTokens/IFixedStrikeOptionTeller.sol";

// Vesting
import {ILinearVesting} from "@axis-core-1.0.1/interfaces/modules/derivatives/ILinearVesting.sol";
import {LinearVesting} from "@axis-core-1.0.1/modules/derivatives/LinearVesting.sol";

/// @title  Issuer
/// @notice Policy that manages issuance of the protocol token and options tokens
/// @dev    This policy is responsible for the following:
///         - Issuing options tokens to recipients
///         - Reclaiming expired options tokens from the teller
///
///         Recipients interact with the FixedStrikeOptionTeller to exercise their option tokens
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
    LinearVesting public vestingModule;

    /// @notice Whether an oToken was created by this contract
    mapping(address => bool) public createdBy;

    /// @notice The ID of the vesting token created for an oToken
    mapping(address => uint256) public optionTokenToVestingTokenId;

    /// @notice The ID of the vesting token created for an oToken
    mapping(address => address) public optionTokenToVestingToken;

    // ========= POLICY SETUP ========= //

    constructor(Kernel kernel_, address teller_, address vestingModule_) Policy(kernel_) {
        // Set the teller to create oTokens from
        teller = oTeller(teller_);

        // Set the vesting module
        vestingModule = LinearVesting(vestingModule_);

        // Enable by default
        locallyActive = true;
    }

    /// @inheritdoc Policy
    function configureDependencies() external override returns (Keycode[] memory dependencies) {
        dependencies = new Keycode[](3);
        dependencies[0] = toKeycode("TRSRY");
        dependencies[1] = toKeycode("TOKEN");
        dependencies[2] = toKeycode("ROLES");

        // Determine the address of the TOKEN module
        address tokenModule = getModuleAddress(dependencies[1]);

        // Changing the TOKEN module is not supported, otherwise option token holders will not be able to convert their tokens
        if (address(TOKEN) != address(0) && tokenModule != address(TOKEN)) {
            revert InvalidState();
        }

        TRSRY = TRSRYv1(getModuleAddress(dependencies[0]));
        TOKEN = TOKENv1(tokenModule);
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
    ///         - The policy is not locally active
    ///         - The vesting expiry is >= 1 week before the option token expiry
    ///         - Validation by the oToken teller fails
    ///
    ///         Note: the expiry timestamp is rounded down to the nearest day
    function createO(
        address quoteToken_,
        uint48 expiry_,
        uint256 convertiblePrice_,
        uint48 vestingStart_,
        uint48 vestingExpiry_
    ) external override onlyRole("admin") onlyWhileActive returns (address token) {
        // Create oToken on oTeller
        // Teller validates the inputs
        token = address(
            teller.deploy(
                ERC20(address(TOKEN)), // payoutToken_ = protocol token
                ERC20(quoteToken_), // quoteToken_ = quoteToken
                uint48(0), // eligible_ = immediately: TODO should we allow setting this?
                expiry_, // expiry_ = expiry
                address(this), // receiver_ = this (where proceeds and unexercised tokens are sent). Cleanup is handled by sweepToTreasury() and reclaimO().
                true, // call_ = true
                convertiblePrice_ // strikePrice_ = convertiblePrice
            )
        );

        // Mark the oToken as created by this contract
        createdBy[token] = true;

        // Create a vesting token if vesting parameters are provided
        address vestingToken;
        if (vestingStart_ != 0 && vestingExpiry_ != 0) {
            // Vesting expiry must be at least 1 week before option token expiry, with a buffer of 1 week
            if (vestingExpiry_ > expiry_ - 1 weeks) revert InvalidParam("vesting expiry");

            uint256 tokenId;
            (tokenId, vestingToken) = vestingModule.deploy(
                address(token),
                abi.encode(
                    ILinearVesting.VestingParams({start: vestingStart_, expiry: vestingExpiry_})
                ),
                true
            );

            // Set the vesting token ID
            optionTokenToVestingTokenId[token] = tokenId;

            // Set the vesting token
            optionTokenToVestingToken[token] = vestingToken;
        }

        // Emit event
        emit oTokenCreated(token, vestingToken);
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

        // Approve the teller to pull the newly minted TOKENs
        ERC20(address(TOKEN)).safeApprove(address(teller), amount_);

        // Mint the oToken from the teller
        teller.create(oToken(token_), amount_);

        // Vesting disabled
        if (optionTokenToVestingTokenId[token_] == 0) {
            // Send the oTokens to the recipient
            ERC20(token_).safeTransfer(to_, amount_);
        }
        // Vesting enabled
        else {
            // Approve the vesting module to pull the newly minted option tokens
            ERC20(token_).safeApprove(address(vestingModule), amount_);

            // Mint the vesting tokens to the recipient
            vestingModule.mint(to_, optionTokenToVestingTokenId[token_], amount_, true);
        }

        // Emit event
        emit oTokenIssued(token_, optionTokenToVestingToken[token_], to_, amount_);
    }

    /// @inheritdoc IIssuer
    /// @dev    This function reverts if:
    ///         - The caller does not have the manager role
    ///         - The policy is not locally active
    function reclaimO(
        address token_
    ) external override onlyRole("manager") onlyWhileActive {
        // Validate that the oToken was created by this contract
        if (!createdBy[token_]) revert InvalidParam("token");

        // Reclaim the oToken from the teller
        // This will revert if the oToken has not expired
        teller.reclaim(oToken(token_));

        // Get the after balances
        // This contract doesn't hold any funds, so the balances are the result of the reclaim
        uint256 protocolTokenAfter = TOKEN.balanceOf(address(this));

        // Burn the protocol tokens
        TOKEN.burn(protocolTokenAfter);

        // Transfer the quote tokens to the treasury
        // quoteToken.safeTransfer(address(TRSRY), quoteTokenAfter);

        // Emit event
        emit oTokenReclaimed(token_, protocolTokenAfter);
    }

    /// @inheritdoc IIssuer
    /// @dev    This function reverts if:
    ///         - The caller does not have the manager role
    ///         - The policy is not locally active
    function sweepToTreasury(
        address token_
    ) external onlyRole("manager") onlyWhileActive {
        uint256 tokenBalance = ERC20(token_).balanceOf(address(this));
        if (tokenBalance == 0) return;

        // Transfer the quote tokens to the treasury
        ERC20(token_).safeTransfer(address(TRSRY), tokenBalance);

        // Emit event
        emit SweptToTreasury(token_, tokenBalance);
    }

    /// @inheritdoc IIssuer
    function getUnderlyingToken() external view returns (address) {
        return address(TOKEN);
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

    /// @notice Set the vesting module
    /// @dev    This function reverts if:
    ///         - The caller does not have the admin role
    ///
    /// @param vestingModule_ The new vesting module
    function setVestingModule(
        address vestingModule_
    ) external onlyRole("admin") {
        vestingModule = LinearVesting(vestingModule_);
    }

    /// @notice Enable the contract functionality
    /// @dev    This function reverts if:
    ///         - The caller does not have the admin role
    ///         - The policy is already active
    function activate() external onlyRole("admin") {
        // Validate that the policy is not already active
        if (locallyActive) revert InvalidState();

        // Set the policy to active
        locallyActive = true;
    }

    /// @notice Disable the contract functionality
    /// @dev    This function reverts if:
    ///         - The caller does not have the emergency role
    ///         - The policy is already inactive
    function shutdown() external onlyRole("emergency") {
        // Validate that the policy is not already inactive
        if (!locallyActive) revert InvalidState();

        // Set the policy to inactive
        locallyActive = false;
    }

    modifier onlyWhileActive() {
        if (!locallyActive) revert Inactive();
        _;
    }
}
