// SPDX-License-Identifier: TBD
pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin-contracts-4.9.6/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin-contracts-4.9.6/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin-contracts-4.9.6/access/Ownable.sol";

// Morpho
import {
    IMorpho,
    MarketParams as MorphoParams,
    Id as MorphoId,
    Position as MorphoPosition
} from "morpho-blue-1.0.0/interfaces/IMorpho.sol";

// Uniswap
import {ISwapRouter02} from "src/lib/Uniswap/ISwapRouter02.sol";

/// @title  Hedger
/// @notice The Hedger is a contract that allows users to hedge a cvToken against the protocol token using a morpho market and a swap router.
contract Hedger is Ownable {
    using SafeERC20 for IERC20;

    // Requirements
    // The purpose of this contract is to provide a way to hedge a cvToken
    // against the protocol token using a morpho market and a swap router.
    // It allows users to:
    // [X] Deposit cvToken into the morpho market
    // [X] Enter/increase a hedge position
    // [X] Exit/decrease a hedge position
    // [X] Withdraw cvToken from the morpho market
    // [X] Add/Remove operator(s) to manage their position(s) on their behalf.
    // It is specifically non-custodial. All morpho market positions are created
    // with the user's address as the owner.
    // It supports managing positions for any cvToken<>MGST morpho market.

    // ========== ERRORS ========== //

    error InvalidParam(string name);
    error NotAuthorized();

    // ========== STATE VARIABLES ========== //

    // Tokens
    // solhint-disable immutable-vars-naming
    IERC20 public immutable mgst;
    IERC20 public immutable weth;
    IERC20 public immutable reserve;
    // solhint-enable immutable-vars-naming

    // Morpho
    IMorpho public morpho;
    MorphoId public mgstMarket;
    mapping(address cvToken => MorphoId) public cvMarkets;

    // Uniswap
    ISwapRouter02 public swapRouter;
    uint24 public reserveWethSwapFee;
    uint24 public mgstWethSwapFee;

    // Operator approvals
    mapping(address user => mapping(address operator => bool)) public isAuthorized;

    // ========== CONSTRUCTOR ========== //

    constructor(
        address mgst_,
        address weth_,
        address reserve_,
        bytes32 mgstMarket_,
        address morpho_,
        address swapRouter_,
        uint24 reserveWethSwapFee_,
        uint24 mgstWethSwapFee_
    ) {
        // Ensure the addresses are not zero
        if (mgst_ == address(0)) revert InvalidParam("mgst");
        if (weth_ == address(0)) revert InvalidParam("weth");
        if (reserve_ == address(0)) revert InvalidParam("reserve");
        if (morpho_ == address(0)) revert InvalidParam("morpho");
        if (swapRouter_ == address(0)) revert InvalidParam("swapRouter");

        // Ensure the mgstMarket ID is not zero
        if (mgstMarket_ == bytes32(0)) revert InvalidParam("mgstMarket id");

        // Ensure the swap fees are not zero
        if (reserveWethSwapFee_ == 0) revert InvalidParam("reserveWethSwapFee");
        if (mgstWethSwapFee_ == 0) revert InvalidParam("mgstWethSwapFee");

        // Store variables
        mgst = IERC20(mgst_);
        weth = IERC20(weth_);
        reserve = IERC20(reserve_);
        mgstMarket = MorphoId.wrap(mgstMarket_);
        morpho = IMorpho(morpho_);
        swapRouter = ISwapRouter02(swapRouter_);
        reserveWethSwapFee = reserveWethSwapFee_;
        mgstWethSwapFee = mgstWethSwapFee_;

        // Get the morpho market params for the mgstMarket ID
        // Confirm that the tokens match
        MorphoParams memory marketParams = morpho.idToMarketParams(MorphoId.wrap(mgstMarket_));
        if (marketParams.collateralToken != mgst_) revert InvalidParam("mgstMarket collateral");
        if (marketParams.loanToken != reserve_) revert InvalidParam("mgstMarket loan");
    }

    // ========== VALIDATION ========== //

    function _getMarketId(
        address cvToken_
    ) internal view returns (MorphoId) {
        MorphoId cvMarket = cvMarkets[cvToken_];
        if (MorphoId.unwrap(cvMarket) == bytes32(0)) revert InvalidParam("cvToken");
        return cvMarket;
    }

    // ========== MODIFIERS ========== //

    /// @notice Ensures that the caller is an approved operator for the user
    /// @dev    If the caller is the user, the modifier does nothing
    modifier onlyApprovedOperator(address user_, address operator_) {
        if (user_ != operator_ && !isAuthorized[user_][operator_]) revert NotAuthorized();
        _;
    }

    // ========== USER ACTIONS ========== //

    /// @notice Deposits a user's cvToken into the Morpho market
    /// @dev    This function performs the following:
    ///         - Performs validation checks
    ///         - Transfers the cvToken from the user to this contract
    ///         - Deposits the cvToken into the Morpho market
    ///
    ///         This function reverts if:
    ///         - `amount_` is zero
    ///         - `cvToken_` does not have a whitelisted Morpho market
    ///         - The caller has not approved this contract to spend `cvToken_`
    ///
    /// @param  cvToken_ The address of the cvToken to deposit
    /// @param  amount_  The amount of cvToken to deposit
    function deposit(address cvToken_, uint256 amount_) external {
        MorphoId cvMarket = _getMarketId(cvToken_);

        // Supply the collateral to the morpho market
        _supplyCollateral(cvMarket, amount_, msg.sender);
    }

    /// @notice Deposits a user's cvToken into the Morpho market and hedges it
    /// @dev    This function is a combination of `deposit()` and `increaseHedge()`, and performs the same validation and operations.
    ///
    /// @param  cvToken_       The address of the cvToken to deposit
    /// @param  amount_        The amount of cvToken to deposit
    /// @param  hedgeAmount_   The amount of MGST to borrow
    /// @param  minReserveOut_ The minimum amount of reserve token to receive (akin to a slippage parameter)
    function depositAndHedge(
        address cvToken_,
        uint256 amount_,
        uint256 hedgeAmount_,
        uint256 minReserveOut_
    ) external {
        MorphoId cvMarket = _getMarketId(cvToken_);

        // Supply the collateral to the morpho market
        _supplyCollateral(cvMarket, amount_, msg.sender);

        // Increase the hedge position
        _increaseHedge(cvMarket, hedgeAmount_, msg.sender, minReserveOut_);
    }

    /// @notice Increases a user's hedge position
    /// @dev    This function performs the following:
    ///         - Performs validation checks
    ///         - Borrows the hedge amount of MGST on behalf of the user
    ///         - Swaps the borrowed MGST for the reserve token
    ///         - Supplies the reserve token into the Morpho market
    ///
    ///         This function reverts if:
    ///         - `hedgeAmount_` is zero
    ///         - `cvToken_` does not have a whitelisted Morpho market
    ///         - The caller has not approved this contract to manage the Morpho position (using `setAuthorization()`)
    ///
    /// @param  cvToken_       The address of the cvToken to hedge
    /// @param  hedgeAmount_  The amount of MGST to borrow
    /// @param  minReserveOut_ The minimum amount of reserve token to receive (akin to a slippage parameter)
    function increaseHedge(
        address cvToken_,
        uint256 hedgeAmount_,
        uint256 minReserveOut_
    ) external {
        MorphoId cvMarket = _getMarketId(cvToken_);

        // Increase the hedge position
        _increaseHedge(cvMarket, hedgeAmount_, msg.sender, minReserveOut_);
    }

    /// @notice Decreases a user's hedge position, utilising reserves from the user or the Morpho market
    /// @dev    This function performs the following:
    ///         - Performs validation checks
    ///         - Transfers the reserve token to this contract, if `reserveToSupply_` is greater than zero
    ///         - Withdraws the reserve token from the Morpho market, if `reserveFromMorpho_` is greater than zero
    ///         - Swaps the reserve token for MGST
    ///         - Repays the MGST to the Morpho market
    ///
    ///         This function reverts if:
    ///         - `cvToken_` does not have a whitelisted Morpho market
    ///         - The caller has not approved this contract to spend the reserve token
    ///         - The caller has not approved this contract to manage the Morpho position (using `setAuthorization()`)
    ///         - Both `reserveToSupply_` and `reserveFromMorpho_` are zero
    ///
    /// @param  cvToken_           The address of the cvToken to hedge
    /// @param  reserveToSupply_   The amount of reserve token to supply to the morpho market
    /// @param  reserveFromMorpho_ The amount of reserve token to withdraw from the morpho market
    /// @param  minMgstOut_        The minimum amount of MGST to receive (akin to a slippage parameter)
    function decreaseHedge(
        address cvToken_,
        uint256 reserveToSupply_,
        uint256 reserveFromMorpho_,
        uint256 minMgstOut_
    ) external {
        MorphoId cvMarket = _getMarketId(cvToken_);

        // Transfer the external amount of reserves to this contract, if necessary
        if (reserveToSupply_ > 0) {
            reserve.safeTransferFrom(msg.sender, address(this), reserveToSupply_);
        }

        // Decrease the hedge position
        _decreaseHedge(cvMarket, reserveToSupply_, reserveFromMorpho_, msg.sender, minMgstOut_);
    }

    /// @notice Unwinds the caller's hedge position and withdraws the collateral to the caller
    /// @dev    This function performs the following:
    ///         - Performs validation checks
    ///         - Transfers the reserve token to this contract, if `reserveToSupply_` is greater than zero
    ///         - Withdraws the reserve token from the Morpho market, if `reserveFromMorpho_` is greater than zero
    ///         - Swaps the reserve token for MGST
    ///         - Repays the MGST to the Morpho market
    ///         - Withdraws the collateral from the morpho market
    ///
    ///         This function reverts if:
    ///         - `cvToken_` does not have a whitelisted Morpho market
    ///         - The caller has not approved this contract to spend the reserve token
    ///         - The caller has not approved this contract to manage the Morpho position (using `setAuthorization()`)
    ///         - Both `reserveToSupply_` and `reserveFromMorpho_` are zero
    ///
    /// @param  cvToken_           The address of the cvToken to hedge
    /// @param  amount_            The amount of cvToken to withdraw
    /// @param  reserveToSupply_   The amount of reserve token to supply to the morpho market
    /// @param  reserveFromMorpho_ The amount of reserve token to withdraw from the morpho market
    /// @param  minMgstOut_        The minimum amount of MGST to receive (akin to a slippage parameter)
    function unwindAndWithdraw(
        address cvToken_,
        uint256 amount_,
        uint256 reserveToSupply_,
        uint256 reserveFromMorpho_,
        uint256 minMgstOut_
    ) external {
        MorphoId cvMarket = _getMarketId(cvToken_);

        // Transfer the external amount of reserves to this contract, if necessary
        if (reserveToSupply_ > 0) {
            reserve.safeTransferFrom(msg.sender, address(this), reserveToSupply_);
        }

        // Decrease the hedge position, if necessary
        _decreaseHedge(cvMarket, reserveToSupply_, reserveFromMorpho_, msg.sender, minMgstOut_);

        // Withdraw the collateral from the morpho market
        _withdrawCollateral(cvMarket, amount_, msg.sender);
    }

    /// @notice Unwinds the caller's hedge position and withdraws all of the collateral to the caller
    /// @dev    This function performs the same operations as `unwindAndWithdraw()`, but for all of the user's collateral
    ///
    ///         This function reverts if:
    ///         - `cvToken_` does not have a whitelisted Morpho market
    ///         - The caller has not approved this contract to spend the reserve token
    ///         - The caller has not approved this contract to manage the Morpho position (using `setAuthorization()`)
    ///         - Both `reserveToSupply_` and `reserveFromMorpho_` are zero
    ///
    /// @param  cvToken_           The address of the cvToken to hedge
    /// @param  reserveToSupply_   The amount of reserve token to supply to the morpho market
    /// @param  reserveFromMorpho_ The amount of reserve token to withdraw from the morpho market
    /// @param  minMgstOut_        The minimum amount of MGST to receive (akin to a slippage parameter)
    function unwindAndWithdrawAll(
        address cvToken_,
        uint256 reserveToSupply_,
        uint256 reserveFromMorpho_,
        uint256 minMgstOut_
    ) external {
        MorphoId cvMarket = _getMarketId(cvToken_);

        // Transfer the external amount of reserves to this contract, if necessary
        if (reserveToSupply_ > 0) {
            reserve.safeTransferFrom(msg.sender, address(this), reserveToSupply_);
        }

        // Decrease the hedge position, if necessary
        _decreaseHedge(cvMarket, reserveToSupply_, reserveFromMorpho_, msg.sender, minMgstOut_);

        // Get the user's deposited balance of cvToken in the morpho market
        MorphoPosition memory position = morpho.position(cvMarket, msg.sender);

        // Withdraw all the collateral from the morpho market
        _withdrawCollateral(cvMarket, position.collateral, msg.sender);
    }

    /// @notice Withdraws the caller's collateral from the Morpho market
    /// @dev    This function performs the following:
    ///         - Performs validation checks
    ///         - Withdraws the collateral from the Morpho market
    ///
    ///         This function reverts if:
    ///         - `cvToken_` does not have a whitelisted Morpho market
    ///         - `amount_` is zero
    ///         - The caller has not approved this contract to manage the Morpho position (using `setAuthorization()`)
    ///
    /// @param  cvToken_ The address of the cvToken to withdraw
    /// @param  amount_  The amount of cvToken to withdraw
    function withdraw(address cvToken_, uint256 amount_) external {
        MorphoId cvMarket = _getMarketId(cvToken_);

        // Withdraw the collateral from the morpho market
        _withdrawCollateral(cvMarket, amount_, msg.sender);
    }

    /// @notice Withdraws all of the caller's collateral from the Morpho market
    /// @dev    This function performs the following:
    ///         - Performs validation checks
    ///         - Withdraws all of the collateral from the Morpho market
    ///
    ///         This function reverts if:
    ///         - `cvToken_` does not have a whitelisted Morpho market
    ///         - The caller has not approved this contract to manage the Morpho position (using `setAuthorization()`)
    ///
    /// @param  cvToken_ The address of the cvToken to withdraw
    function withdrawAll(
        address cvToken_
    ) external {
        MorphoId cvMarket = _getMarketId(cvToken_);

        // Get the user's deposited balance of cvToken in the morpho market
        MorphoPosition memory position = morpho.position(cvMarket, msg.sender);

        // Withdraw all the collateral from the morpho market
        _withdrawCollateral(cvMarket, position.collateral, msg.sender);
    }

    /// @notice Withdraws the caller's reserves from the MGST<>RESERVE market
    /// @dev    This function performs the following:
    ///         - Performs validation checks
    ///         - Withdraws the reserves from the MGST<>RESERVE market
    ///
    ///         This function reverts if:
    ///         - `amount_` is zero
    ///         - The caller has not approved this contract to manage the Morpho position (using `setAuthorization()`)
    ///
    /// @param  amount_ The amount of reserves to withdraw
    function withdrawReserves(
        uint256 amount_
    ) external {
        _withdrawReserves(amount_, msg.sender);
    }

    // ========== DELEGATION ========== //

    /// @notice Allows the caller to enable or disable an operator's ability to perform actions on behalf of the caller
    ///
    /// @param  operator_ The address of the operator
    /// @param  status_   True if enabled
    function setOperatorStatus(address operator_, bool status_) external {
        isAuthorized[msg.sender][operator_] = status_;
    }

    // ========== DELEGATED ACTIONS ========== //

    /// @notice Deposits a user's cvToken into the Morpho market
    /// @dev    This function performs the same operations as `deposit()`, but for a specific user (`onBehalfOf_`).
    ///         This function does not require the caller to be an approved operator for the user (`onBehalfOf_`), so that tokens can be donated to the user.
    ///
    ///         This function reverts if:
    ///         - `cvToken_` does not have a whitelisted Morpho market
    ///         - The caller has not approved this contract to spend `cvToken_`
    ///
    /// @param  cvToken_   The address of the cvToken to deposit
    /// @param  amount_    The amount of cvToken to deposit
    /// @param  onBehalfOf_ The address of the user to perform the operation for
    function depositFor(address cvToken_, uint256 amount_, address onBehalfOf_) external {
        // doesn't require only approved operator to donate tokens to user
        MorphoId cvMarket = _getMarketId(cvToken_);

        // Supply the collateral to the morpho market
        _supplyCollateral(cvMarket, amount_, onBehalfOf_);
    }

    /// @notice Deposits a user's cvToken into the Morpho market and hedges it
    /// @dev    This function performs the same operations as `depositAndHedge()`, but for a specific user (`onBehalfOf_`)
    ///
    ///         This function reverts if:
    ///         - `cvToken_` does not have a whitelisted Morpho market
    ///         - The user (`onBehalfOf_`) has not approved this contract to spend `cvToken_`
    ///         - The caller is not an approved operator for the user (`onBehalfOf_`)
    ///         - The user has not approved this contract to manage the Morpho position (using `setAuthorization()`)
    ///
    /// @param  cvToken_       The address of the cvToken to deposit
    /// @param  amount_        The amount of cvToken to deposit
    /// @param  mgstAmount_    The amount of MGST to borrow
    /// @param  minReserveOut_ The minimum amount of reserve token to receive (akin to a slippage parameter)
    /// @param  onBehalfOf_    The address of the user to perform the operation for
    function depositAndHedgeFor(
        address cvToken_,
        uint256 amount_,
        uint256 mgstAmount_,
        uint256 minReserveOut_,
        address onBehalfOf_
    ) external onlyApprovedOperator(onBehalfOf_, msg.sender) {
        MorphoId cvMarket = _getMarketId(cvToken_);

        // Supply the collateral to the morpho market
        _supplyCollateral(cvMarket, amount_, onBehalfOf_);

        // Increase the hedge position
        _increaseHedge(cvMarket, mgstAmount_, onBehalfOf_, minReserveOut_);
    }

    /// @notice Increases a user's hedge position
    /// @dev    This function performs the same operations as `increaseHedge()`, but for a specific user (`onBehalfOf_`)
    ///
    ///         This function reverts if:
    ///         - `cvToken_` does not have a whitelisted Morpho market
    ///         - The user has not approved this contract to manage the Morpho position (using `setAuthorization()`)
    ///
    /// @param  cvToken_       The address of the cvToken to hedge
    /// @param  mgstAmount_    The amount of MGST to borrow
    /// @param  minReserveOut_ The minimum amount of reserve token to receive (akin to a slippage parameter)
    /// @param  onBehalfOf_    The address of the user to perform the operation for
    function increaseHedgeFor(
        address cvToken_,
        uint256 mgstAmount_,
        uint256 minReserveOut_,
        address onBehalfOf_
    ) external onlyApprovedOperator(onBehalfOf_, msg.sender) {
        MorphoId cvMarket = _getMarketId(cvToken_);

        // Increase the hedge position
        _increaseHedge(cvMarket, mgstAmount_, onBehalfOf_, minReserveOut_);
    }

    /// @notice Decreases a user's hedge position, utilising reserves from the user or the Morpho market
    /// @dev    This function performs the same operations as `decreaseHedge()`, but for a specific user (`onBehalfOf_`)
    ///
    ///         This function reverts if:
    ///         - `cvToken_` does not have a whitelisted Morpho market
    ///         - The user (`onBehalfOf_`) has not approved this contract to spend the reserve token
    ///         - The user has not approved this contract to manage the Morpho position (using `setAuthorization()`)
    ///         - Both `reserveToSupply_` and `reserveFromMorpho_` are zero
    ///
    /// @param  cvToken_           The address of the cvToken to hedge
    /// @param  reserveToSupply_   The amount of reserve token to supply to the morpho market
    /// @param  reserveFromMorpho_ The amount of reserve token to withdraw from the morpho market
    /// @param  minMgstOut_        The minimum amount of MGST to receive (akin to a slippage parameter)
    /// @param  onBehalfOf_        The address of the user to perform the operation on behalf of
    function decreaseHedgeFor(
        address cvToken_,
        uint256 reserveToSupply_,
        uint256 reserveFromMorpho_,
        uint256 minMgstOut_,
        address onBehalfOf_
    ) external onlyApprovedOperator(onBehalfOf_, msg.sender) {
        MorphoId cvMarket = _getMarketId(cvToken_);

        // Transfer the external amount of reserves to this contract, if necessary
        if (reserveToSupply_ > 0) {
            reserve.safeTransferFrom(onBehalfOf_, address(this), reserveToSupply_);
        }

        // Decrease the hedge position
        _decreaseHedge(cvMarket, reserveToSupply_, reserveFromMorpho_, onBehalfOf_, minMgstOut_);
    }

    /// @notice Unwinds a user's hedge position and withdraws the collateral to the user
    /// @dev    This function performs the same operations as `unwindAndWithdraw()`, but for a specific user (`onBehalfOf_`)
    ///
    ///         This function reverts if:
    ///         - `cvToken_` does not have a whitelisted Morpho market
    ///         - The user (`onBehalfOf_`) has not approved this contract to spend the reserve token
    ///         - The user has not approved this contract to manage the Morpho position (using `setAuthorization()`)
    ///         - The caller is not an approved operator for the user (`onBehalfOf_`)
    ///
    /// @param  cvToken_           The address of the cvToken to hedge
    /// @param  amount_            The amount of cvToken to withdraw
    /// @param  reserveToSupply_   The amount of reserve token to supply to the morpho market
    /// @param  reserveFromMorpho_ The amount of reserve token to withdraw from the morpho market
    /// @param  minMgstOut_        The minimum amount of MGST to receive (akin to a slippage parameter)
    /// @param  onBehalfOf_        The address of the user to perform the operation for
    function unwindAndWithdrawFor(
        address cvToken_,
        uint256 amount_,
        uint256 reserveToSupply_,
        uint256 reserveFromMorpho_,
        uint256 minMgstOut_,
        address onBehalfOf_
    ) external onlyApprovedOperator(onBehalfOf_, msg.sender) {
        MorphoId cvMarket = _getMarketId(cvToken_);

        // Decrease the hedge position, if necessary
        _decreaseHedge(cvMarket, reserveToSupply_, reserveFromMorpho_, onBehalfOf_, minMgstOut_);

        // Withdraw the collateral from the morpho market
        _withdrawCollateral(cvMarket, amount_, onBehalfOf_);
    }

    // TODO can we assume the reserve amounts that are needed based on the user's position? (need to use the balance lib)

    /// @notice Unwinds a user's hedge position and withdraws all of the collateral to the user
    /// @dev    This function performs the same operations as `unwindAndWithdrawAll()`, but for a specific user (`onBehalfOf_`)
    ///
    ///         This function reverts if:
    ///         - `cvToken_` does not have a whitelisted Morpho market
    ///         - The user (`onBehalfOf_`) has not approved this contract to spend the reserve token
    ///         - The user has not approved this contract to manage the Morpho position (using `setAuthorization()`)
    ///         - The caller is not an approved operator for the user (`onBehalfOf_`)
    ///
    /// @param  cvToken_           The address of the cvToken to hedge
    /// @param  reserveToSupply_   The amount of reserve token to supply to the morpho market
    /// @param  reserveFromMorpho_ The amount of reserve token to withdraw from the morpho market
    /// @param  minMgstOut_        The minimum amount of MGST to receive (akin to a slippage parameter)
    /// @param  onBehalfOf_        The address of the user to perform the operation for
    function unwindAndWithdrawAllFor(
        address cvToken_,
        uint256 reserveToSupply_,
        uint256 reserveFromMorpho_,
        uint256 minMgstOut_,
        address onBehalfOf_
    ) external onlyApprovedOperator(onBehalfOf_, msg.sender) {
        MorphoId cvMarket = _getMarketId(cvToken_);

        // Decrease the hedge position
        _decreaseHedge(cvMarket, reserveToSupply_, reserveFromMorpho_, onBehalfOf_, minMgstOut_);

        // Get the user's deposited balance of cvToken in the morpho market
        MorphoPosition memory position = morpho.position(cvMarket, onBehalfOf_);

        // Withdraw all the collateral from the morpho market
        _withdrawCollateral(cvMarket, position.collateral, onBehalfOf_);
    }

    /// @notice Withdraws a user's collateral from the Morpho market
    /// @dev    This function performs the same operations as `withdraw()`, but for a specific user (`onBehalfOf_`)
    ///
    ///         This function reverts if:
    ///         - `cvToken_` does not have a whitelisted Morpho market
    ///         - The caller is not an approved operator for the user (`onBehalfOf_`)
    ///         - The user has not approved this contract to manage the Morpho position (using `setAuthorization()`)
    ///
    /// @param  cvToken_   The address of the cvToken to withdraw
    /// @param  amount_    The amount of cvToken to withdraw
    /// @param  onBehalfOf_ The address of the user to perform the operation for
    function withdrawFor(
        address cvToken_,
        uint256 amount_,
        address onBehalfOf_
    ) external onlyApprovedOperator(onBehalfOf_, msg.sender) {
        MorphoId cvMarket = _getMarketId(cvToken_);

        // Withdraw the collateral from the morpho market
        _withdrawCollateral(cvMarket, amount_, onBehalfOf_);
    }

    /// @notice Withdraws all of a user's collateral from the Morpho market
    /// @dev    This function performs the same operations as `withdrawAll()`, but for a specific user (`onBehalfOf_`)
    ///
    ///         This function reverts if:
    ///         - `cvToken_` does not have a whitelisted Morpho market
    ///         - The caller is not an approved operator for the user (`onBehalfOf_`)
    ///         - The user has not approved this contract to manage the Morpho position (using `setAuthorization()`)
    ///
    /// @param  cvToken_   The address of the cvToken to withdraw
    /// @param  onBehalfOf_ The address of the user to perform the operation for
    function withdrawAllFor(
        address cvToken_,
        address onBehalfOf_
    ) external onlyApprovedOperator(onBehalfOf_, msg.sender) {
        MorphoId cvMarket = _getMarketId(cvToken_);

        // Get the user's deposited balance of cvToken in the morpho market
        MorphoPosition memory position = morpho.position(cvMarket, onBehalfOf_);

        // Withdraw all the collateral from the morpho market
        _withdrawCollateral(cvMarket, position.collateral, onBehalfOf_);
    }

    /// @notice Withdraws a user's reserves from the MGST<>RESERVE market
    /// @dev    This function performs the same operations as `withdrawReserves()`, but for a specific user (`onBehalfOf_`)
    ///
    ///         This function reverts if:
    ///         - The caller is not an approved operator for the user (`onBehalfOf_`)
    ///         - The user has not approved this contract to manage the Morpho position (using `setAuthorization()`)
    ///
    /// @param  amount_      The amount of reserves to withdraw
    /// @param  onBehalfOf_  The address of the user to perform the operation for
    function withdrawReservesFor(
        uint256 amount_,
        address onBehalfOf_
    ) external onlyApprovedOperator(onBehalfOf_, msg.sender) {
        _withdrawReserves(amount_, onBehalfOf_);
    }

    // ========== INTERNAL OPERATIONS ========== //

    function _supplyCollateral(MorphoId cvMarket_, uint256 amount_, address onBehalfOf_) internal {
        // Validate the amount is not zero
        if (amount_ == 0) revert InvalidParam("amount");

        // Get the morpho market params
        MorphoParams memory marketParams = morpho.idToMarketParams(cvMarket_);

        // Transfer the cvToken to this contract
        IERC20(marketParams.collateralToken).safeTransferFrom(msg.sender, address(this), amount_);

        // Approve the morpho market to spend the cvToken
        IERC20(marketParams.collateralToken).safeApprove(address(morpho), amount_);

        // Deposit the cvToken into the morpho market
        morpho.supplyCollateral(
            marketParams, // marketParams
            amount_, // assets
            onBehalfOf_, // onBehalfOf
            bytes("") // data (not used)
        );
    }

    function _withdrawCollateral(
        MorphoId cvMarket_,
        uint256 amount_,
        address onBehalfOf_
    ) internal {
        // Validate the amount is not zero
        if (amount_ == 0) revert InvalidParam("amount");

        // Get the morpho market params
        MorphoParams memory marketParams = morpho.idToMarketParams(cvMarket_);

        // Withdraw the cvToken from the morpho market
        morpho.withdrawCollateral(
            marketParams, // marketParams
            amount_, // assets
            onBehalfOf_, // onBehalfOf
            onBehalfOf_ // receiver
        );
    }

    function _increaseHedge(
        MorphoId cvMarket_,
        uint256 hedgeAmount_,
        address onBehalfOf_,
        uint256 minReserveOut_
    ) internal {
        // Increasing a hedge means borrowing more MGST and swapping it for the reserve token

        // Validate the hedge amount is not zero
        if (hedgeAmount_ == 0) revert InvalidParam("hedgeAmount");

        // Get the morpho market params
        MorphoParams memory marketParams = morpho.idToMarketParams(cvMarket_);

        // Try to borrow the hedge amount on behalf of the user
        (uint256 mgstBorrowed,) = morpho.borrow(
            marketParams, // marketParams
            hedgeAmount_, // assets
            0, // shares (not used)
            onBehalfOf_, // onBehalfOf
            address(this) // receiver (this contract receives this intermediate balance)
        );

        // Swap the MGST for the reserve token

        // Approve the swap router to spend the MGST
        mgst.safeApprove(address(swapRouter), mgstBorrowed);

        // Specify a two-hop path for the swap: MGST -> WETH -> RESERVE
        // The router expects the path in forward order since this is an exactInput swap
        ISwapRouter02.ExactInputParams memory params = ISwapRouter02.ExactInputParams({
            path: abi.encodePacked(
                address(mgst), mgstWethSwapFee, address(weth), reserveWethSwapFee, address(reserve)
            ),
            recipient: address(this), // this contract receives since it's an intermediate step
            amountIn: mgstBorrowed,
            amountOutMinimum: minReserveOut_
        });

        // Execute the swap
        uint256 reserveReceived = swapRouter.exactInput(params);

        // Get the morpho market params
        marketParams = morpho.idToMarketParams(mgstMarket);

        // Deposit the reserves into the morpho market
        morpho.supply(
            marketParams, // marketParams
            reserveReceived, // assets
            0, // shares (not used)
            onBehalfOf_, // onBehalfOf
            bytes("") // data (not used)
        );
    }

    function _decreaseHedge(
        MorphoId cvMarket_,
        uint256 externalReserves_,
        uint256 reservesToWithdraw_,
        address onBehalfOf_,
        uint256 minMgstOut_
    ) internal {
        // Decreasing a hedge means swapping the reserve token for MGST and repaying the loan
        // 1. if necessary, withdraw reserves from the MGST<>RESERVE morpho market
        // 2. swap the reserve token for MGST
        // 3. repay the loan

        // Check if we need to withdraw reserves from morpho
        MorphoParams memory marketParams;
        uint256 reservesWithdrawn;
        if (reservesToWithdraw_ > 0) {
            // Get the morpho market params
            marketParams = morpho.idToMarketParams(mgstMarket);

            // Withdraw the reserves from the MGST<>RESERVE morpho market
            (reservesWithdrawn,) = morpho.withdraw(
                marketParams, // marketParams
                reservesToWithdraw_, // assets
                0, // shares (not used)
                onBehalfOf_, // onBehalfOf
                address(this) // receiver (this contract receives this intermediate balance)
            );
        }

        // Total reserves should not be zero
        if (externalReserves_ + reservesWithdrawn == 0) revert InvalidParam("reserves");

        // Swap the reserves for MGST

        // Specify a two-hop path for the swap: RESERVE -> WETH -> MGST
        // The router expects the path in reverse order
        ISwapRouter02.ExactInputParams memory params = ISwapRouter02.ExactInputParams({
            path: abi.encodePacked(
                address(mgst), mgstWethSwapFee, address(weth), reserveWethSwapFee, address(reserve)
            ),
            recipient: address(this), // this contract receives since it's an intermediate step
            amountIn: externalReserves_ + reservesWithdrawn,
            amountOutMinimum: minMgstOut_
        });

        // Execute the swap
        uint256 mgstReceived = swapRouter.exactInput(params);

        // Repay the MGST to the morpho market
        marketParams = morpho.idToMarketParams(cvMarket_);

        // Approve the morpho market to spend the MGST
        mgst.safeApprove(address(morpho), mgstReceived);

        // Repay the loan
        morpho.repay(
            marketParams, // marketParams
            mgstReceived, // assets
            0, // shares (not used)
            onBehalfOf_, // onBehalfOf
            bytes("") // data (not used)
        );

        // Transfer the remaining reserves to the user
        uint256 excessReserves = reserve.balanceOf(address(this));
        if (excessReserves > 0) reserve.safeTransfer(onBehalfOf_, excessReserves);
    }

    /// @dev Withdraws reserves from the MGST<>RESERVE market
    function _withdrawReserves(uint256 amount_, address onBehalfOf_) internal {
        // Validate the amount is not zero
        if (amount_ == 0) revert InvalidParam("amount");

        // Get the morpho market params
        MorphoParams memory marketParams = morpho.idToMarketParams(mgstMarket);

        // Withdraw the reserves from the MGST<>RESERVE morpho market
        // Send them directly to the user
        morpho.withdraw(
            marketParams, // marketParams
            amount_, // assets
            0, // shares (not used)
            onBehalfOf_, // onBehalfOf
            onBehalfOf_ // receiver
        );
    }

    // ========== ADMIN ========== //

    /// @notice Adds a cvToken and its corresponding Morpho market ID to the whitelist
    /// @dev    This function reverts if:
    ///         - The caller is not the owner
    ///         - The cvToken is zero
    ///         - The cvMarket ID is zero
    ///         - The cvMarket ID does not correspond to the cvToken
    ///         - The cvMarket ID does not correspond to the MGST<>RESERVE morpho market
    ///
    /// @param  cvToken_   The address of the cvToken to add
    /// @param  cvMarket_  The Morpho market ID of the cvToken
    function addCvToken(address cvToken_, bytes32 cvMarket_) external onlyOwner {
        // Ensure the cvToken is not zero
        if (cvToken_ == address(0)) revert InvalidParam("cvToken");

        // Ensure the cvMarket ID is not zero
        if (cvMarket_ == bytes32(0)) revert InvalidParam("cvMarket");

        // Get the morpho market params for the cvMarket ID
        // Confirm that the tokens match
        MorphoId cvMarket = MorphoId.wrap(cvMarket_);
        MorphoParams memory marketParams = morpho.idToMarketParams(cvMarket);
        if (marketParams.collateralToken != cvToken_) revert InvalidParam("collateral");
        if (marketParams.loanToken != address(mgst)) revert InvalidParam("loan");

        // Store the cvMarket ID
        cvMarkets[cvToken_] = cvMarket;
    }

    function setReserveWethSwapFee(
        uint24 reserveWethSwapFee_
    ) external onlyOwner {
        if (reserveWethSwapFee_ == 0) revert InvalidParam("reserveWethSwapFee");

        reserveWethSwapFee = reserveWethSwapFee_;
    }

    function setMgstWethSwapFee(
        uint24 mgstWethSwapFee_
    ) external onlyOwner {
        if (mgstWethSwapFee_ == 0) revert InvalidParam("mgstWethSwapFee");

        mgstWethSwapFee = mgstWethSwapFee_;
    }
}
