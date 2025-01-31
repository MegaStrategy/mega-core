// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import {ERC20} from "@openzeppelin-contracts-4.9.6/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin-contracts-4.9.6/token/ERC20/extensions/ERC20Permit.sol";
import {TOKENv1} from "src/modules/TOKEN/TOKEN.v1.sol";
import {Kernel, Module, Keycode, toKeycode} from "src/Kernel.sol";

/// @notice Implementation of the protocol token
/// @dev    This is a fork of the OlympusMinter, but modified to use the contract as the token instead of an external one
contract MegaToken is TOKENv1 {
    //============================================================================================//
    //                                      MODULE SETUP                                          //
    //============================================================================================//

    constructor(
        Kernel kernel_,
        string memory name_,
        string memory symbol_
    ) ERC20(name_, symbol_) ERC20Permit(name_) Module(kernel_) {
        active = true;
    }

    /// @inheritdoc Module
    function KEYCODE() public pure override returns (Keycode) {
        return toKeycode("TOKEN");
    }

    /// @inheritdoc Module
    function VERSION() external pure override returns (uint8 major, uint8 minor) {
        major = 1;
        minor = 0;
    }

    //============================================================================================//
    //                                       CORE FUNCTIONS                                       //
    //============================================================================================//

    /// @inheritdoc TOKENv1
    /// @dev        This function reverts if:
    ///             - The caller is not permissioned
    ///             - The token is not active
    ///             - The amount is zero
    ///             - The caller does not have enough mint approval
    function mint(address to_, uint256 amount_) external override permissioned onlyWhileActive {
        // Validate that the amount is not zero
        if (amount_ == 0) revert TOKEN_ZeroAmount();

        // Validate that the caller has enough mint approval
        uint256 approval = mintApproval[msg.sender];
        if (approval < amount_) revert TOKEN_NotApproved();

        // Decrease the mint approval
        unchecked {
            mintApproval[msg.sender] = approval - amount_;
        }

        // Mint the tokens
        _mint(to_, amount_);

        // Emit the event
        emit Mint(msg.sender, to_, amount_);
    }

    /// @inheritdoc TOKENv1
    /// @dev        This function reverts if:
    ///             - The caller is not permissioned
    ///             - The token is not active
    ///             - The amount is zero
    ///             - The caller does not have enough spending allowance from the owner
    function burnFrom(address from_, uint256 amount_) external override onlyWhileActive {
        // Validate that the amount is not zero
        if (amount_ == 0) revert TOKEN_ZeroAmount();

        // Spend the allowance of the caller
        _spendAllowance(from_, msg.sender, amount_);

        // Burn the tokens from the address
        _burn(from_, amount_);

        emit Burn(msg.sender, from_, amount_);
    }

    /// @inheritdoc TOKENv1
    /// @dev        This function reverts if:
    ///             - The token is not active
    ///             - The amount is zero
    function burn(
        uint256 amount_
    ) external override onlyWhileActive {
        if (amount_ == 0) revert TOKEN_ZeroAmount();

        // Burn the tokens from the sender
        _burn(msg.sender, amount_);

        emit Burn(msg.sender, msg.sender, amount_);
    }

    /// @inheritdoc TOKENv1
    function increaseMintApproval(
        address policy_,
        uint256 amount_
    ) external override permissioned {
        uint256 approval = mintApproval[policy_];

        uint256 newAmount =
            type(uint256).max - approval <= amount_ ? type(uint256).max : approval + amount_;
        mintApproval[policy_] = newAmount;

        emit IncreaseMintApproval(policy_, newAmount);
    }

    /// @inheritdoc TOKENv1
    function decreaseMintApproval(
        address policy_,
        uint256 amount_
    ) external override permissioned {
        uint256 approval = mintApproval[policy_];

        uint256 newAmount = approval <= amount_ ? 0 : approval - amount_;
        mintApproval[policy_] = newAmount;

        emit DecreaseMintApproval(policy_, newAmount);
    }

    /// @inheritdoc TOKENv1
    function deactivate() external override permissioned {
        active = false;
    }

    /// @inheritdoc TOKENv1
    function activate() external override permissioned {
        active = true;
    }
}
