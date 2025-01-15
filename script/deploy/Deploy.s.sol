// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.19;

import {Script, console2} from "@forge-std/Script.sol";
import {stdJson} from "@forge-std/StdJson.sol";
import {WithSalts} from "../salts/WithSalts.s.sol";
import {WithEnvironment} from "./WithEnvironment.s.sol";

import {Authority} from "solmate-6.8.0/auth/Auth.sol";
import {FixedStrikeOptionTeller} from "src/lib/oTokens/FixedStrikeOptionTeller.sol";

import {Actions, fromKeycode, Kernel, Keycode, Module, toKeycode} from "src/Kernel.sol";
import {OlympusTreasury} from "src/modules/TRSRY/OlympusTreasury.sol";
import {OlympusRoles} from "src/modules/ROLES/OlympusRoles.sol";
import {MegaToken} from "src/modules/TOKEN/MegaToken.sol";
import {OlympusPriceV2} from "src/modules/PRICE/OlympusPrice.v2.sol";
import {UniswapV3Price} from "src/modules/PRICE/submodules/feeds/UniswapV3Price.sol";
import {ChainlinkPriceFeeds} from "src/modules/PRICE/submodules/feeds/ChainlinkPriceFeeds.sol";
import {SimplePriceFeedStrategy} from
    "src/modules/PRICE/submodules/strategies/SimplePriceFeedStrategy.sol";

import {RolesAdmin} from "src/policies/RolesAdmin.sol";
import {TreasuryCustodian} from "src/policies/TreasuryCustodian.sol";
import {Emergency} from "src/policies/Emergency.sol";
import {Banker} from "src/policies/Banker.sol";
import {Issuer} from "src/policies/Issuer.sol";
import {Hedger} from "src/periphery/Hedger.sol";
import {PriceConfigV2} from "src/policies/PriceConfig.v2.sol";
import {MegaTokenOracle} from "src/policies/MegaTokenOracle.sol";

import {
    Id as MorphoId,
    MarketParams as MorphoMarketParams
} from "morpho-blue-1.0.0/interfaces/IMorpho.sol";
import {MarketParamsLib} from "morpho-blue-1.0.0/libraries/MarketParamsLib.sol";

// solhint-disable max-states-count
/// @notice Script to deploy the system
/// @dev    The address that this script is broadcast from must have write access to the contracts being configured
contract Deploy is Script, WithSalts, WithEnvironment {
    using stdJson for string;

    Kernel public kernel;

    /// @notice Maps deployment names to their corresponding deploy function selectors
    mapping(string => bytes4) public selectorMap;

    // Deploy system storage
    /// @notice Names of the deployments to be performed
    string[] public deployments;

    /// @notice Stores the contents of the deployment JSON file as a string
    /// @dev    Individual deployment args can be accessed using the _readDeploymentArgString and _readDeploymentArgAddress functions
    string public deploymentFileJson;

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
        // Modules
        selectorMap["OlympusTreasury"] = this._deployTreasury.selector;
        selectorMap["OlympusRoles"] = this._deployRoles.selector;
        selectorMap["Token"] = this._deployToken.selector;
        selectorMap["OlympusPriceV2"] = this._deployPriceV2.selector;
        selectorMap["ChainlinkPriceFeeds"] = this._deployChainlinkPriceFeeds.selector;
        selectorMap["UniswapV3Price"] = this._deployUniswapV3Price.selector;
        selectorMap["SimplePriceFeedStrategy"] = this._deploySimplePriceFeedStrategy.selector;

        // Policies
        selectorMap["RolesAdmin"] = this._deployRolesAdmin.selector;
        selectorMap["TreasuryCustodian"] = this._deployTreasuryCustodian.selector;
        selectorMap["Emergency"] = this._deployEmergency.selector;
        selectorMap["Banker"] = this._deployBanker.selector;
        selectorMap["Issuer"] = this._deployIssuer.selector;
        selectorMap["FixedStrikeOptionTeller"] = this._deployFixedStrikeOptionTeller.selector;
        selectorMap["Hedger"] = this._deployHedger.selector;
        selectorMap["PriceConfigV2"] = this._deployPriceConfigV2.selector;
        selectorMap["MegaTokenOracle"] = this._deployMegaTokenOracle.selector;

        // Load env data
        _loadEnv(chain_);

        // Load deployment data
        deploymentFileJson = vm.readFile(deployFilePath_);

        // Parse deployment sequence and names
        bytes memory sequence = abi.decode(deploymentFileJson.parseRaw(".sequence"), (bytes));
        uint256 len = sequence.length;
        console2.log("Contracts to be deployed:", len);

        if (len == 0) {
            return;
        } else if (len == 1) {
            // Only one deployment
            string memory name =
                abi.decode(deploymentFileJson.parseRaw(".sequence[0].name"), (string));
            deployments.push(name);
        } else {
            // More than one deployment
            string[] memory names =
                abi.decode(deploymentFileJson.parseRaw(".sequence[*].name"), (string[]));
            for (uint256 i = 0; i < len; i++) {
                string memory name = names[i];
                deployments.push(name);
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
            // Get deploy script selector
            string memory name = deployments[i];
            bytes4 selector = selectorMap[name];

            // Call the deploy function for the contract
            console2.log("Deploying", name);
            (bool success, bytes memory data) =
                address(this).call(abi.encodeWithSelector(selector, name));
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

    function _readDeploymentArgString(
        string memory deploymentName_,
        string memory key_
    ) internal view returns (string memory) {
        return deploymentFileJson.readString(
            string.concat(".sequence[?(@.name == '", deploymentName_, "')].args.", key_)
        );
    }

    function _readDeploymentArgBytes32(
        string memory deploymentName_,
        string memory key_
    ) internal view returns (bytes32) {
        return deploymentFileJson.readBytes32(
            string.concat(".sequence[?(@.name == '", deploymentName_, "')].args.", key_)
        );
    }

    function _readDeploymentArgAddress(
        string memory deploymentName_,
        string memory key_
    ) internal view returns (address) {
        return deploymentFileJson.readAddress(
            string.concat(".sequence[?(@.name == '", deploymentName_, "')].args.", key_)
        );
    }

    function _readDeploymentArgUint256(
        string memory deploymentName_,
        string memory key_
    ) internal view returns (uint256) {
        return deploymentFileJson.readUint(
            string.concat(".sequence[?(@.name == '", deploymentName_, "')].args.", key_)
        );
    }

    // ========== DEPLOYMENT FUNCTIONS ========== //

    // Module deployment functions
    function _deployTreasury(
        string memory
    ) public returns (address, string memory) {
        // No additional arguments for Treasury module

        // Deploy Treasury module
        vm.broadcast();
        OlympusTreasury TRSRY = new OlympusTreasury(kernel);
        console2.log("Treasury deployed at:", address(TRSRY));

        return (address(TRSRY), "mega.modules.OlympusTreasury");
    }

    function _deployRoles(
        string memory
    ) public returns (address, string memory) {
        // No additional arguments for Roles module

        // Deploy Roles module
        vm.broadcast();
        OlympusRoles ROLES = new OlympusRoles(kernel);
        console2.log("Roles deployed at:", address(ROLES));

        return (address(ROLES), "mega.modules.OlympusRoles");
    }

    function _deployToken(
        string memory name_
    ) public returns (address, string memory) {
        string memory name = _readDeploymentArgString(name_, "name");
        string memory symbol = _readDeploymentArgString(name_, "symbol");

        // Ensure the args are set
        require(bytes(name).length > 0, "name must be set");
        require(bytes(symbol).length > 0, "symbol must be set");

        console2.log("    Token name:", name);
        console2.log("    Token symbol:", symbol);

        // Deploy Token module
        vm.broadcast();
        MegaToken token = new MegaToken(kernel, name, symbol);
        console2.log("Token deployed at:", address(token));

        return (address(token), "mega.modules.Token");
    }

    function _deployPriceV2(
        string memory name_
    ) public returns (address, string memory) {
        uint8 decimals = uint8(_readDeploymentArgUint256(name_, "decimals"));
        uint32 observationFrequency =
            uint32(_readDeploymentArgUint256(name_, "observationFrequency"));

        // Ensure the args are set
        require(decimals != 0, "decimals must be set");
        require(observationFrequency != 0, "observationFrequency must be set");

        console2.log("    Decimals:", decimals);
        console2.log("    Observation frequency:", observationFrequency);

        // Deploy PriceV2 module
        vm.broadcast();
        OlympusPriceV2 priceV2 = new OlympusPriceV2(kernel, decimals, observationFrequency);
        console2.log("PriceV2 deployed at:", address(priceV2));

        return (address(priceV2), "mega.modules.PriceV2");
    }

    function _deployChainlinkPriceFeeds(
        string memory
    ) public returns (address, string memory) {
        // No additional arguments for ChainlinkPriceFeeds module

        // Deploy ChainlinkPriceFeeds module
        vm.broadcast();
        ChainlinkPriceFeeds chainlinkPriceFeeds =
            new ChainlinkPriceFeeds(Module(_envAddressNotZero("mega.modules.PriceV2")));
        console2.log("ChainlinkPriceFeeds deployed at:", address(chainlinkPriceFeeds));

        return (address(chainlinkPriceFeeds), "mega.submodules.PriceV2.ChainlinkPriceFeeds");
    }

    function _deployUniswapV3Price(
        string memory
    ) public returns (address, string memory) {
        // No additional arguments for UniswapV3Price module

        // Deploy UniswapV3Price module
        vm.broadcast();
        UniswapV3Price uniswapV3Price =
            new UniswapV3Price(Module(_envAddressNotZero("mega.modules.PriceV2")));
        console2.log("UniswapV3Price deployed at:", address(uniswapV3Price));

        return (address(uniswapV3Price), "mega.submodules.PriceV2.UniswapV3Price");
    }

    function _deploySimplePriceFeedStrategy(
        string memory
    ) public returns (address, string memory) {
        // No additional arguments for SimplePriceFeedStrategy module

        // Deploy SimplePriceFeedStrategy module
        vm.broadcast();
        SimplePriceFeedStrategy simplePriceFeedStrategy =
            new SimplePriceFeedStrategy(Module(_envAddressNotZero("mega.modules.PriceV2")));
        console2.log("SimplePriceFeedStrategy deployed at:", address(simplePriceFeedStrategy));

        return (address(simplePriceFeedStrategy), "mega.submodules.PriceV2.SimplePriceFeedStrategy");
    }

    function _deployRolesAdmin(
        string memory
    ) public returns (address, string memory) {
        // No additional arguments for RolesAdmin policy

        // Deploy RolesAdmin policy
        vm.broadcast();
        RolesAdmin rolesAdmin = new RolesAdmin(kernel);
        console2.log("RolesAdmin deployed at:", address(rolesAdmin));

        return (address(rolesAdmin), "mega.policies.RolesAdmin");
    }

    function _deployTreasuryCustodian(
        string memory
    ) public returns (address, string memory) {
        // No additional arguments for TreasuryCustodian policy

        // Deploy TreasuryCustodian policy
        vm.broadcast();
        TreasuryCustodian treasuryCustodian = new TreasuryCustodian(kernel);
        console2.log("TreasuryCustodian deployed at:", address(treasuryCustodian));

        return (address(treasuryCustodian), "mega.policies.TreasuryCustodian");
    }

    function _deployEmergency(
        string memory
    ) public returns (address, string memory) {
        // No additional arguments for Emergency policy

        // Deploy Emergency policy
        vm.broadcast();
        Emergency emergency = new Emergency(kernel);
        console2.log("Emergency deployed at:", address(emergency));

        return (address(emergency), "mega.policies.Emergency");
    }

    function _deployBanker(
        string memory
    ) public returns (address, string memory) {
        // No additional arguments for Banker policy

        address auctionHouse = _getAddressNotZero("axis.BatchAuctionHouse");

        // Generate the salt
        // This is not a vanity address, so the salt and derived address doesn't really matter
        bytes32 salt_;
        {
            bytes memory args = abi.encode(kernel, auctionHouse);

            bytes memory contractCode = type(Banker).creationCode;
            (string memory bytecodePath, bytes32 bytecodeHash) =
                _writeBytecode("Banker", contractCode, args);
            _setSalt(bytecodePath, "E7", "Banker", bytecodeHash);
            salt_ = _getSalt("Banker", type(Banker).creationCode, args);
            console2.log("Salt", vm.toString(salt_));
        }

        // Deploy Banker policy
        vm.broadcast();
        Banker banker = new Banker{salt: salt_}(kernel, auctionHouse);
        console2.log("Banker deployed at:", address(banker));

        return (address(banker), "mega.policies.Banker");
    }

    function _deployIssuer(
        string memory
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
        string memory name_
    ) public returns (address, string memory) {
        address authority = _readDeploymentArgAddress(name_, "authority");
        address guardian = _readDeploymentArgAddress(name_, "guardian");

        // Ensure the args are set
        // require(authority != address(0), "Authority must be set");
        require(guardian != address(0), "Guardian must be set");

        console2.log("    Authority:", authority);
        console2.log("    Guardian:", guardian);

        // Deploy FixedStrikeOptionTeller
        vm.broadcast();
        FixedStrikeOptionTeller teller = new FixedStrikeOptionTeller(guardian, Authority(authority));
        console2.log("FixedStrikeOptionTeller deployed at:", address(teller));

        return (address(teller), "axis.options.FixedStrikeOptionTeller");
    }

    function _deployMegaTokenOracle(
        string memory
    ) public returns (address, string memory) {
        // No additional arguments for MegaTokenOracle policy

        address loanToken = _getAddressNotZero("external.tokens.USDC");

        console2.log("    Loan token:", loanToken);

        // Deploy MegaTokenOracle policy
        vm.broadcast();
        MegaTokenOracle megaTokenOracle = new MegaTokenOracle(kernel, loanToken);
        console2.log("MegaTokenOracle deployed at:", address(megaTokenOracle));

        return (address(megaTokenOracle), "mega.policies.MegaTokenOracle");
    }

    function _deployHedger(
        string memory name_
    ) public returns (address, string memory) {
        uint24 reserveWethSwapFee_ = uint24(_readDeploymentArgUint256(name_, "reserveWethSwapFee"));
        uint24 mgstWethSwapFee_ = uint24(_readDeploymentArgUint256(name_, "mgstWethSwapFee"));
        uint256 lltv = _readDeploymentArgUint256(name_, "lltv");

        // Ensure the args are set
        require(reserveWethSwapFee_ != 0, "reserveWethSwapFee must be set");
        require(mgstWethSwapFee_ != 0, "mgstWethSwapFee must be set");
        require(lltv != 0, "lltv must be set");

        console2.log("    Reserve WETH swap fee:", reserveWethSwapFee_);
        console2.log("    MGST WETH swap fee:", mgstWethSwapFee_);
        console2.log("    LLTV:", lltv);

        address reserve = _getAddressNotZero("external.tokens.USDC");
        address mgst = _getAddressNotZero("external.tokens.MGST");
        address megaTokenOracle = _getAddressNotZero("mega.policies.MegaTokenOracle");

        // Validate the oracle
        require(MegaTokenOracle(megaTokenOracle).getLoanToken() == reserve, "loan token mismatch");
        require(
            MegaTokenOracle(megaTokenOracle).getCollateralToken() == mgst,
            "collateral token mismatch"
        );

        // Derive the ID for the MGST<>RESERVE market
        MorphoMarketParams memory mgstMarketParams = MorphoMarketParams({
            loanToken: reserve,
            collateralToken: mgst,
            oracle: megaTokenOracle,
            irm: address(0), // Disabled
            lltv: lltv
        });
        bytes32 mgstMarketId = MorphoId.unwrap(MarketParamsLib.id(mgstMarketParams));

        // Deploy Hedger
        vm.broadcast();
        Hedger hedger = new Hedger(
            _getAddressNotZero("mega.modules.Token"),
            _getAddressNotZero("external.tokens.WETH"),
            reserve,
            mgstMarketId,
            _getAddressNotZero("external.morpho"),
            _getAddressNotZero("external.uniswap.v3.swapRouter02"),
            _getAddressNotZero("external.uniswap.v3.swapQuoterV2"),
            reserveWethSwapFee_,
            mgstWethSwapFee_
        );
        console2.log("Hedger deployed at:", address(hedger));

        return (address(hedger), "mega.periphery.Hedger");
    }

    function _deployPriceConfigV2(
        string memory
    ) public returns (address, string memory) {
        // No additional arguments for PriceConfigV2 policy

        // Deploy PriceConfigV2 policy
        vm.broadcast();
        PriceConfigV2 priceConfigV2 = new PriceConfigV2(kernel);
        console2.log("PriceConfigV2 deployed at:", address(priceConfigV2));

        return (address(priceConfigV2), "mega.policies.PriceConfigV2");
    }

    // ========== VERIFICATION ========== //

    function kernelInstallation(
        string calldata chain_
    ) external {
        _loadEnv(chain_);

        // Modules
        OlympusRoles ROLES = OlympusRoles(_getAddressNotZero("mega.modules.OlympusRoles"));
        OlympusTreasury TRSRY = OlympusTreasury(_getAddressNotZero("mega.modules.OlympusTreasury"));
        MegaToken token = MegaToken(_getAddressNotZero("mega.modules.Token"));
        OlympusPriceV2 PRICE = OlympusPriceV2(_getAddressNotZero("mega.modules.PriceV2"));

        // Policies
        RolesAdmin rolesAdmin = RolesAdmin(_getAddressNotZero("mega.policies.RolesAdmin"));
        TreasuryCustodian treasuryCustodian =
            TreasuryCustodian(_getAddressNotZero("mega.policies.TreasuryCustodian"));
        Emergency emergency = Emergency(_getAddressNotZero("mega.policies.Emergency"));
        Banker banker = Banker(_getAddressNotZero("mega.policies.Banker"));
        Issuer issuer = Issuer(_getAddressNotZero("mega.policies.Issuer"));
        PriceConfigV2 priceConfigV2 =
            PriceConfigV2(_getAddressNotZero("mega.policies.PriceConfigV2"));
        MegaTokenOracle megaTokenOracle =
            MegaTokenOracle(_getAddressNotZero("mega.policies.MegaTokenOracle"));

        vm.startBroadcast();

        console2.log("Installing modules");

        // Install modules
        kernel.executeAction(Actions.InstallModule, address(ROLES));
        kernel.executeAction(Actions.InstallModule, address(TRSRY));
        kernel.executeAction(Actions.InstallModule, address(token));
        kernel.executeAction(Actions.InstallModule, address(PRICE));

        console2.log("Activating policies");

        // Activate policies
        kernel.executeAction(Actions.ActivatePolicy, address(rolesAdmin));
        kernel.executeAction(Actions.ActivatePolicy, address(treasuryCustodian));
        kernel.executeAction(Actions.ActivatePolicy, address(emergency));
        kernel.executeAction(Actions.ActivatePolicy, address(banker));
        kernel.executeAction(Actions.ActivatePolicy, address(issuer));
        kernel.executeAction(Actions.ActivatePolicy, address(priceConfigV2));
        kernel.executeAction(Actions.ActivatePolicy, address(megaTokenOracle));
        console2.log("Done");

        vm.stopBroadcast();

        // See PriceConfiguration.s.sol for PRICE submodule installation and configuration
    }

    /// @dev Verifies that the environment variable addresses were set correctly following deployment
    /// @dev Should be called prior to pushAuth()
    function verifyKernelInstallation(
        string calldata chain_
    ) external {
        _loadEnv(chain_);

        // Modules
        // TRSRY
        {
            OlympusTreasury TRSRY =
                OlympusTreasury(_getAddressNotZero("mega.modules.OlympusTreasury"));
            Module trsryModule = kernel.getModuleForKeycode(toKeycode("TRSRY"));
            Keycode trsryKeycode = kernel.getKeycodeForModule(TRSRY);
            require(trsryModule == TRSRY);
            require(fromKeycode(trsryKeycode) == "TRSRY");
        }

        // TOKEN
        {
            MegaToken token = MegaToken(_getAddressNotZero("mega.modules.Token"));
            Module tokenModule = kernel.getModuleForKeycode(toKeycode("TOKEN"));
            Keycode tokenKeycode = kernel.getKeycodeForModule(token);
            require(tokenModule == token);
            require(fromKeycode(tokenKeycode) == "TOKEN");
        }

        // ROLES
        {
            OlympusRoles ROLES = OlympusRoles(_getAddressNotZero("mega.modules.OlympusRoles"));
            Module rolesModule = kernel.getModuleForKeycode(toKeycode("ROLES"));
            Keycode rolesKeycode = kernel.getKeycodeForModule(ROLES);
            require(rolesModule == ROLES);
            require(fromKeycode(rolesKeycode) == "ROLES");
        }

        // PRICEv2
        {
            OlympusPriceV2 PRICE = OlympusPriceV2(_getAddressNotZero("mega.modules.PriceV2"));
            Module priceModule = kernel.getModuleForKeycode(toKeycode("PRICE"));
            Keycode priceKeycode = kernel.getKeycodeForModule(PRICE);
            require(priceModule == PRICE);
            require(fromKeycode(priceKeycode) == "PRICE");
        }

        // Policies
        RolesAdmin rolesAdmin = RolesAdmin(_getAddressNotZero("mega.policies.RolesAdmin"));
        TreasuryCustodian treasuryCustodian =
            TreasuryCustodian(_getAddressNotZero("mega.policies.TreasuryCustodian"));
        Emergency emergency = Emergency(_getAddressNotZero("mega.policies.Emergency"));
        Banker banker = Banker(_getAddressNotZero("mega.policies.Banker"));
        Issuer issuer = Issuer(_getAddressNotZero("mega.policies.Issuer"));
        PriceConfigV2 priceConfigV2 =
            PriceConfigV2(_getAddressNotZero("mega.policies.PriceConfigV2"));
        MegaTokenOracle megaTokenOracle =
            MegaTokenOracle(_getAddressNotZero("mega.policies.MegaTokenOracle"));

        require(kernel.isPolicyActive(rolesAdmin));
        require(kernel.isPolicyActive(treasuryCustodian));
        require(kernel.isPolicyActive(emergency));
        require(kernel.isPolicyActive(banker));
        require(kernel.isPolicyActive(issuer));
        require(kernel.isPolicyActive(priceConfigV2));
        require(kernel.isPolicyActive(megaTokenOracle));
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
