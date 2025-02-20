// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import {Script} from "@forge-std/Script.sol";
import {console2} from "@forge-std/console2.sol";
import {WithSalts} from "../WithSalts.s.sol";
import {WithEnvironment} from "../../WithEnvironment.s.sol";

import {Kernel} from "../../../src/Kernel.sol";
import {Banker} from "../../../src/policies/Banker.sol";

contract BankerSalts is Script, WithSalts, WithEnvironment {
    address internal _envKernel;
    address internal _envAuctionHouse;
    address public constant CREATE2_DEPLOYER = address(0x4e59b44847b379578588920cA78FbF26c0B4956C);

    function _setUp(
        string calldata chain_
    ) internal {
        _loadEnv(chain_);
        _createBytecodeDirectory();

        // Cache required variables
        _envKernel = _envAddress("mega.Kernel");
        _envAuctionHouse = _envAddress("axis.BatchAuctionHouse");
    }

    function generateBankerSalt(
        string calldata chain_
    ) public {
        _setUp(chain_);
        // NOTE: this is not really needed, as the deploy script mines a salt for the Banker

        bytes memory args = abi.encode(_envKernel, _envAuctionHouse);
        bytes memory contractCode = type(Banker).creationCode;
        (string memory bytecodePath, bytes32 bytecodeHash) =
            _writeBytecode("Banker", contractCode, args);
        _setSalt(bytecodePath, "E7", "Banker", bytecodeHash);
        bytes32 salt = _getSalt("Banker", contractCode, args);

        // Do a mock deployment and display the expected address
        vm.startBroadcast(CREATE2_DEPLOYER);
        Banker banker = new Banker{salt: salt}(Kernel(_envKernel), _envAuctionHouse);
        console2.log("Expected address:", address(banker));
        vm.stopBroadcast();
    }
    }
}
