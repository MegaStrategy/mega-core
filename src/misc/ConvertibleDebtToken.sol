// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.19;

import {ERC20} from "solmate-6.8.0/tokens/ERC20.sol";

contract ConvertibleDebtToken is ERC20 {
    // ========== ERRORS ========== //

    error NotAuthorized();
    error InvalidParam(string name);

    // ========== STATE ========== //

    address public immutable ISSUER;

    ERC20 public asset;
    uint48 public maturity;
    uint256 public conversionPrice;

    // ========== CONSTRUCTOR ========== //

    constructor(
        string memory name_,
        string memory symbol_,
        address asset_,
        uint48 maturity_,
        uint256 conversionPrice_
    ) ERC20(name_, symbol_, ERC20(asset_).decimals()) {
        // Validate the asset is not the zero address
        if (asset_ == address(0)) revert InvalidParam("asset");

        // Validate that the maturity is in the future
        if (maturity_ <= block.timestamp) revert InvalidParam("maturity");

        // Validate that the conversion price is not zero
        if (conversionPrice_ == 0) revert InvalidParam("conversionPrice");

        ISSUER = msg.sender;
        asset = ERC20(asset_);
        maturity = maturity_;
        conversionPrice = conversionPrice_;
    }

    // ========== MODIFIERS ========== //

    modifier onlyIssuer() {
        if (msg.sender != ISSUER) revert NotAuthorized();
        _;
    }

    // ========== MINT/BURN ========== //

    function mint(address to_, uint256 amount_) external onlyIssuer {
        _mint(to_, amount_);
    }

    function burnFrom(address from_, uint256 amount_) external onlyIssuer {
        _burn(from_, amount_);
    }

    function burn(
        uint256 amount_
    ) external {
        _burn(msg.sender, amount_);
    }

    // ========== VIEW FUNCTIONS ========== //

    function getTokenData()
        external
        view
        returns (ERC20 asset_, uint48 maturity_, uint256 conversionPrice_)
    {
        return (asset, maturity, conversionPrice);
    }
}
