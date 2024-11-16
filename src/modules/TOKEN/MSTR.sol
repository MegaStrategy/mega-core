// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import "src/modules/TOKEN/TOKEN.v1.sol";
import "src/Kernel.sol";

/// @notice Token implementation for the system
/// @dev This is a fork of the OlympusMinter, but modified to use the contract as the token instead of an external one
contract MSTR is TOKENv1 {
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
    function mint(address to_, uint256 amount_) external override permissioned onlyWhileActive {
        if (amount_ == 0) revert TOKEN_ZeroAmount();

        uint256 approval = mintApproval[msg.sender];
        if (approval < amount_) revert TOKEN_NotApproved();

        unchecked {
            mintApproval[msg.sender] = approval - amount_;
        }

        _mint(to_, amount_);

        emit Mint(msg.sender, to_, amount_);
    }

    /// @inheritdoc TOKENv1
    function burnFrom(
        address from_,
        uint256 amount_
    ) external override permissioned onlyWhileActive {
        if (amount_ == 0) revert TOKEN_ZeroAmount();

        // Spend the allowance of the caller
        _spendAllowance(from_, msg.sender, amount_);

        // Burn the tokens from the address
        _burn(from_, amount_);

        emit Burn(msg.sender, from_, amount_);
    }

    /// @inheritdoc TOKENv1
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
