// SPDX-License-Identifier: BSL-1.1
pragma solidity >=0.8.0;

import {ERC20} from "@solmate-6.8.0/tokens/ERC20.sol";
import {IOracle} from "morpho-blue-1.0.0/interfaces/IOracle.sol";

/// @title  ConvertibleDebtToken
/// @notice ERC20 token that represents debt convertible into an underlying asset.
/// @dev    The token is quite simple, and does not includes features for converting/redeeming the debt.
contract ConvertibleDebtToken is ERC20, IOracle {
    // ========== ERRORS ========== //

    error AlreadySet();
    error NotAuthorized();
    error InvalidParam(string name);

    // ========== EVENTS ========== //

    event ConversionPriceSet(uint256 conversionPrice);

    // ========== STATE ========== //

    /// @notice The issuer of the token.
    address public immutable ISSUER;

    /// @notice The underlying asset that the debt is in.
    ERC20 public underlying;

    /// @notice The asset being converted to.
    ERC20 public convertsTo;

    /// @notice The maturity of the token.
    uint48 public maturity;

    /// @notice The conversion price of the token expressed as the amount of `underlying` per `convertsTo`, in underlying decimals.
    /// @dev    A couple of examples help to clarify this value:
    ///         - If both `underlying` and `convertsTo` have 18 decimals and `underlying` is a stablecoin where 1 of `convertsTo` is worth 5 of `underlying`, then the conversion price is 5e18.
    ///         - If `underlying` has 6 decimals and `convertsTo` has 18 decimals and 1 of `convertsTo` is worth 5 of `underlying`, then the conversion price is 5e6.
    ///
    ///         It is noted that this approach limits the precision of the conversion price in situations where the underlying asset has a small number of decimals and a high value compared to the `convertsTo` asset.
    uint256 public conversionPrice;

    // ========== CONSTRUCTOR ========== //

    /// @notice Deploys the token contract.
    /// @dev    This function will revert if:
    ///         - The `asset_` is the zero address
    ///         - The `maturity_` is not in the future
    ///         - The `conversionPrice_` is zero
    ///         - The `issuer_` is the zero address
    ///
    /// @param  name_               The name of the token.
    /// @param  symbol_             The symbol of the token.
    /// @param  underlying_         The underlying asset that the debt is in.
    /// @param  convertsTo_         The asset being converted to.
    /// @param  maturity_           The maturity of the token.
    /// @param  conversionPrice_    The conversion price of the token.
    /// @param  issuer_             The issuer of the token.
    constructor(
        string memory name_,
        string memory symbol_,
        address underlying_,
        address convertsTo_,
        uint48 maturity_,
        uint256 conversionPrice_,
        address issuer_
    ) ERC20(name_, symbol_, ERC20(underlying_).decimals()) {
        // Validate the convertsTo asset is not the zero address
        if (convertsTo_ == address(0)) revert InvalidParam("convertsTo");

        // Validate the underlying asset is not the zero address
        if (underlying_ == address(0)) revert InvalidParam("underlying");

        // Validate that the maturity is in the future
        if (maturity_ <= block.timestamp) revert InvalidParam("maturity");

        // Validate that the issuer is not the zero address
        if (issuer_ == address(0)) revert InvalidParam("issuer");

        ISSUER = issuer_;
        underlying = ERC20(underlying_);
        convertsTo = ERC20(convertsTo_);
        maturity = maturity_;

        // Optionally, allow conversion price to be set after deployment
        // This is useful for creating tokens, auctioning them, and then setting the conversion price
        // based on the auction result (e.g. with a derivative value auction).
        if (conversionPrice_ != 0) {
            conversionPrice = conversionPrice_;
            emit ConversionPriceSet(conversionPrice_);
        }
    }

    // ========== MODIFIERS ========== //

    modifier onlyIssuer() {
        if (msg.sender != ISSUER) revert NotAuthorized();
        _;
    }

    // ========== MINT/BURN ========== //

    /// @notice Mints the token to the given address.
    /// @dev    Gated to the `ISSUER`.
    ///
    /// @param  to_     The address to mint the token to.
    /// @param  amount_ The amount of tokens to mint.
    function mint(address to_, uint256 amount_) external onlyIssuer {
        _mint(to_, amount_);
    }

    /// @notice Burns the token from the given address.
    /// @dev    This function will revert if:
    ///         - The caller is not the `ISSUER`
    ///         - The caller does not have sufficient spending allowance provided by the `from_` address
    ///
    /// @param  from_   The address to burn the token from.
    /// @param  amount_ The amount of tokens to burn.
    function burnFrom(address from_, uint256 amount_) external onlyIssuer {
        uint256 allowed = allowance[from_][msg.sender];

        if (allowed != type(uint256).max) allowance[from_][msg.sender] = allowed - amount_;

        _burn(from_, amount_);
    }

    /// @notice Burns the token from the caller.
    /// @dev    This function will revert if the caller does not have sufficient balance.
    ///         As this can only be called by the token holder themselves, it is not gated,
    ///         and does not require allowance checks.
    ///
    /// @param  amount_ The amount of tokens to burn.
    function burn(
        uint256 amount_
    ) external {
        _burn(msg.sender, amount_);
    }

    // ========== MANAGEMENT ========== //

    /// @notice Set the conversion price of the token.
    /// @dev    This function reverts if:
    ///         - The caller is not the `ISSUER`
    ///         - The conversion price has already been set
    ///         - The new conversion price is zero
    ///
    /// @param  conversionPrice_ The conversion price of the token.
    function setConversionPrice(
        uint256 conversionPrice_
    ) external onlyIssuer {
        // Validate that the conversion price has not been set
        // It can only be set once
        if (conversionPrice != 0) revert AlreadySet();

        // Validate that the new conversion price is not zero
        if (conversionPrice_ == 0) revert InvalidParam("conversionPrice");

        // Set the conversion price
        conversionPrice = conversionPrice_;

        // Emit the event
        emit ConversionPriceSet(conversionPrice_);
    }

    // ========== VIEW FUNCTIONS ========== //

    /// @notice Returns the token data.
    ///
    /// @return underlying_       The underlying asset that the debt is in.
    /// @return convertsTo_       The asset that can be converted to.
    /// @return maturity_         The maturity of the token.
    /// @return conversionPrice_  The conversion price of the token.
    function getTokenData()
        external
        view
        returns (ERC20 underlying_, ERC20 convertsTo_, uint48 maturity_, uint256 conversionPrice_)
    {
        return (underlying, convertsTo, maturity, conversionPrice);
    }

    /// @notice Price function for Morpho IOracle interface. Returns the price of 1 asset of collateral token quoted in 1 asset of loan token, scaled by 1e36.
    /// @dev    This function returns the hardcoded price in underlying terms in the format expected by Morpho.
    ///         It corresponds to the price of 10**(collateral token decimals) assets of collateral token quoted in
    ///         10**(loan token decimals) assets of loan token with `36 + loan token decimals - collateral token decimals`
    ///         decimals of precision.
    function price() external view override returns (uint256) {
        // The price of 1 unit of `underlying` in `convertsTo` is in the inverse of the conversion price
        // scaled to 36 decimals per the Morpho IOracle interface.
        return (1e36 * (10 ** convertsTo.decimals())) / conversionPrice;
    }
}
