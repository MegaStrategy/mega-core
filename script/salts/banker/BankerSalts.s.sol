// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import {Script} from "@forge-std/Script.sol";
import {WithSalts} from "../WithSalts.s.sol";
import {WithEnvironment} from "../../deploy/WithEnvironment.s.sol";

import {Banker} from "../../../src/policies/Banker.sol";

contract BankerSalts is Script, WithSalts, WithEnvironment {
    address internal _envKernel;
    address internal _envAuctionHouse;

    function _setUp(
        string calldata chain_
    ) internal {
        _loadEnv(chain_);
        _createBytecodeDirectory();

        // Cache required variables
        _envKernel = _envAddress("mega.Kernel");
        _envAuctionHouse = _envAddress("axis.BatchAuctionHouse");
    }

    function generate(
        string calldata chain_
    ) public {
        _setUp(chain_);

        bytes memory args = abi.encode(_envKernel, _envAuctionHouse);

        bytes memory contractCode = type(Banker).creationCode;
        (string memory bytecodePath, bytes32 bytecodeHash) =
            _writeBytecode("Banker", contractCode, args);
        _setSalt(bytecodePath, "E7", "Banker", bytecodeHash);
    }
}
