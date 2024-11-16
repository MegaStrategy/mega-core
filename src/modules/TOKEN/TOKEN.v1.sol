// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import "src/Kernel.sol";
import {
    ERC20Votes,
    ERC20Permit,
    ERC20
} from "@openzeppelin-contracts-4.9.6/token/ERC20/extensions/ERC20Votes.sol";

/// @notice Token for the overall system
abstract contract TOKENv1 is ERC20Votes, Module {
    // =========  EVENTS ========= //

    event IncreaseMintApproval(address indexed policy_, uint256 newAmount_);
    event DecreaseMintApproval(address indexed policy_, uint256 newAmount_);
    event Mint(address indexed policy_, address indexed to_, uint256 amount_);
    event Burn(address indexed policy_, address indexed from_, uint256 amount_);

    // ========= ERRORS ========= //

    error TOKEN_NotApproved();
    error TOKEN_ZeroAmount();
    error TOKEN_NotActive();

    // =========  STATE ========= //

    /// @notice Status of the minter. If false, minting and burning TOKEN is disabled.
    bool public active;

    /// @notice Mapping of who is approved for minting.
    /// @dev    minter -> amount. Infinite approval is max(uint256).
    mapping(address => uint256) public mintApproval;

    // =========  FUNCTIONS ========= //

    modifier onlyWhileActive() {
        if (!active) revert TOKEN_NotActive();
        _;
    }

    /// @notice Mint to an address.
    function mint(address to_, uint256 amount_) external virtual;

    /// @notice Burn tokens from sender.
    function burn(
        uint256 amount_
    ) external virtual;

    /// @notice Burn from an address. Must have approval.
    function burnFrom(address from_, uint256 amount_) external virtual;

    /// @notice Increase approval for specific withdrawer addresses
    /// @dev    Policies must explicity request how much they want approved before withdrawing.
    function increaseMintApproval(address policy_, uint256 amount_) external virtual;

    /// @notice Decrease approval for specific withdrawer addresses
    function decreaseMintApproval(address policy_, uint256 amount_) external virtual;

    /// @notice Emergency shutdown of minting and burning.
    function deactivate() external virtual;

    /// @notice Re-activate minting and burning after shutdown.
    function activate() external virtual;
}
