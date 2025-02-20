// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import {Script} from "@forge-std/Script.sol";
import {console2} from "@forge-std/console2.sol";
import {WithSalts} from "../WithSalts.s.sol";
import {WithEnvironment} from "../../WithEnvironment.s.sol";

import {Kernel} from "../../../src/Kernel.sol";
import {Banker} from "../../../src/policies/Banker.sol";
import {ConvertibleDebtToken} from "../../../src/lib/ConvertibleDebtToken.sol";

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

    function generateDebtTokenSalt(
        string calldata chain_,
        string calldata auctionFilePath_,
        string calldata prefix_
    ) public {
        _setUp(chain_);

        console2.log("Loading auction data from ", auctionFilePath_);
        string memory auctionData = vm.readFile(auctionFilePath_);

        address underlying = address(_envAddressNotZero("external.tokens.USDC"));
        uint256 conversionPrice = vm.parseJsonUint(auctionData, ".auctionParams.conversionPrice");
        uint48 maturity = uint48(
            block.timestamp + uint48(vm.parseJsonUint(auctionData, ".auctionParams.maturity"))
        );

        // Get the name and symbol for the debt token
        address banker = _envAddressNotZero("mega.policies.Banker");
        (string memory name, string memory symbol) =
            Banker(banker).getNextDebtTokenNameAndSymbol(underlying);

        // Generate the salt
        bytes32 salt;
        {
            bytes memory args = abi.encode(
                name,
                symbol,
                underlying,
                address(_envAddressNotZero("mega.tokens.MGST")),
                maturity,
                conversionPrice,
                banker
            );
            bytes memory contractCode = type(ConvertibleDebtToken).creationCode;
            (string memory bytecodePath, bytes32 bytecodeHash) =
                _writeBytecode("ConvertibleDebtToken", contractCode, args);
            _setSalt(bytecodePath, prefix_, "ConvertibleDebtToken", bytecodeHash);
            salt = _getSalt("ConvertibleDebtToken", contractCode, args);
        }

        // Do a mock deployment and display the expected address
        vm.startBroadcast(CREATE2_DEPLOYER);
        ConvertibleDebtToken debtToken = new ConvertibleDebtToken{salt: salt}(
            name,
            symbol,
            underlying,
            address(_envAddressNotZero("mega.tokens.MGST")),
            maturity,
            conversionPrice,
            banker
        );
        console2.log("Expected address:", address(debtToken));
        vm.stopBroadcast();
    }
}
