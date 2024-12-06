// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.19;

import {Script} from "@forge-std/Script.sol";
import {WithEnvironment} from "./WithEnvironment.s.sol";
import {console2} from "@forge-std/console2.sol";
import {ERC20} from "solmate-6.8.0/tokens/ERC20.sol";
import {MockERC20} from "solmate-6.8.0/test/utils/mocks/MockERC20.sol";
import {WETH as WETHToken} from "solmate-6.8.0/tokens/WETH.sol";

import {RolesAdmin} from "../src/policies/RolesAdmin.sol";
import {Banker} from "../src/policies/Banker.sol";
import {Issuer} from "../src/policies/Issuer.sol";

contract Testing is Script, WithEnvironment {
    function addAdmin(string calldata chain_, address admin_) external {
        _loadEnv(chain_);

        vm.startBroadcast();
        RolesAdmin(_envAddressNotZero("mega.policies.RolesAdmin")).grantRole(
            bytes32("admin"), admin_
        );
        vm.stopBroadcast();
    }

    function addManager(string calldata chain_, address manager_) external {
        _loadEnv(chain_);

        vm.startBroadcast();
        RolesAdmin(_envAddressNotZero("mega.policies.RolesAdmin")).grantRole(
            bytes32("manager"), manager_
        );
        vm.stopBroadcast();
    }

    function initialize(
        string calldata chain_
    ) external {
        _loadEnv(chain_);

        // Add as admin and manager first

        // Initialize the Banker
        vm.startBroadcast();
        Banker(_envAddressNotZero("mega.policies.Banker")).initialize(0, 0, 0, 1e18);
        vm.stopBroadcast();
    }

    function createDebtToken(
        string calldata chain_
    ) external {
        _loadEnv(chain_);

        // Create the debt token
        uint48 maturity = uint48(block.timestamp + 1 days);
        vm.startBroadcast();
        address debtToken = Banker(_envAddressNotZero("mega.policies.Banker")).createDebtToken(
            address(_envAddressNotZero("external.tokens.WETH")), maturity, 1e18
        );
        vm.stopBroadcast();
        console2.log("debtToken", debtToken);
    }

    function issueDebtToken(
        string calldata chain_,
        address debtToken_,
        address to_,
        uint256 amount_
    ) external {
        _loadEnv(chain_);

        // Transfer the WETH amount to the Treasury
        vm.startBroadcast();
        ERC20(address(_envAddressNotZero("external.tokens.WETH"))).transfer(
            address(_envAddressNotZero("mega.modules.OlympusTreasury")), amount_
        );
        vm.stopBroadcast();

        // Verify the WETH is in the Treasury
        console2.log(
            "WETH in Treasury",
            ERC20(address(_envAddressNotZero("external.tokens.WETH"))).balanceOf(
                _envAddressNotZero("mega.modules.OlympusTreasury")
            )
        );

        // Issue the debt token
        vm.startBroadcast();
        Banker(_envAddressNotZero("mega.policies.Banker")).issue(debtToken_, to_, amount_);
        vm.stopBroadcast();

        console2.log("Debt token issued", amount_);
    }

    function convertDebtToken(
        string calldata chain_,
        address debtToken_,
        uint256 amount_
    ) external {
        _loadEnv(chain_);

        // Approve the Banker to spend the debt token
        vm.startBroadcast();
        ERC20(debtToken_).approve(
            address(Banker(_envAddressNotZero("mega.policies.Banker"))), amount_
        );
        vm.stopBroadcast();

        // Convert the debt token to TOKEN
        vm.startBroadcast();
        Banker(_envAddressNotZero("mega.policies.Banker")).convert(debtToken_, amount_);
        vm.stopBroadcast();
    }

    function redeemDebtToken(
        string calldata chain_,
        address debtToken_,
        uint256 amount_
    ) external {
        _loadEnv(chain_);

        // Redeem the debt token
        vm.startBroadcast();
        Banker(_envAddressNotZero("mega.policies.Banker")).redeem(debtToken_, amount_);
        vm.stopBroadcast();
    }

    function createOptionToken(
        string calldata chain_
    ) external {
        _loadEnv(chain_);

        uint48 expiry = uint48(block.timestamp + 1 days);
        vm.startBroadcast();
        address optionToken = Issuer(_envAddressNotZero("mega.policies.Issuer")).createO(
            address(_envAddressNotZero("external.tokens.USDC")), expiry, 2e18
        );
        vm.stopBroadcast();
        console2.log("optionToken", optionToken);
    }

    function issueOptionToken(
        string calldata chain_,
        address optionToken_,
        uint256 amount_
    ) external {
        _loadEnv(chain_);

        // Issue the option token
        vm.startBroadcast();
        Issuer(_envAddressNotZero("mega.policies.Issuer")).issueO(optionToken_, msg.sender, amount_);
        vm.stopBroadcast();

        console2.log("Option token issued", amount_);
    }
}
