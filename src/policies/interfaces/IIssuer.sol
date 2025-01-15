// SPDX-License-Identifier: Unlicensed
pragma solidity >=0.8.0;

interface IIssuer {
    // ========== ERRORS ========== //

    error InvalidParam(string name);
    error Inactive();

    // ========== EVENTS ========== //

    // solhint-disable-next-line event-name-camelcase
    event oTokenCreated(address indexed oToken);
    // solhint-disable-next-line event-name-camelcase
    event oTokenIssued(address indexed oToken, address indexed to, uint256 amount);

    // ========== PROTOCOL TOKEN ========== //

    /// @notice Mint the protocol token to an address
    /// @dev    The implementing function should ensure the following:
    ///         - The caller has the "admin" role
    ///         - The policy is locally active
    function mint(address to_, uint256 amount_) external;

    // ========== OPTION TOKENS ========== //

    /// @notice Create an option token
    /// @dev    The implementing function should ensure the following:
    ///         - The caller has the "admin" role
    ///         - The policy is locally active
    ///
    /// @param quoteToken_          The token to quote the option in
    /// @param expiry_              The expiry timestamp of the option, in seconds
    /// @param convertiblePrice_    The price at which the option can be converted
    /// @return token               The address of the created oToken
    function createO(
        address quoteToken_,
        uint48 expiry_,
        uint256 convertiblePrice_
    ) external returns (address token);

    /// @notice Issue oTokens to an address
    /// @dev    The implementing function should ensure the following:
    ///         - The caller has the "admin" role
    ///         - The policy is locally active
    function issueO(address token_, address to_, uint256 amount_) external;
}
