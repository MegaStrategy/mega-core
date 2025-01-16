// SPDX-License-Identifier: TBD
pragma solidity >=0.8.0;

import {Point} from "axis-core-1.0.1/lib/ECIES.sol";

interface IBanker {
    // ========== ERRORS ========== //

    error InvalidDebtToken();
    error InvalidParam(string name);
    error Inactive();
    error DebtTokenMatured();
    error DebtTokenNotMatured();
    error OnlyLocal();

    // ========== EVENTS ========== //

    event DebtAuction(uint96 lotId);
    event DebtIssued(address debtToken, address to, uint256 amount);
    event DebtRepaid(address debtToken, address from, uint256 amount);
    event DebtConverted(address debtToken, address from, uint256 amount, uint256 mintAmount);
    event AuctionSucceeded(address debtToken, uint256 refund, address underlying, uint256 proceeds);
    event MaxDiscountSet(uint256 maxDiscount);
    event MinFillPercentSet(uint24 minFillPercent);
    event MaxBidsSet(uint256 maxBids);
    event ReferrerFeeSet(uint48 referrerFee);

    /// @notice Emitted when a new convertible debt token is created
    event ConvertibleDebtTokenCreated(
        address indexed cdt,
        address indexed underlying,
        address indexed convertsTo,
        uint48 maturity,
        uint256 conversionPrice
    );

    // ========== DATA STRUCTURES ========== //

    /// @notice Parameters for creating a debt token
    ///
    /// @param  underlying      The underlying asset for the debt token
    /// @param  maturity        The maturity timestamp of the debt token
    /// @param  conversionPrice The price at which the debt token can be converted to the underlying asset. Amount of underlying to MGST in underlying decimals.
    struct DebtTokenParams {
        address underlying;
        uint48 maturity;
        uint256 conversionPrice;
    }

    /// @notice Parameters for creating an auction
    ///
    /// @param  start               The start timestamp of the auction
    /// @param  duration            The duration of the auction in seconds
    /// @param  capacity            The capacity of the auction in MGST
    /// @param  auctionPublicKey    The public key for the auction
    /// @param  infoHash            The IPFS hash for the auction
    struct AuctionParams {
        uint48 start;
        uint48 duration;
        uint256 capacity;
        Point auctionPublicKey;
        string infoHash;
    }

    // ========== AUCTION ========== //

    /// @notice Creates an auction for a convertible debt token
    /// @dev    The implementing function should ensure the following:
    ///         - The caller has the "manager" role
    ///         - The policy is locally active
    ///
    /// @param  dtParams_ The parameters for the debt token
    /// @param  aParams_  The parameters for the auction
    function auction(
        DebtTokenParams calldata dtParams_,
        AuctionParams calldata aParams_
    ) external;

    // ========== DEBT TOKEN ========== //

    /// @notice Creates a new convertible debt token
    /// @dev    The implementing function should ensure the following:
    ///         - The caller has the "manager" role
    ///         - The policy is locally active
    ///
    /// @param  asset_            The underlying asset for the debt token
    /// @param  maturity_         The maturity timestamp of the debt token
    /// @param  conversionPrice_  The price at which the debt token can be converted to the underlying asset. Amount of underlying to MGST in underlying decimals.
    /// @return debtToken         The address of the newly created debt token
    function createDebtToken(
        address asset_,
        uint48 maturity_,
        uint256 conversionPrice_
    ) external returns (address debtToken);

    /// @notice Issues convertible debt tokens to an address
    /// @dev    The implementing function should ensure the following:
    ///         - The caller has the "manager" role
    ///         - The policy is locally active
    ///
    /// @param  debtToken_  The address of the debt token to issue
    /// @param  to_         The address to issue the debt token to
    /// @param  amount_     The amount of debt tokens to issue
    function issue(address debtToken_, address to_, uint256 amount_) external;

    // ========== DEBT CONVERSION ========== //

    /// @notice Converts convertible debt tokens to the protocol token
    /// @dev    The implementing function should ensure the following:
    ///         - The policy is locally active
    ///
    /// @param  debtToken_  The address of the debt token to convert
    /// @param  amount_     The amount of debt tokens to convert
    function convert(address debtToken_, uint256 amount_) external;

    /// @notice Redeems convertible debt tokens for the underlying asset
    /// @dev    The implementing function should ensure the following:
    ///         - The policy is locally active
    ///
    /// @param  debtToken_  The address of the debt token to redeem
    /// @param  amount_     The amount of debt tokens to redeem
    function redeem(address debtToken_, uint256 amount_) external;

    // ========== HELPER FUNCTIONS ========== //

    /// @notice Get the converted amount of the protocol token for a given amount of debt tokens
    /// @dev    This function will revert if:
    ///         - The debt token was not created by this issuer
    ///
    /// @param  debtToken_      Address of the debt token
    /// @param  amount_         Amount of debt tokens to convert
    /// @return convertedAmount Amount of the protocol token that would be minted for the given amount of debt tokens
    function getConvertedAmount(
        address debtToken_,
        uint256 amount_
    ) external view returns (uint256);
}
