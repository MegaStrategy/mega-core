// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.19;

import {ERC20} from "solmate-6.8.0/tokens/ERC20.sol";

contract oToken is ERC20 {
    // ========== ERRORS ========== //

    error NotAuthorized();
    error InvalidParam(string name);

    // ========== STATE ========== //

    address public immutable ISSUER;

    ERC20 public baseToken;
    ERC20 public quoteToken;
    uint48 public expiry;
    uint256 public convertiblePrice;

    // ========== CONSTRUCTOR ========== //

    constructor(
        string memory name_,
        string memory symbol_,
        address baseToken_,
        address quoteToken_,
        uint48 expiry_,
        uint256 convertiblePrice_
    ) ERC20(name_, symbol_, ERC20(baseToken_).decimals()) {
        // If baseAsset does not implement decimals, then the function will revert
        // Therefore, we don't need to check if it's the zero address

        // Validate the quote asset is not the zero address
        if (quoteToken_ == address(0)) revert InvalidParam("quoteToken");

        // Validate that the expiry is in the future
        if (expiry_ <= block.timestamp) revert InvalidParam("expiry");

        // Validate that the strike price is not zero
        if (convertiblePrice_ == 0) revert InvalidParam("convertiblePrice");

        ISSUER = msg.sender;
        baseToken = ERC20(baseToken_);
        quoteToken = ERC20(quoteToken_);
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
        uint256 allowed = allowance[from_][msg.sender];

        if (allowed != type(uint256).max) allowance[from_][msg.sender] = allowed - amount_;

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
        returns (ERC20 baseToken_, ERC20 quoteToken_, uint48 expiry_, uint256 convertiblePrice_)
    {
        return (baseToken, quoteToken, expiry, convertiblePrice);
    }
}
