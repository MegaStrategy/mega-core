// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.19;

// solhint-disable-next-line no-global-import
import "src/Kernel.sol";
import {ROLESv1, RolesConsumer} from "src/modules/ROLES/MegaRoles.sol";
import {TRSRYv1} from "src/modules/TRSRY/TRSRY.v1.sol";
import {TOKENv1} from "src/modules/TOKEN/TOKEN.v1.sol";

/// @notice Contract to allow emergency shutdown of minting and treasury withdrawals
/// @dev    All functions are only callable by the "emergency" role
contract Emergency is Policy, RolesConsumer {
    // =========  EVENTS ========= //

    event Status(bool treasury_, bool minter_);

    // =========  STATE ========= //

    TRSRYv1 public TRSRY;
    TOKENv1 public TOKEN;

    //============================================================================================//
    //                                      POLICY SETUP                                          //
    //============================================================================================//

    constructor(
        Kernel kernel_
    ) Policy(kernel_) {}

    /// @inheritdoc Policy
    function configureDependencies() external override returns (Keycode[] memory dependencies) {
        dependencies = new Keycode[](3);
        dependencies[0] = toKeycode("TRSRY");
        dependencies[1] = toKeycode("TOKEN");
        dependencies[2] = toKeycode("ROLES");

        TRSRY = TRSRYv1(getModuleAddress(dependencies[0]));
        TOKEN = TOKENv1(getModuleAddress(dependencies[1]));
        ROLES = ROLESv1(getModuleAddress(dependencies[2]));

        (uint8 TRSRY_MAJOR,) = TRSRY.VERSION();
        (uint8 TOKEN_MAJOR,) = TOKEN.VERSION();
        (uint8 ROLES_MAJOR,) = ROLES.VERSION();

        // Ensure Modules are using the expected major version.
        // Modules should be sorted in alphabetical order.
        bytes memory expected = abi.encode([1, 1, 1]);
        if (TOKEN_MAJOR != 1 || ROLES_MAJOR != 1 || TRSRY_MAJOR != 1) {
            revert Policy_WrongModuleVersion(expected);
        }
    }

    /// @inheritdoc Policy
    function requestPermissions() external view override returns (Permissions[] memory requests) {
        Keycode TRSRY_KEYCODE = TRSRY.KEYCODE();
        Keycode TOKEN_KEYCODE = TOKEN.KEYCODE();

        requests = new Permissions[](4);
        requests[0] = Permissions(TRSRY_KEYCODE, TRSRY.deactivate.selector);
        requests[1] = Permissions(TRSRY_KEYCODE, TRSRY.activate.selector);
        requests[2] = Permissions(TOKEN_KEYCODE, TOKEN.deactivate.selector);
        requests[3] = Permissions(TOKEN_KEYCODE, TOKEN.activate.selector);
    }

    //============================================================================================//
    //                                       CORE FUNCTIONS                                       //
    //============================================================================================//

    /// @notice Emergency shutdown of treasury withdrawals and minting
    function shutdown() external onlyRole("emergency") {
        TRSRY.deactivate();
        TOKEN.deactivate();
        _reportStatus();
    }

    /// @notice Emergency shutdown of treasury withdrawals
    function shutdownWithdrawals() external onlyRole("emergency") {
        TRSRY.deactivate();
        _reportStatus();
    }

    /// @notice Emergency shutdown of minting
    function shutdownMinting() external onlyRole("emergency") {
        TOKEN.deactivate();
        _reportStatus();
    }

    /// @notice Restart treasury withdrawals and minting after shutdown
    function restart() external onlyRole("emergency") {
        TRSRY.activate();
        TOKEN.activate();
        _reportStatus();
    }

    /// @notice Restart treasury withdrawals after shutdown
    function restartWithdrawals() external onlyRole("emergency") {
        TRSRY.activate();
        _reportStatus();
    }

    /// @notice Restart minting after shutdown
    function restartMinting() external onlyRole("emergency") {
        TOKEN.activate();
        _reportStatus();
    }

    /// @notice Emit an event to show the current status of TRSRY and TOKEN
    function _reportStatus() internal {
        emit Status(TRSRY.active(), TOKEN.active());
    }
}
