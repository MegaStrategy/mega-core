// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.19;

import {Script} from "@forge-std/Script.sol";
import {VmSafe} from "@forge-std/Vm.sol";
import {console2} from "@forge-std/console2.sol";

abstract contract WithFfi is Script {
    function _ffi(
        string[] memory inputs_
    ) internal returns (bytes memory res) {
        VmSafe.FfiResult memory result = vm.tryFfi(inputs_);
        if (result.exitCode != 0) {
            console2.log("FFI call failed");
            console2.log("stdError:", string(result.stderr));

            // solhint-disable-next-line custom-errors
            revert("FFI call failed");
        }

        return result.stdout;
    }
}
