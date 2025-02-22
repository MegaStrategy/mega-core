/// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import {Test} from "@forge-std/Test.sol";
import {stdJson} from "@forge-std/StdJson.sol";

contract WithSalts is Test {
    using stdJson for string;

    string internal constant _SALTS_PATH = "./script/salts/salts.json";
    string internal _saltJson;

    /// @notice Gets the salt for a given key
    /// @dev    Test salts are read from underneath the ".test" prefix.
    ///
    ///         If the key is not found, the function will return `bytes32(0)`.
    ///
    /// @param  contractName_   The contract to get the salt for
    /// @param  contractCode_   The creation code of the contract
    /// @param  args_           The abi-encoded constructor arguments to the contract
    /// @return                 The salt for the given key
    function _getTestSalt(
        string memory contractName_,
        bytes memory contractCode_,
        bytes memory args_
    ) internal returns (bytes32) {
        // Load salt file if needed
        if (bytes(_saltJson).length == 0) {
            _saltJson = vm.readFile(_SALTS_PATH);
        }

        // Generate the bytecode hash
        bytes memory bytecode = abi.encodePacked(contractCode_, args_);
        bytes32 bytecodeHash = keccak256(bytecode);

        bytes32 salt = bytes32(
            vm.parseJson(
                _saltJson, string.concat(".Test_", contractName_, ".", vm.toString(bytecodeHash))
            )
        );

        return salt;
    }

    function _computeAddress(
        address deployer_,
        bytes32 salt_,
        bytes32 bytecodeHash_
    ) internal pure returns (address) {
        return address(
            uint160(
                uint256(keccak256(abi.encodePacked(bytes1(0xff), deployer_, salt_, bytecodeHash_)))
            )
        );
    }
}
