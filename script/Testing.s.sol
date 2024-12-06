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
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant USDC_MINTER = 0x2230393EDAD0299b7E7B59F20AA856cD1bEd52e1;
    address payable constant WETH = payable(0x4200000000000000000000000000000000000006);

    function setEthBalance(address to_, uint256 amount_) public {
        string[] memory setBalanceInputs = new string[](5);
        setBalanceInputs[0] = "cast";
        setBalanceInputs[1] = "rpc";
        setBalanceInputs[2] = "anvil_setBalance";
        setBalanceInputs[3] = vm.toString(to_);
        setBalanceInputs[4] = vm.toString(amount_);
        vm.ffi(setBalanceInputs);

        console2.log("ETH balance", address(to_).balance);
    }

    function depositEth(uint256 amount_) public {
        console2.log("Depositing ETH", amount_);

        vm.startBroadcast();
        WETHToken(WETH).deposit{value: amount_}();
        vm.stopBroadcast();

        console2.log("WETH balance", WETHToken(WETH).balanceOf(address(msg.sender)));
    }

    function mintToken(address token_, address tokenOwner_, address to_, uint256 amount_) public {
        // TODO this isn't working, due to the "caller is not a minter" error
        // Impersonate the token owner
        string[] memory impersonateInputs = new string[](4);
        impersonateInputs[0] = "cast";
        impersonateInputs[1] = "rpc";
        impersonateInputs[2] = "anvil_impersonateAccount";
        impersonateInputs[3] = vm.toString(tokenOwner_);
        vm.ffi(impersonateInputs);

        // Mint the token
        string[] memory mintInputs = new string[](9);
        mintInputs[0] = "cast";
        mintInputs[1] = "send";
        mintInputs[2] = vm.toString(token_);
        mintInputs[3] = "--from";
        mintInputs[4] = vm.toString(tokenOwner_);
        mintInputs[5] = "mint(address,uint256)(bool)";
        mintInputs[6] = vm.toString(to_);
        mintInputs[7] = vm.toString(amount_);
        mintInputs[8] = "--unlocked";
        vm.ffi(mintInputs);

        // End impersonation
        string[] memory endImpersonateInputs = new string[](4);
        endImpersonateInputs[0] = "cast";
        endImpersonateInputs[1] = "rpc";
        endImpersonateInputs[2] = "anvil_stopImpersonatingAccount";
        endImpersonateInputs[3] = vm.toString(tokenOwner_);
        vm.ffi(endImpersonateInputs);
    }

    function initialize(string calldata chain_) external {
        _loadEnv(chain_);

        // Grant "admin" role to the script deployer
        vm.startBroadcast();
        console2.log("sender", msg.sender);
        RolesAdmin(_envAddressNotZero("mega.policies.RolesAdmin")).grantRole(bytes32("admin"), msg.sender);
        vm.stopBroadcast();

        // Grant "manager" role to the script deployer
        vm.startBroadcast();
        RolesAdmin(_envAddressNotZero("mega.policies.RolesAdmin")).grantRole(bytes32("manager"), msg.sender);
        vm.stopBroadcast();

        // Initialize the Banker
        vm.startBroadcast();
        Banker(_envAddressNotZero("mega.policies.Banker")).initialize(
            0,
            0,
            0,
            1e18
        );
        vm.stopBroadcast();
    }

    function createDebtToken(string calldata chain_) external {
        _loadEnv(chain_);

        // Create the debt token
        uint48 maturity = uint48(block.timestamp + 1 days);
        vm.startBroadcast();
        address debtToken = Banker(_envAddressNotZero("mega.policies.Banker")).createDebtToken(WETH, maturity, 1e18);
        vm.stopBroadcast();
        console2.log("debtToken", debtToken);
    }

    function issueDebtToken(string calldata chain_, address debtToken_, address to_, uint256 amount_) external {
        _loadEnv(chain_);

        // Deal the sender some ETH
        vm.startBroadcast();
        setEthBalance(msg.sender, 10 ether);
        vm.stopBroadcast();

        // Deposit ETH to obtain WETH
        depositEth(amount_);

        // Transfer the WETH amount to the Treasury
        vm.startBroadcast();
        ERC20(WETH).transfer(address(_envAddressNotZero("mega.modules.OlympusTreasury")), amount_);
        vm.stopBroadcast();

        // Verify the WETH is in the Treasury
        console2.log("WETH in Treasury", ERC20(WETH).balanceOf(_envAddressNotZero("mega.modules.OlympusTreasury")));

        // Issue the debt token
        vm.startBroadcast();
        Banker(_envAddressNotZero("mega.policies.Banker")).issue(debtToken_, to_, amount_);
        vm.stopBroadcast();

        console2.log("Debt token issued", amount_);
    }

    function convertDebtToken(string calldata chain_, address debtToken_, uint256 amount_) external {
        _loadEnv(chain_);

        // Approve the Banker to spend the debt token
        vm.startBroadcast();
        ERC20(debtToken_).approve(address(Banker(_envAddressNotZero("mega.policies.Banker"))), amount_);
        vm.stopBroadcast();

        // Convert the debt token to TOKEN
        vm.startBroadcast();
        Banker(_envAddressNotZero("mega.policies.Banker")).convert(debtToken_, amount_);
        vm.stopBroadcast();
    }

    function redeemDebtToken(string calldata chain_, address debtToken_, uint256 amount_) external {
        _loadEnv(chain_);

        // Redeem the debt token
        vm.startBroadcast();
        Banker(_envAddressNotZero("mega.policies.Banker")).redeem(debtToken_, amount_);
        vm.stopBroadcast();
    }

    function createOptionToken(string calldata chain_) external {
        _loadEnv(chain_);

        uint48 expiry = uint48(block.timestamp + 1 days);
        vm.startBroadcast();
        address optionToken = Issuer(_envAddressNotZero("mega.policies.Issuer")).createO(USDC, expiry, 2e18);
        vm.stopBroadcast();
        console2.log("optionToken", optionToken);
    }

    function issueOptionToken(string calldata chain_, address optionToken_, uint256 amount_) external {
        _loadEnv(chain_);

        // Issue the option token
        vm.startBroadcast();
        Issuer(_envAddressNotZero("mega.policies.Issuer")).issueO(optionToken_, msg.sender, amount_);
        vm.stopBroadcast();

        console2.log("Option token issued", amount_);
    }
}
