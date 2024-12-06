// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.19;

import {Script, console2} from "@forge-std/Script.sol";
import {stdJson} from "@forge-std/StdJson.sol";
import {WithSalts} from "../salts/WithSalts.s.sol";
import {WithEnvironment} from "./WithEnvironment.s.sol";

import {Authority} from "solmate-6.8.0/auth/Auth.sol";
import {FixedStrikeOptionTeller} from "src/lib/oTokens/FixedStrikeOptionTeller.sol";

// solhint-disable-next-line no-global-import
import "src/Kernel.sol";
import {OlympusTreasury} from "src/modules/TRSRY/OlympusTreasury.sol";
import {OlympusRoles} from "src/modules/ROLES/OlympusRoles.sol";
import {MSTR} from "src/modules/TOKEN/MSTR.sol";

import {RolesAdmin} from "src/policies/RolesAdmin.sol";
import {TreasuryCustodian} from "src/policies/TreasuryCustodian.sol";
import {Emergency} from "src/policies/Emergency.sol";
import {Banker} from "src/policies/Banker.sol";
import {Issuer} from "src/policies/Issuer.sol";

// solhint-disable max-states-count
/// @notice Script to deploy the system
/// @dev    The address that this script is broadcast from must have write access to the contracts being configured
contract Deploy is Script, WithSalts, WithEnvironment {
    using stdJson for string;

    Kernel public kernel;

    // Deploy system storage
    mapping(string => bytes4) public selectorMap;
    mapping(string => bytes) public argsMap;
    string[] public deployments;

    // Post-deployment storage
    string[] public deploymentKeys;
    mapping(string => address) public deployedTo;

    function _loadEnv(
        string calldata chain_
    ) internal override {
        super._loadEnv(chain_);

        // Don't validate that the kernel address is not zero, in case it hasn't been deployed yet
        kernel = Kernel(_envAddress("mega.Kernel"));
    }

    function _setUp(string calldata chain_, string calldata deployFilePath_) internal {
        // Setup contract -> selector mappings
        selectorMap["OlympusTreasury"] = this._deployTreasury.selector;
        selectorMap["OlympusRoles"] = this._deployRoles.selector;
        selectorMap["Token"] = this._deployToken.selector;

        selectorMap["RolesAdmin"] = this._deployRolesAdmin.selector;
        selectorMap["TreasuryCustodian"] = this._deployTreasuryCustodian.selector;
        selectorMap["Emergency"] = this._deployEmergency.selector;
        selectorMap["Banker"] = this._deployBanker.selector;
        selectorMap["Issuer"] = this._deployIssuer.selector;
        selectorMap["FixedStrikeOptionTeller"] = this._deployFixedStrikeOptionTeller.selector;

        // Load env data
        _loadEnv(chain_);

        // Load deployment data
        string memory data = vm.readFile(deployFilePath_);

        // Parse deployment sequence and names
        bytes memory sequence = abi.decode(data.parseRaw(".sequence"), (bytes));
        uint256 len = sequence.length;
        console2.log("Contracts to be deployed:", len);

        if (len == 0) {
            return;
        } else if (len == 1) {
            // Only one deployment
            string memory name = abi.decode(data.parseRaw(".sequence[0].name"), (string));
            deployments.push(name);

            // Parse and store args if not kernel
            // Note: constructor args need to be provided in alphabetical order
            // due to changes with forge-std or a struct needs to be used
            if (keccak256(bytes(name)) != keccak256(bytes("Kernel"))) {
                argsMap[name] =
                    data.parseRaw(string.concat(".sequence[?(@.name == '", name, "')].args"));
            }
        } else {
            // More than one deployment
            string[] memory names = abi.decode(data.parseRaw(".sequence[*].name"), (string[]));
            for (uint256 i = 0; i < len; i++) {
                string memory name = names[i];
                deployments.push(name);

                // Parse and store args if not kernel
                // Note: constructor args need to be provided in alphabetical order
                // due to changes with forge-std or a struct needs to be used
                if (keccak256(bytes(name)) != keccak256(bytes("Kernel"))) {
                    argsMap[name] =
                        data.parseRaw(string.concat(".sequence[?(@.name == '", name, "')].args"));
                }
            }
        }
    }

    function envAddress(
        string memory key_
    ) internal view returns (address) {
        return env.readAddress(string.concat(".current.", chain, ".", key_));
    }

    function deploy(string calldata chain_, string calldata deployFilePath_) external {
        // Setup
        _setUp(chain_, deployFilePath_);

        // Check that deployments is not empty
        uint256 len = deployments.length;
        require(len > 0, "No deployments");

        // If kernel to be deployed, then it should be first (not included in contract -> selector mappings so it will error out if not first)
        bool deployKernel = keccak256(bytes(deployments[0])) == keccak256(bytes("Kernel"));
        if (deployKernel) {
            console2.log("Deploying Kernel");
            vm.broadcast();
            kernel = new Kernel();
            console2.log("Kernel deployed at:", address(kernel));
            console2.log("");

            // Store the deployed contract address for logging
            string memory deployKey = "mega.Kernel";
            deploymentKeys.push(deployKey);
            deployedTo[deployKey] = address(kernel);
        }

        // Iterate through deployments
        for (uint256 i = deployKernel ? 1 : 0; i < len; i++) {
            // Get deploy script selector and deploy args from contract name
            string memory name = deployments[i];
            bytes4 selector = selectorMap[name];
            bytes memory args = argsMap[name];

            // Call the deploy function for the contract
            console2.log("Deploying", name);
            (bool success, bytes memory data) =
                address(this).call(abi.encodeWithSelector(selector, args));
            require(success, string.concat("Failed to deploy ", deployments[i]));
            (address deployedAddress, string memory deployKey) = abi.decode(data, (address, string));
            console2.log("");

            // Store the deployed contract address for logging
            deploymentKeys.push(deployKey);
            deployedTo[deployKey] = deployedAddress;
        }

        // Save deployments to file
        _saveDeployment(chain_);
    }

    // ========== DEPLOYMENT FUNCTIONS ========== //

    // Module deployment functions
    function _deployTreasury(
        bytes memory
    ) public returns (address, string memory) {
        // No additional arguments for Treasury module

        // Deploy Treasury module
        vm.broadcast();
        OlympusTreasury TRSRY = new OlympusTreasury(kernel);
        console2.log("Treasury deployed at:", address(TRSRY));

        return (address(TRSRY), "mega.modules.OlympusTreasury");
    }

    function _deployRoles(
        bytes memory
    ) public returns (address, string memory) {
        // No additional arguments for Roles module

        // Deploy Roles module
        vm.broadcast();
        OlympusRoles ROLES = new OlympusRoles(kernel);
        console2.log("Roles deployed at:", address(ROLES));

        return (address(ROLES), "mega.modules.OlympusRoles");
    }

    function _deployToken(
        bytes memory args
    ) public returns (address, string memory) {
        (string memory name, string memory symbol) = abi.decode(args, (string, string));

        // Deploy Token module
        vm.broadcast();
        MSTR token = new MSTR(kernel, name, symbol);
        console2.log("Token deployed at:", address(token));

        return (address(token), "mega.modules.Token");
    }

    function _deployRolesAdmin(
        bytes memory
    ) public returns (address, string memory) {
        // No additional arguments for RolesAdmin policy

        // Deploy RolesAdmin policy
        vm.broadcast();
        RolesAdmin rolesAdmin = new RolesAdmin(kernel);
        console2.log("RolesAdmin deployed at:", address(rolesAdmin));

        return (address(rolesAdmin), "mega.policies.RolesAdmin");
    }

    function _deployTreasuryCustodian(
        bytes memory
    ) public returns (address, string memory) {
        // No additional arguments for TreasuryCustodian policy

        // Deploy TreasuryCustodian policy
        vm.broadcast();
        TreasuryCustodian treasuryCustodian = new TreasuryCustodian(kernel);
        console2.log("TreasuryCustodian deployed at:", address(treasuryCustodian));

        return (address(treasuryCustodian), "mega.policies.TreasuryCustodian");
    }

    function _deployEmergency(
        bytes memory
    ) public returns (address, string memory) {
        // No additional arguments for Emergency policy

        // Deploy Emergency policy
        vm.broadcast();
        Emergency emergency = new Emergency(kernel);
        console2.log("Emergency deployed at:", address(emergency));

        return (address(emergency), "mega.policies.Emergency");
    }

    function _deployBanker(
        bytes memory
    ) public returns (address, string memory) {
        // No additional arguments for Banker policy

        address auctionHouse = _getAddressNotZero("axis.BatchAuctionHouse");
        address cdtFactory = _getAddressNotZero("axis.derivatives.ConvertibleDebtTokenFactory");

        // Generate the salt
        // This is not a vanity address, so the salt and derived address doesn't really matter
        bytes32 salt_;
        {
            bytes memory args = abi.encode(kernel, auctionHouse, cdtFactory);

            bytes memory contractCode = type(Banker).creationCode;
            (string memory bytecodePath, bytes32 bytecodeHash) =
                _writeBytecode("Banker", contractCode, args);
            _setSalt(bytecodePath, "E7", "Banker", bytecodeHash);
            salt_ = _getSalt("Banker", type(Banker).creationCode, args);
            console2.log("Salt", vm.toString(salt_));
        }

        // Deploy Banker policy
        vm.broadcast();
        Banker banker = new Banker{salt: salt_}(kernel, auctionHouse, cdtFactory);
        console2.log("Banker deployed at:", address(banker));

        return (address(banker), "mega.policies.Banker");
    }

    function _deployIssuer(
        bytes memory
    ) public returns (address, string memory) {
        // No additional arguments for Issuer policy

        // Deploy Issuer policy
        vm.broadcast();
        Issuer issuer =
            new Issuer(kernel, _getAddressNotZero("axis.options.FixedStrikeOptionTeller"));
        console2.log("Issuer deployed at:", address(issuer));

        return (address(issuer), "mega.policies.Issuer");
    }

    function _deployFixedStrikeOptionTeller(
        bytes memory args_
    ) public returns (address, string memory) {
        (address guardian_, address authority_) = abi.decode(args_, (address, address));

        // Ensure the args are set
        require(guardian_ != address(0), "Guardian must be set");
        require(authority_ != address(0), "Authority must be set");

        // Deploy FixedStrikeOptionTeller
        vm.broadcast();
        FixedStrikeOptionTeller teller =
            new FixedStrikeOptionTeller(guardian_, Authority(authority_));
        console2.log("FixedStrikeOptionTeller deployed at:", address(teller));

        return (address(teller), "axis.options.FixedStrikeOptionTeller");
    }

    // ========== VERIFICATION ========== //

    function kernelInstallation(
        string calldata chain_
    ) external {
        _loadEnv(chain_);

        OlympusRoles ROLES = OlympusRoles(_getAddressNotZero("mega.modules.OlympusRoles"));
        OlympusTreasury TRSRY = OlympusTreasury(_getAddressNotZero("mega.modules.OlympusTreasury"));
        MSTR token = MSTR(_getAddressNotZero("mega.modules.Token"));
        RolesAdmin rolesAdmin = RolesAdmin(_getAddressNotZero("mega.policies.RolesAdmin"));
        TreasuryCustodian treasuryCustodian =
            TreasuryCustodian(_getAddressNotZero("mega.policies.TreasuryCustodian"));
        Emergency emergency = Emergency(_getAddressNotZero("mega.policies.Emergency"));
        Banker banker = Banker(_getAddressNotZero("mega.policies.Banker"));
        Issuer issuer = Issuer(_getAddressNotZero("mega.policies.Issuer"));

        vm.startBroadcast();

        console2.log("Installing modules");

        // Install modules
        kernel.executeAction(Actions.InstallModule, address(ROLES));
        kernel.executeAction(Actions.InstallModule, address(TRSRY));
        kernel.executeAction(Actions.InstallModule, address(token));

        console2.log("Activating policies");

        // Activate policies
        kernel.executeAction(Actions.ActivatePolicy, address(rolesAdmin));
        kernel.executeAction(Actions.ActivatePolicy, address(treasuryCustodian));
        kernel.executeAction(Actions.ActivatePolicy, address(emergency));
        kernel.executeAction(Actions.ActivatePolicy, address(banker));
        kernel.executeAction(Actions.ActivatePolicy, address(issuer));

        console2.log("Done");

        vm.stopBroadcast();
    }

    /// @dev Verifies that the environment variable addresses were set correctly following deployment
    /// @dev Should be called prior to pushAuth()
    function verifyKernelInstallation(
        string calldata chain_
    ) external {
        _loadEnv(chain_);

        OlympusTreasury TRSRY = OlympusTreasury(_getAddressNotZero("mega.modules.OlympusTreasury"));
        MSTR token = MSTR(_getAddressNotZero("mega.modules.Token"));
        OlympusRoles ROLES = OlympusRoles(_getAddressNotZero("mega.modules.OlympusRoles"));
        RolesAdmin rolesAdmin = RolesAdmin(_getAddressNotZero("mega.policies.RolesAdmin"));
        TreasuryCustodian treasuryCustodian =
            TreasuryCustodian(_getAddressNotZero("mega.policies.TreasuryCustodian"));
        Emergency emergency = Emergency(_getAddressNotZero("mega.policies.Emergency"));
        Banker banker = Banker(_getAddressNotZero("mega.policies.Banker"));
        Issuer issuer = Issuer(_getAddressNotZero("mega.policies.Issuer"));

        // Modules
        // TRSRY
        Module trsryModule = kernel.getModuleForKeycode(toKeycode("TRSRY"));
        Keycode trsryKeycode = kernel.getKeycodeForModule(TRSRY);
        require(trsryModule == TRSRY);
        require(fromKeycode(trsryKeycode) == "TRSRY");

        // TOKEN
        Module tokenModule = kernel.getModuleForKeycode(toKeycode("TOKEN"));
        Keycode tokenKeycode = kernel.getKeycodeForModule(token);
        require(tokenModule == token);
        require(fromKeycode(tokenKeycode) == "TOKEN");

        // ROLES
        Module rolesModule = kernel.getModuleForKeycode(toKeycode("ROLES"));
        Keycode rolesKeycode = kernel.getKeycodeForModule(ROLES);
        require(rolesModule == ROLES);
        require(fromKeycode(rolesKeycode) == "ROLES");

        // Policies
        require(kernel.isPolicyActive(rolesAdmin));
        require(kernel.isPolicyActive(treasuryCustodian));
        require(kernel.isPolicyActive(emergency));
        require(kernel.isPolicyActive(banker));
        require(kernel.isPolicyActive(issuer));
    }

    /// @dev Should be called by the deployer address after deployment
    function pushAuth(string calldata chain_, address governance_, address council_) external {
        _loadEnv(chain_);

        RolesAdmin rolesAdmin = RolesAdmin(_getAddressNotZero("mega.policies.RolesAdmin"));

        vm.startBroadcast();
        // Give the council the admin and manager roles
        rolesAdmin.grantRole("admin", council_);
        rolesAdmin.grantRole("manager", council_);

        // Push rolesAdmin to the council
        rolesAdmin.pushNewAdmin(council_);

        // Push kernel executor to governance
        kernel.executeAction(Actions.ChangeExecutor, governance_);

        vm.stopBroadcast();
    }

    function _saveDeployment(
        string memory chain_
    ) internal {
        // Create the deployments folder if it doesn't exist
        if (!vm.isDir("./deployments")) {
            console2.log("Creating deployments directory");

            string[] memory inputs = new string[](2);
            inputs[0] = "mkdir";
            inputs[1] = "deployments";

            vm.ffi(inputs);
        }

        // Create file path
        string memory file =
            string.concat("./deployments/", ".", chain_, "-", vm.toString(block.timestamp), ".json");
        console2.log("Writing deployments to", file);

        // Write deployment info to file in JSON format
        vm.writeLine(file, "{");

        // Iterate through the contracts that were deployed and write their addresses to the file
        uint256 len = deploymentKeys.length;
        // All except the last one
        for (uint256 i; i < len - 1; ++i) {
            string memory deployKey = deploymentKeys[i];
            vm.writeLine(
                file,
                string.concat("\"", deployKey, "\": \"", vm.toString(deployedTo[deployKey]), "\",")
            );
        }

        // Write the last deployment without a comma
        string memory lastDeployKey = deploymentKeys[len - 1];
        vm.writeLine(
            file,
            string.concat(
                "\"", lastDeployKey, "\": \"", vm.toString(deployedTo[lastDeployKey]), "\""
            )
        );
        vm.writeLine(file, "}");

        // Update the env.json file
        console2.log("Updating env.json");
        for (uint256 i; i < len; ++i) {
            string memory deployKey = deploymentKeys[i];

            string[] memory inputs = new string[](3);
            inputs[0] = "./script/deploy/write_deployment.sh";
            inputs[1] = string.concat("current.", chain_, ".", deployKey);
            inputs[2] = vm.toString(deployedTo[deployKey]);

            vm.ffi(inputs);
        }
        console2.log("Done");
    }

    // ========== HELPER FUNCTIONS ========== //

    function _getAddressNotZero(
        string memory key_
    ) internal view returns (address) {
        // Get from deployed addresses first
        address deployedAddress = deployedTo[key_];
        if (deployedAddress != address(0)) {
            console2.log(
                "    %s: %s (from deployment addresses)", key_, vm.toString(deployedAddress)
            );
            return deployedAddress;
        }

        return _envAddressNotZero(key_);
    }
}
