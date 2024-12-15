// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.19;

import {Script} from "@forge-std/Script.sol";
import {WithEnvironment} from "./WithEnvironment.s.sol";
import {console2} from "@forge-std/console2.sol";
import {ERC20} from "solmate-6.8.0/tokens/ERC20.sol";

import {RolesAdmin} from "../src/policies/RolesAdmin.sol";
import {Banker} from "../src/policies/Banker.sol";
import {Issuer} from "../src/policies/Issuer.sol";
import {Point} from "axis-core-1.0.1/lib/ECIES.sol";
import {ECIES} from "axis-core-1.0.1/lib/ECIES.sol";

contract TasksScript is Script, WithEnvironment {
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

    function createBankerAuction(string calldata chain_, uint256 auctionPrivateKey_) external {
        // TODO specify start date, maturity, conversion price, capacity
        _loadEnv(chain_);

        // Set up debt token params
        Banker.DebtTokenParams memory dtParams = Banker.DebtTokenParams({
            underlying: address(_envAddressNotZero("external.tokens.USDC")),
            maturity: uint48(block.timestamp + 30 days),
            conversionPrice: 30e6
        });

        // Set up auction params
        Banker.AuctionParams memory auctionParams = Banker.AuctionParams({
            start: uint48(block.timestamp + 1 minutes),
            duration: uint48(1 days),
            capacity: 1000e6,
            auctionPublicKey: ECIES.calcPubKey(Point(1, 2), auctionPrivateKey_),
            infoHash: ""
        });

        // Create the auction
        vm.startBroadcast();
        Banker(_envAddressNotZero("mega.policies.Banker")).auction(
            dtParams, auctionParams
        );
        vm.stopBroadcast();

        console2.log("Auction created");
    }

    function createDebtToken(string calldata chain_, uint256 conversionPrice_) external {
        _loadEnv(chain_);

        // Create the debt token
        uint48 maturity = uint48(block.timestamp + 1 days);
        vm.startBroadcast();
        address debtToken = Banker(_envAddressNotZero("mega.policies.Banker")).createDebtToken(
            address(_envAddressNotZero("external.tokens.USDC")), maturity, conversionPrice_
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

        // Transfer the USDC amount to the Treasury
        vm.startBroadcast();
        ERC20(address(_envAddressNotZero("external.tokens.USDC"))).transfer(
            address(_envAddressNotZero("mega.modules.OlympusTreasury")), amount_
        );
        vm.stopBroadcast();

        // Verify the USDC is in the Treasury
        console2.log(
            "USDC in Treasury",
            ERC20(address(_envAddressNotZero("external.tokens.USDC"))).balanceOf(
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
            address(_envAddressNotZero("external.tokens.WETH")), expiry, 2e18
        );
        vm.stopBroadcast();
        console2.log("optionToken", optionToken);
    }

    function issueOptionToken(
        string calldata chain_,
        address optionToken_,
        address to_,
        uint256 amount_
    ) external {
        _loadEnv(chain_);

        // Issue the option token
        vm.startBroadcast();
        Issuer(_envAddressNotZero("mega.policies.Issuer")).issueO(optionToken_, to_, amount_);
        vm.stopBroadcast();

        console2.log("Option token issued", amount_);
    }
}
