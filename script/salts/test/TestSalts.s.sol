/// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

// Scripting libraries
import {Script} from "@forge-std/Script.sol";
import {WithEnvironment} from "../../WithEnvironment.s.sol";
import {WithSalts} from "../WithSalts.s.sol";

// Contracts
import {Banker} from "../../../src/policies/Banker.sol";

contract TestSalts is Script, WithEnvironment, WithSalts {
    string public constant BANKER = "Banker";
    address public constant AUCTION_HOUSE = address(0xAA);
    address public constant KERNEL = address(0xBB);
    address public constant CONVERTIBLE_DEBT_TOKEN_FACTORY = address(0x00000000000000000000000000000000000000ff);
    address public constant CREATE2_DEPLOYER = address(0x4e59b44847b379578588920cA78FbF26c0B4956C);

    function _setUp(
        string calldata chain_
    ) internal {
        _loadEnv(chain_);
        _createBytecodeDirectory();
    }

    function generate(string calldata chain_, string calldata saltKey_) public {
        _setUp(chain_);

        // For the given salt key, call the appropriate selector
        // e.g. a salt key named MockCallback would require the following function: generateMockCallback()
        bytes4 selector = bytes4(keccak256(bytes(string.concat("generate", saltKey_, "()"))));

        // Call the generate function for the salt key
        (bool success,) = address(this).call(abi.encodeWithSelector(selector));
        require(success, string.concat("Failed to generate ", saltKey_));
    }

    function generateBanker() public {
        // 11100111 = 0xE7
        bytes memory args = abi.encode(KERNEL, AUCTION_HOUSE, CONVERTIBLE_DEBT_TOKEN_FACTORY);
        bytes memory contractCode = type(Banker).creationCode;
        (string memory bytecodePath, bytes32 bytecodeHash) =
            _writeBytecode(BANKER, contractCode, args);
        _setTestSalt(bytecodePath, "E7", BANKER, bytecodeHash);
    }
}
