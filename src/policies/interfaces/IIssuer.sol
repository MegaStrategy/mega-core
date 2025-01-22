// SPDX-License-Identifier: Unlicensed
pragma solidity >=0.8.0;

interface IIssuer {
    // ========== ERRORS ========== //

    error InvalidParam(string name);
    error Inactive();

    // ========== EVENTS ========== //

    // solhint-disable-next-line event-name-camelcase
    event oTokenCreated(address indexed oToken, address indexed vestingToken);
    // solhint-disable-next-line event-name-camelcase
    event oTokenIssued(
        address indexed oToken, address indexed vestingToken, address indexed to, uint256 amount
    );
    event oTokenReclaimed(address indexed oToken, uint256 amount);

    // ========== PROTOCOL TOKEN ========== //

    /// @notice Mint the protocol token to an address
    /// @dev    The implementing function should ensure the following:
    ///         - The caller has the "admin" role
    ///         - The policy is locally active
    ///
    ///         The implementing function should perform the following:
    ///         - Mint the protocol token to the recipient
    ///         - Emit an event
    ///
    /// @param  to_     The address to mint the protocol token to
    /// @param  amount_ The amount of protocol token to mint
    function mint(address to_, uint256 amount_) external;

    // ========== OPTION TOKENS ========== //

    /// @notice Create an option token with optional vesting
    /// @dev    The implementing function should ensure the following:
    ///         - The caller has the "admin" role
    ///         - The policy is locally active
    ///
    ///         The implementing function should perform the following:
    ///         - Create the oToken on the teller
    ///         - Mark the oToken as created by this contract
    ///         - Create a vesting token if vesting parameters are provided
    ///         - Emit an event
    ///
    /// @param  quoteToken_         The token to quote the option in
    /// @param  expiry_             The expiry timestamp of the option, in seconds
    /// @param  convertiblePrice_   The price at which the option can be converted
    /// @param  vestingStart_       The start timestamp of the vesting, in seconds (0 if not vesting)
    /// @param  vestingExpiry_      The expiry timestamp of the vesting, in seconds (0 if not vesting)
    /// @return token               The address of the created oToken
    function createO(
        address quoteToken_,
        uint48 expiry_,
        uint256 convertiblePrice_,
        uint48 vestingStart_,
        uint48 vestingExpiry_
    ) external returns (address token);

    /// @notice Issue oTokens to an address
    /// @dev    The implementing function should ensure the following:
    ///         - The caller has the "admin" role
    ///         - The policy is locally active
    ///         - Validate the oToken was created by this contract
    ///         - Validate the `to_` address is not zero
    ///         - Validate the `amount_` is greater than zero
    ///
    ///         The implementing function should perform the following:
    ///         - Mint the oToken
    ///         - Wrap the oToken into the vesting token, if enabled
    ///         - Send the oToken/vesting oToken to the recipient
    ///         - Emit an event
    ///
    /// @param  token_  The address of the oToken
    /// @param  to_     The address to issue the oToken to
    /// @param  amount_ The amount of oToken to issue
    function issueO(address token_, address to_, uint256 amount_) external;

    /// @notice Reclaim expired oTokens
    /// @dev    The implementing function should ensure the following:
    ///         - The caller has the "admin" role
    ///         - The policy is locally active
    ///
    ///         The implementing function should perform the following:
    ///         - Validate the oToken was created by this contract
    ///         - Reclaim the oToken from the teller
    ///         - Transfer proceeds to the treasury
    ///         - Burn any protocol tokens that were reclaimed
    ///         - Emit an event
    ///
    /// @param  token_  The address of the oToken
    function reclaimO(
        address token_
    ) external;
}
