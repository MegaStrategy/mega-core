// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.19;

import "src/Kernel.sol";

// Modules
import {TRSRYv1} from "src/modules/TRSRY/TRSRY.v1.sol";
import {TOKENv1} from "src/modules/TOKEN/TOKEN.v1.sol";
import {ROLESv1, RolesConsumer} from "src/modules/ROLES/OlympusRoles.sol";

// Other Local
import {oToken} from "src/misc/oToken.sol";

import {ERC20} from "solmate-6.8.0/tokens/ERC20.sol";
import {Timestamp} from "axis-core-1.0.1/lib/Timestamp.sol";

contract Issuer is Policy, RolesConsumer {
    using Timestamp for uint48;

    // ========== ERRORS ========== //

    error InvalidParam(string name);
    error oTokenExpired();

    // ========== EVENTS ========== //

    event oTokenCreated(address indexed oToken, uint48 expiry, uint256 convertiblePrice);

    // ========== STATE ========== //

    // Modules
    TRSRYv1 internal TRSRY;
    TOKENv1 internal TOKEN;
    uint8 internal _tokenDecimals;

    // Local state
    bool public active;

    /// @notice whether the option token was issued by this contract
    mapping(address => bool) public createdBy;

    // ========= POLICY SETUP ========= //

    constructor(
        Kernel kernel_
    ) Policy(kernel_) {}

    /// @inheritdoc Policy
    function configureDependencies() external override returns (Keycode[] memory dependencies) {
        dependencies = new Keycode[](2);
        dependencies[0] = toKeycode("TRSRY");
        dependencies[1] = toKeycode("TOKEN");
        dependencies[2] = toKeycode("ROLES");

        TRSRY = TRSRYv1(getModuleAddress(dependencies[0]));
        TOKEN = TOKENv1(getModuleAddress(dependencies[1]));
        ROLES = ROLESv1(getModuleAddress(dependencies[2]));

        _tokenDecimals = TOKEN.decimals();
    }

    /// @inheritdoc Policy
    function requestPermissions() external view override returns (Permissions[] memory permissions) {
        Keycode TOKEN_KEYCODE = TOKEN.KEYCODE();

        permissions = new Permissions[](3);
        permissions[0] = Permissions(TOKEN_KEYCODE, TOKENv1.mint.selector);
        permissions[1] = Permissions(TOKEN_KEYCODE, TOKENv1.increaseMintApproval.selector);
        permissions[2] = Permissions(TOKEN_KEYCODE, TOKENv1.decreaseMintApproval.selector);
    }

    // ========= MINT ========= //

    /// @notice Mint MSTR to an address
    /// @param to_ Address to mint to
    /// @param amount_ Amount to mint
    function mint(address to_, uint256 amount_) external onlyRole("admin") {
        // Increase mint allowance by provided amount
        TOKEN.increaseMintApproval(address(this), amount_);

        // Mint the MSTR
        TOKEN.mint(to_, amount_);
    }

    // ========== oTokens ========= //

    function createO(
        address quoteToken_,
        uint48 expiry_,
        uint256 convertiblePrice_
    ) external onlyRole("admin") returns (address token) {
        // Create oToken
        // Expiry and convertible price are validated in the token constructor
        (string memory name, string memory symbol) = _computeNameAndSymbol(address(TOKEN), expiry_);

        token = address(
            new oToken(name, symbol, address(TOKEN), quoteToken_, expiry_, convertiblePrice_)
        );

        // Mark the oToken as created by this contract
        createdBy[token] = true;

        // Emit event
        emit oTokenCreated(token, expiry_, convertiblePrice_);
    }

    function issueO(address token_, address to_, uint256 amount_) external onlyRole("admin") {
        // Validate that the oToken was created by this contract
        if (!createdBy[token_]) revert InvalidParam("token");

        // Mint the oToken
        oToken(token_).mint(to_, amount_);
    }

    function convertO(address token_, uint256 amount_) external {
        // Validate that the oToken was created by this contract
        if (!createdBy[token_]) revert InvalidParam("token");

        // Get token data
        (, ERC20 quoteToken, uint48 expiry, uint256 convertiblePrice) =
            oToken(token_).getTokenData();

        // Validate that the oToken has not expired
        if (expiry <= block.timestamp) revert oTokenExpired();

        // Calculate the amount of quote token required
        uint256 quoteAmount = amount_ * convertiblePrice / 10 ** _tokenDecimals;

        // Transfer the quote token from the caller to the treasury
        // Requires approval to transfer
        quoteToken.transferFrom(msg.sender, address(TRSRY), quoteAmount);

        // Burn the oToken from the caller
        // Requires approval to burn
        oToken(token_).burnFrom(msg.sender, amount_);

        // Mint TOKEN to the caller
        TOKEN.mint(msg.sender, amount_);
    }

    /// @notice     Computes the name and symbol of an oToken
    ///
    /// @param      asset_      The address of the underlying token
    /// @param      expiry_     The timestamp at which the option expires
    /// @return     string      The name of the oToken
    /// @return     string      The symbol of the oToken
    function _computeNameAndSymbol(
        address asset_,
        uint48 expiry_
    ) internal view returns (string memory, string memory) {
        // Get the date components
        (string memory year, string memory month, string memory day) = expiry_.toPaddedString();

        return (
            string(abi.encodePacked(ERC20(asset_).name(), " C ", year, "-", month, "-", day)),
            string(abi.encodePacked("o", ERC20(asset_).symbol()))
        );
    }
}
