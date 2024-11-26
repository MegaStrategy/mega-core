// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.19;

import {Script, console2} from "@forge-std/Script.sol";
import {stdJson} from "@forge-std/StdJson.sol";
import {ERC20} from "solmate-6.8.0/tokens/ERC20.sol";
import {WithSalts} from "../salts/WithSalts.s.sol";

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
contract Deploy is Script, WithSalts {
    using stdJson for string;

    Kernel public kernel;

    // Modules
    OlympusTreasury public TRSRY;
    OlympusRoles public ROLES;
    MSTR public TOKEN;

    // Policies
    RolesAdmin public rolesAdmin;
    TreasuryCustodian public treasuryCustodian;
    Emergency public emergency;
    Banker public banker;
    Issuer public issuer;

    // Construction variables

    // Token addresses
    ERC20 public weth;
    ERC20 public usdc;

    // External contracts
    address public auctionHouse;
    address public cdtFactory;
    address public oTeller;

    // Deploy system storage
    string public chain;
    string public env;
    mapping(string => bytes4) public selectorMap;
    mapping(string => bytes) public argsMap;
    string[] public deployments;
    mapping(string => address) public deployedTo;

    function _load(
        string calldata chain_
    ) internal {
        chain = chain_;

        // Load environment addresses
        env = vm.readFile("./script/env.json");

        // Non-bophades contracts
        weth = ERC20(envAddress("external.tokens.WETH"));
        usdc = ERC20(envAddress("external.tokens.USDC"));

        // Bophades contracts
        kernel = Kernel(envAddress("mega.Kernel"));
        TRSRY = OlympusTreasury(envAddress("mega.modules.OlympusTreasury"));
        TOKEN = MSTR(envAddress("mega.modules.MSTR"));
        ROLES = OlympusRoles(envAddress("mega.modules.OlympusRoles"));

        rolesAdmin = RolesAdmin(envAddress("mega.policies.RolesAdmin"));
        treasuryCustodian = TreasuryCustodian(envAddress("mega.policies.TreasuryCustodian"));
        emergency = Emergency(envAddress("mega.policies.Emergency"));
        banker = Banker(envAddress("mega.policies.Banker"));
        issuer = Issuer(envAddress("mega.policies.Issuer"));

        // External contracts
        auctionHouse = envAddress("axis.BatchAuctionHouse");
        cdtFactory = envAddress("axis.derivatives.ConvertibleDebtTokenFactory");
        oTeller = envAddress("axis.options.FixedStrikeOptionTeller");
    }

    function _setUp(string calldata chain_, string calldata deployFilePath_) internal {
        // Setup contract -> selector mappings
        selectorMap["OlympusTreasury"] = this._deployTreasury.selector;
        selectorMap["OlympusRoles"] = this._deployRoles.selector;
        selectorMap["MSTR"] = this._deployToken.selector;

        selectorMap["RolesAdmin"] = this._deployRolesAdmin.selector;
        selectorMap["TreasuryCustodian"] = this._deployTreasuryCustodian.selector;
        selectorMap["Emergency"] = this._deployEmergency.selector;
        selectorMap["Banker"] = this._deployBanker.selector;
        selectorMap["Issuer"] = this._deployIssuer.selector;

        // Load env data
        _load(chain_);

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
            console2.log("");

            // Store the deployed contract address for logging
            deployedTo[name] = abi.decode(data, (address));
        }

        // TODO make deployment addresses available to subsequent deployments

        // Save deployments to file
        _saveDeployment(chain_);
    }

    // ========== DEPLOYMENT FUNCTIONS ========== //

    // Module deployment functions
    function _deployTreasury(
        bytes memory
    ) public returns (address) {
        // No additional arguments for Treasury module

        // Deploy Treasury module
        vm.broadcast();
        TRSRY = new OlympusTreasury(kernel);
        console2.log("Treasury deployed at:", address(TRSRY));

        return address(TRSRY);
    }

    function _deployRoles(
        bytes memory
    ) public returns (address) {
        // No additional arguments for Roles module

        // Deploy Roles module
        vm.broadcast();
        ROLES = new OlympusRoles(kernel);
        console2.log("Roles deployed at:", address(ROLES));

        return address(ROLES);
    }

    function _deployToken(
        bytes memory args
    ) public returns (address) {
        (string memory name, string memory symbol) = abi.decode(args, (string, string));

        // Deploy Token module
        vm.broadcast();
        TOKEN = new MSTR(kernel, name, symbol);
        console2.log("Token deployed at:", address(TOKEN));

        return address(TOKEN);
    }

    function _deployRolesAdmin(
        bytes memory
    ) public returns (address) {
        // No additional arguments for RolesAdmin policy

        // Deploy RolesAdmin policy
        vm.broadcast();
        rolesAdmin = new RolesAdmin(kernel);
        console2.log("RolesAdmin deployed at:", address(rolesAdmin));

        return address(rolesAdmin);
    }

    function _deployTreasuryCustodian(
        bytes memory
    ) public returns (address) {
        // No additional arguments for TreasuryCustodian policy

        // Deploy TreasuryCustodian policy
        vm.broadcast();
        treasuryCustodian = new TreasuryCustodian(kernel);
        console2.log("TreasuryCustodian deployed at:", address(treasuryCustodian));

        return address(treasuryCustodian);
    }

    function _deployEmergency(
        bytes memory
    ) public returns (address) {
        // No additional arguments for Emergency policy

        // Deploy Emergency policy
        vm.broadcast();
        emergency = new Emergency(kernel);
        console2.log("Emergency deployed at:", address(emergency));

        return address(emergency);
    }

    function _deployBanker(
        bytes memory
    ) public returns (address) {
        // No additional arguments for Banker policy

        // TODO consider generating the salt here

        // Get the salt
        bytes32 salt_ = _getSalt(
            "Banker", type(Banker).creationCode, abi.encode(kernel, auctionHouse, cdtFactory)
        );
        console2.log("Salt", vm.toString(salt_));

        // Deploy Banker policy
        vm.broadcast();
        banker = new Banker{salt: salt_}(kernel, auctionHouse, cdtFactory);
        console2.log("Banker deployed at:", address(banker));

        return address(banker);
    }

    function _deployIssuer(
        bytes memory
    ) public returns (address) {
        // No additional arguments for Issuer policy

        // Deploy Issuer policy
        vm.broadcast();
        issuer = new Issuer(kernel, oTeller);
        console2.log("Issuer deployed at:", address(issuer));

        return address(issuer);
    }

    // ========== VERIFICATION ========== //

    function kernelInstallation(
        string calldata chain_
    ) external {
        _load(chain_);

        vm.startBroadcast();

        // Install modules
        kernel.executeAction(Actions.InstallModule, address(ROLES));
        kernel.executeAction(Actions.InstallModule, address(TRSRY));
        kernel.executeAction(Actions.InstallModule, address(TOKEN));

        // Activate policies
        kernel.executeAction(Actions.ActivatePolicy, address(rolesAdmin));
        kernel.executeAction(Actions.ActivatePolicy, address(treasuryCustodian));
        kernel.executeAction(Actions.ActivatePolicy, address(emergency));
        kernel.executeAction(Actions.ActivatePolicy, address(banker));
        kernel.executeAction(Actions.ActivatePolicy, address(issuer));

        vm.stopBroadcast();
    }

    /// @dev Verifies that the environment variable addresses were set correctly following deployment
    /// @dev Should be called prior to pushAuth()
    function verifyKernelInstallation(
        string calldata chain_
    ) external {
        _load(chain_);

        // Modules
        // TRSRY
        Module trsryModule = kernel.getModuleForKeycode(toKeycode("TRSRY"));
        Keycode trsryKeycode = kernel.getKeycodeForModule(TRSRY);
        require(trsryModule == TRSRY);
        require(fromKeycode(trsryKeycode) == "TRSRY");

        // TOKEN
        Module tokenModule = kernel.getModuleForKeycode(toKeycode("TOKEN"));
        Keycode tokenKeycode = kernel.getKeycodeForModule(TOKEN);
        require(tokenModule == TOKEN);
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
        _load(chain_);

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
        uint256 len = deployments.length;
        // All except the last one
        for (uint256 i; i < len - 1; ++i) {
            vm.writeLine(
                file,
                string.concat(
                    "\"", deployments[i], "\": \"", vm.toString(deployedTo[deployments[i]]), "\","
                )
            );
        }

        // Write the last deployment without a comma
        vm.writeLine(
            file,
            string.concat(
                "\"",
                deployments[len - 1],
                "\": \"",
                vm.toString(deployedTo[deployments[len - 1]]),
                "\""
            )
        );
        vm.writeLine(file, "}");

        // Update the env.json file
        console2.log("Updating env.json");
        for (uint256 i; i < len; ++i) {
            string[] memory inputs = new string[](3);
            inputs[0] = "./script/deploy/write_deployment.sh";
            inputs[1] = string.concat("current.", chain_, ".", deployments[i]);
            inputs[2] = vm.toString(deployedTo[deployments[i]]);

            vm.ffi(inputs);
        }
        console2.log("Done");
    }
}
