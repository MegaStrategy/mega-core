// SPDX-License-Identifier: TBD
pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin-contracts-4.9.6/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin-contracts-4.9.6/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin-contracts-4.9.6/access/Ownable.sol";

// Morpho
import {
    IMorpho,
    MarketParams as MorphoMarketParams,
    Id as MorphoId
} from "morpho-blue-1.0.0/interfaces/IMorpho.sol";
import {MorphoLib} from "morpho-blue-1.0.0/libraries/periphery/MorphoLib.sol";
import {MorphoBalancesLib} from "morpho-blue-1.0.0/libraries/periphery/MorphoBalancesLib.sol";
import {SharesMathLib} from "morpho-blue-1.0.0/libraries/SharesMathLib.sol";

// Uniswap
import {IUniversalRouter} from "src/lib/Uniswap/IUniversalRouter.sol";

// Local
import {ConvertibleDebtToken} from "src/lib/ConvertibleDebtToken.sol";
import {cvVault} from "src/vaults/cvVault.sol"; // TODO create an interface for this so we don't have to import the whole thing

/// @notice The cvVault is purpose built for executing strategies with tokens that cannot be compounded.
///         The underlying/deposit token is not compoundable, but can earn yield in another token.
///         Therefore, we combine the functionality of a staking contract with a ERC4626 vault so the position is tokenized.
///         We use ERC4626 instead of a regular ERC20 as the receipt token to allow the vault to perform operations that change the underlying balance,
///         such as market making.
contract cvStrategy is Ownable {
    using MorphoLib for IMorpho;
    using MorphoBalancesLib for IMorpho;
    using SafeERC20 for IERC20;

    // ========== ERRORS ========== //

    error InvalidParam(string name);
    error NotAuthorized();

    // ========== EVENTS ========== //

    // ========== DATA STRUCTURES ========== //

    enum Actions {
        MorphoSupply,
        MorphoBorrow,
        MorphoRepay,
        MorphoWithdraw,
        MorphoFlashloan,
        UniSwap,
        AeroSwap,
        BankerConvert,
        ProcessWithdrawal
    }

    struct Instruction {
        Actions action;
        bytes data;
    }

    // ========== STATE VARIABLES ========== //

    address public manager;

    // Morpho
    IMorpho public morpho;
    MorphoId public cvMarket;
    MorphoId public tokenMarket;

    // Uniswap
    IUniversalRouter public uniswap;

    // Tokens
    ConvertibleDebtToken public immutable cvToken;
    IERC20 public immutable hedgedToken;
    IERC20 public immutable rewardToken;

    // ========== CONSTRUCTOR ========== //

    constructor(
        address vault_,
        address manager_,
        address morpho_,
        MorphoId cvMarket_,
        MorphoId tokenMarket_
    ) Ownable() {
        // Addresses cannot be zero
        if (vault_ == address(0)) revert InvalidParam("vault");
        if (manager_ == address(0)) revert InvalidParam("manager");
        if (morpho_ == address(0)) revert InvalidParam("morpho");

        vault = cvVault(vault_);

        // Cache token addresses locally to avoid more external calls to vault later
        cvToken = ConvertibleDebtToken(vault.asset());
        hedgedToken = vault.hedgedToken();
        rewardToken = vault.rewardToken();

        // Initialize Morpho
        morpho = IMorpho(morpho_);

        // TODO cvMarket needs to be CV<>TOKEN
        cvMarket = cvMarket_;

        // TODO token market needs to be TOKEN<>REWARD
        // This isn't strictly required since we could deposit to a morpho vault that services many markets
        // Maybe easier to keep it to a single market for now
        tokenMarket = tokenMarket_;
    }

    // ========== MODIFIERS ========== //

    modifier onlyVault() {
        if (msg.sender != address(vault)) revert NotAuthorized();
        _;
    }

    // ========== WITHDRAW ========== //

    function withdrawCvToken(
        uint256 amount_
    ) external onlyVault {
        // Get the total assets in the strategy. If the amount is more than the total assets, revert
        uint256 total = totalAssets();
        if (amount_ > total) revert InvalidParam("amount");

        // TODO maybe abstract the below logic into a "source" function
        // Potentially, combine in someway with the need to payback the loan to remove collateral
        // proportionately to the amount that is being withdrawn

        // Check if there are enough assets in this contract to send to the vault
        // If not, source the difference from the collateral deposited to the morpho market
        // If necessary, transfer the amount to the vault once there are enough tokens
        uint256 local = cvToken.balanceOf(address(this));
        if (amount_ > local) {
            // Withdraw the difference from the morpho market
            uint256 difference = amount_ - local;

            // Get the market params for the morpho market
            MorphoMarketParams memory marketParams = morpho.idToMarketParams(cvMarket);

            // If local amount is zero, then we can just send the withdrawal to the vault
            // Alternatively, if there is enough in the market, we can source from there and keep it to one transfer
            // If neither are true, then it will require two transfers
            if (local == 0 || total - local >= amount_) {
                // Withdraw the total amount from the morpho market and send directly to the vault
                morpho.withdraw(marketParams, amount_, false, address(this), address(vault));

                // We return early here since the balance is already sent to the vault
                return;
            } else {
                // Withdraw the difference from the morpho market to this contract
                morpho.withdraw(marketParams, difference, false, address(this), address(this));
            }
        }

        // If we get here, then there are enough tokens in the contract to send to the vault
        cvToken.safeTransfer(address(vault), amount_);
    }

    function withdrawRewardToken(
        uint256 amount_
    ) external onlyVault {
        // Get the current rewards balance. If the amount is more than the current rewards, revert
        uint256 total = currentRewards();
        if (amount_ > total) revert InvalidParam("amount");

        // Check if there are enough rewards in this contract to pay out
        // If not, source from the vault entirely or withdraw the difference from the morpho market
        // If necessary, transfer the amount to the vault once there are enough tokens
        uint256 local = rewardToken.balanceOf(address(this));
        if (amount_ > local) {
            // Withdraw the difference from the morpho market
            uint256 difference = amount_ - local;

            // Get the market params for the morpho market
            MorphoMarketParams memory marketParams = morpho.idToMarketParams(tokenMarket);

            // If local amount is zero, then we can just send the withdrawal to the vault
            // Alternatively, if there is enough in the market, we can source from there and keep it to one transfer
            // If neither are true, then it will require two transfers
            if (local == 0 || total - local >= amount_) {
                // Withdraw the total amount from the morpho market and send directly to the vault
                morpho.withdraw(marketParams, amount_, false, address(this), address(vault));

                // We return early here since the balance is already sent to the vault
                return;
            } else {
                // Withdraw the difference from the morpho market to this contract
                morpho.withdraw(marketParams, difference, false, address(this), address(this));
            }
        }

        // If we get here, then there are enough tokens in the contract to send to the vault
        rewardToken.safeTransfer(address(vault), amount_);
    }

    // ========== VIEW FUNCTIONS ========== //

    function totalAssets() public view override returns (uint256) {
        // We have to override this function to track assets deployed as collateral in the Morpho market in addition to local ones
        uint256 local = cvToken.balanceOf(address(this));
        uint256 deployed = morpho.collateral(cvMarket, address(this));
        return local + deployed;
    }

    function currentRewards() public view returns (uint256) {
        // Calculates the currently controlled balance rewards, not including those that were previously paid out
        uint256 local = rewardToken.balanceOf(address(this));
        uint256 deployed = morpho.expectedSupplyAssets(tokenMarket, address(this));
        return local + deployed;
    }

    function currentHedgedBalance() public view returns (uint256) {
        // Calculates the currently controlled balance of the hedged asset
        return morpho.expectedBorrowAssets(cvMarket, address(this));
    }

    // ========== MANAGER ========== //

    function execute(
        Instruction[] memory instructions
    ) external onlyManager {
        for (uint256 i; i < instructions.length; i++) {
            Instruction memory instruction = instructions[i];

            if (instruction.action == Actions.MorphoSupply) {
                _morphoSupply(instruction.data);
            } else if (instruction.action == Actions.MorphoBorrow) {
                _morphoBorrow(instruction.data);
            } else if (instruction.action == Actions.MorphoRepay) {
                _morphoRepay(instruction.data);
            } else if (instruction.action == Actions.MorphoWithdraw) {
                _morphoWithdraw(instruction.data);
            } else if (instruction.action == Actions.MorphoFlashloan) {
                _morphoFlashloan(instruction.data);
            } else if (instruction.action == Actions.UniSwap) {
                _uniSwap(instruction.data);
            } else if (instruction.action == Actions.AeroSwap) {
                _aeroSwap(instruction.data);
            } else if (instruction.action == Actions.BankerConvert) {
                _bankerConvert(instruction.data);
            } else if (instruction.action == Actions.ProcessWithdrawal) {
                _processWithdrawal(instruction.data);
            }
        }

        // TODO should the yield index be updated after the instructions are executed?
        // Are there reasons to not update this?
    }

    // ========== ACTIONS ========== //

    function _parseMorphoData(
        bytes memory data
    ) internal returns (MorphoMarketParams memory, bool, uint256) {
        // Parse encoded data
        (MorphoId id, bool inAssets, uint256 amount) = abi.decode(data, (MorphoId, bool, uint256));

        // Get the market params for the morpho market
        MorphoMarketParams memory marketParams = morpho.idToMarketParams(id);

        return (marketParams, inAssets, amount);
    }

    function _morphoSupply(
        bytes memory data
    ) internal {
        // Decode the data
        (MorphoMarketParams memory marketParams, bool inAssets, uint256 amount) =
            _parseMorphoData(data);

        // Require that the amount is in assets for this function
        if (!inAssets) revert InvalidParam("data.inAssets");

        // Approve the loan token and call supply
        IERC20(marketParams.loanToken).safeApprove(address(morpho), amount);
        // TODO do we need to cache the position?
        morpho.supply(
            marketParams, // market params
            amount, // amount in assets
            0, // amount in shares (not used)
            address(this), // onBehalfOf
            bytes("") // data (not used)
        );
    }

    function _morphoSupplyCollateral(
        bytes memory data
    ) internal {
        // Decode the data
        (MorphoMarketParams memory marketParams, bool inAssets, uint256 amount) =
            _parseMorphoData(data);

        // Require that the amount is in assets for this function
        if (!inAssets) revert InvalidParam("data.inAssets");

        // Approve the collateral token and call supplyCollateral
        IERC20(marketParams.collateralToken).safeApprove(address(morpho), amount);
        // TODO do we need to cache the position?
        morpho.supplyCollateral(
            marketParams, // market params
            amount, // amount in assets
            address(this), // onBehalfOf
            bytes("") // data (not used)
        );
    }

    function _morphoBorrow(
        bytes memory data
    ) internal {
        // Decode the data
        (MorphoMarketParams memory marketParams, bool inAssets, uint256 amount) =
            _parseMorphoData(data);

        // Require that the amount is in assets for this function
        if (!inAssets) revert InvalidParam("data.inAssets");

        // Borrow the amount from the market
        // Will revert if there isn't sufficient collateral
        // TODO do we need to use the return values?
        morpho.borrow(
            marketParams, // market params
            amount, // amount in assets
            0, // amount in shares (not used)
            address(this), // onBehalfOf
            address(this) // recipient
        );
    }

    function _morphoRepay(
        bytes memory data
    ) internal {
        // Decode the data
        (MorphoMarketParams memory marketParams, bool inAssets, uint256 amount) =
            _parseMorphoData(data);

        // Handle repaying in assets or shares
        if (inAssets) {
            // Approve the market for the amount and call repay
            IERC20(marketParams.loanToken).safeApprove(address(morpho), amount);
            morpho.repay(
                marketParams, // market params
                amount, // amount in assets
                0, // amount in shares (not used)
                address(this), // onBehalfOf
                bytes("") // dat (not used)
            );
        } else {
            // Recommended to repay all borrowed tokens

            // Calculate the amount in assets (be conservative for the approval)
            (,, uint256 totalBorrowAssets, uint256 totalBorrowShares) =
                morpho.expectedMarketBalances(marketParams);
            uint256 assets = SharesMathLib.toAssetsUp(amount, totalBorrowAssets, totalBorrowShares);

            // Approve the market for the amount in assets and call repay with the shares value
            IERC20(marketParams.loanToken).safeApprove(address(morpho), assets);
            morpho.repay(
                marketParams, // market params
                0, // amount in assets (not used)
                amount, // amount in shares
                address(this), // onBehalfOf
                bytes("") // dat (not used)
            );
        }
    }

    function _morphoWithdraw(
        bytes memory data
    ) internal {
        // Decode the data
        (MorphoMarketParams memory marketParams, bool inAssets, uint256 amount) =
            _parseMorphoData(data);

        if (inAssets) {
            morpho.withdraw(
                marketParams, // market params
                amount, // amount in assets
                0, // amount in shares (not used)
                address(this), // onBehalfOf
                address(this) // recipient
            );
        } else {
            // Recommended to withdraw all supplied assets
            morpho.withdraw(
                marketParams, // market params
                0, // amount in assets (not used)
                amount, // amount in shares
                address(this), // onBehalfOf
                address(this) // recipient
            );
        }
    }

    function _morphoWithdrawCollateral(
        bytes memory data
    ) internal {
        // Decode the data
        (MorphoMarketParams memory marketParams, bool inAssets, uint256 amount) =
            _parseMorphoData(data);

        // Require that the amount is in assets for this function
        if (!inAssets) revert InvalidParam("data.inAssets");

        morpho.withdrawCollateral(
            marketParams, // market params
            amount, // amount in assets
            address(this), // onBehalfOf
            address(this) // recipient
        );
    }

    function _morphoFlashloan(
        bytes memory data
    ) internal {}

    function _uniSwap(
        bytes memory data
    ) internal {}

    function _aeroSwap(
        bytes memory data
    ) internal {}

    function _bankerConvert(
        bytes memory data
    ) internal {}

    function _processWithdrawal(
        bytes memory data
    ) internal {}

    // ========== ADMIN ========== //

    function setManager(
        address manager_
    ) external onlyOwner {
        manager = manager_;
    }
}
