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
import {MorphoLib} from "morpho-blue-1.0.0/libraries/periphery/MorphoLib.sol";
import {MorphoBalancesLib} from "morpho-blue-1.0.0/libraries/periphery/MorphoBalancesLib.sol";
import {SharesMathLib} from "morpho-blue-1.0.0/libraries/SharesMathLib.sol";

// Uniswap
import {ISwapRouter} from "src/lib/Uniswap/ISwapRouter.sol";

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
    IERC20 public immutable mgst;
    IERC20 public immutable weth;
    IERC20 public immutable reserve;

    // Morpho
    IMorpho public morpho;
    MorphoId public mgstMarket;
    mapping(address cvToken => MorphoId) public cvMarkets;

    // Uniswap
    ISwapRouter public swapRouter;

    // Operator approvals
    mapping(address user => mapping(address operator => bool)) public isAuthorized;

    // ========== CONSTRUCTOR ========== //

    constructor(
        address mgst_,
        address weth_,
        address reserve_,
        bytes32 mgstMarket_,
        address morpho_,
        address swapRouter_
    ) {
        // Ensure the addresses are not zero
        if (mgst_ == address(0)) revert InvalidParam("mgst");
        if (weth_ == address(0)) revert InvalidParam("weth");
        if (reserve_ == address(0)) revert InvalidParam("reserve");
        if (morpho_ == address(0)) revert InvalidParam("morpho");
        if (swapRouter_ == address(0)) revert InvalidParam("swapRouter");

        // Ensure the mgstMarket ID is not zero
        if (mgstMarket_ == bytes32(0)) revert InvalidParam("mgstMarket");

        // Get the morpho market params for the mgstMarket ID
        // Confirm that the tokens match
        MorphoParams memory marketParams = morpho.idToMarketParams(MorphoId.wrap(mgstMarket_));
        if (marketParams.collateralToken != mgst_) revert InvalidParam("mgstMarket");
        if (marketParams.loanToken != reserve_) revert InvalidParam("mgstMarket");

        // Store variables
        mgst = IERC20(mgst_);
        weth = IERC20(weth_);
        reserve = IERC20(reserve_);
        mgstMarket = MorphoId.wrap(mgstMarket_);
        morpho = IMorpho(morpho_);
        swapRouter = ISwapRouter(swapRouter_);
    }

    // ========== VALIDATION ========== //

    function getMarketId(
        address cvToken_
    ) internal view returns (MorphoId) {
        MorphoId cvMarket = cvMarkets[cvToken_];
        if (MorphoId.unwrap(cvMarket) == bytes32(0)) revert InvalidParam("cvToken");
        return cvMarket;
    }

    modifier onlyApprovedOperator(address user_, address operator_) {
        if (user_ != operator_ && !isAuthorized[user_][operator_]) revert NotAuthorized();
        _;
    }

    // ========== USER ACTIONS ========== //

    /// @dev User must approve this contract to spend the amount of cvToken
    function deposit(address cvToken_, uint256 amount_) external {
        MorphoId cvMarket = getMarketId(cvToken_);

        // Supply the collateral to the morpho market
        _supplyCollateral(cvMarket, amount_, msg.sender);
    }

    function depositAndHedge(
        address cvToken_,
        uint256 amount_,
        uint256 hedgeAmount_,
        uint256 minReserveOut_
    ) external {
        MorphoId cvMarket = getMarketId(cvToken_);

        // Supply the collateral to the morpho market
        _supplyCollateral(cvMarket, amount_, msg.sender);

        // Increase the hedge position
        _increaseHedge(cvMarket, hedgeAmount_, msg.sender, minReserveOut_);
    }

    function increaseHedge(
        address cvToken_,
        uint256 hedgeAmount_,
        uint256 minReserveOut_
    ) external {
        MorphoId cvMarket = getMarketId(cvToken_);

        // Increase the hedge position
        _increaseHedge(cvMarket, hedgeAmount_, msg.sender, minReserveOut_);
    }

    function decreaseHedge(
        address cvToken_,
        uint256 reserveToSupply_,
        uint256 reserveFromMorpho_,
        uint256 minMgstOut_
    ) external {
        MorphoId cvMarket = getMarketId(cvToken_);

        // Transfer the external amount of reserves to this contract, if necessary
        if (reserveToSupply_ > 0) {
            reserve.safeTransferFrom(msg.sender, address(this), reserveToSupply_);
        }

        // Decrease the hedge position
        _decreaseHedge(cvMarket, reserveToSupply_, reserveFromMorpho_, msg.sender, minMgstOut_);
    }

    function unwindAndWithdraw(
        address cvToken_,
        uint256 amount_,
        uint256 reserveToSupply_,
        uint256 reserveFromMorpho_,
        uint256 minMgstOut_
    ) external {
        MorphoId cvMarket = getMarketId(cvToken_);

        // Transfer the external amount of reserves to this contract, if necessary
        if (reserveToSupply_ > 0) {
            reserve.safeTransferFrom(msg.sender, address(this), reserveToSupply_);
        }

        // Decrease the hedge position, if necessary
        _decreaseHedge(cvMarket, reserveToSupply_, reserveFromMorpho_, msg.sender, minMgstOut_);

        // Withdraw the collateral from the morpho market
        _withdrawCollateral(cvMarket, amount_, msg.sender);
    }

    // TODO can we assume the reserve amounts that are needed based on the user's position? (need to use the balance lib)
    function unwindAndWithdrawAll(
        address cvToken_,
        uint256 reserveToSupply_,
        uint256 reserveFromMorpho_,
        uint256 minMgstOut_
    ) external {
        MorphoId cvMarket = getMarketId(cvToken_);

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

    function withdraw(address cvToken_, uint256 amount_) external {
        MorphoId cvMarket = getMarketId(cvToken_);

        // Withdraw the collateral from the morpho market
        _withdrawCollateral(cvMarket, amount_, msg.sender);
    }

    function withdrawAll(
        address cvToken_
    ) external {
        MorphoId cvMarket = getMarketId(cvToken_);

        // Get the user's deposited balance of cvToken in the morpho market
        MorphoPosition memory position = morpho.position(cvMarket, msg.sender);

        // Withdraw all the collateral from the morpho market
        _withdrawCollateral(cvMarket, position.collateral, msg.sender);
    }

    function withdrawReserves(
        uint256 amount_
    ) external {
        _withdrawReserves(amount_, msg.sender);
    }

    // ========== DELEGATION ========== //

    function setOperatorStatus(address operator_, bool status_) external {
        isAuthorized[msg.sender][operator_] = status_;
    }

    // ========== DELEGATED ACTIONS ========== //

    function deposit(address cvToken_, uint256 amount_, address onBehalfOf_) external {
        // doesn't require only approved operator to donate tokens to user
        MorphoId cvMarket = getMarketId(cvToken_);

        // Supply the collateral to the morpho market
        _supplyCollateral(cvMarket, amount_, onBehalfOf_);
    }

    function depositAndHedge(
        address cvToken_,
        uint256 amount_,
        uint256 mgstAmount_,
        uint256 minReserveOut_,
        address onBehalfOf_
    ) external onlyApprovedOperator(onBehalfOf_, msg.sender) {
        MorphoId cvMarket = getMarketId(cvToken_);

        // Supply the collateral to the morpho market
        _supplyCollateral(cvMarket, amount_, onBehalfOf_);

        // Increase the hedge position
        _increaseHedge(cvMarket, mgstAmount_, onBehalfOf_, minReserveOut_);
    }

    function increaseHedge(
        address cvToken_,
        uint256 mgstAmount_,
        uint256 minReserveOut_,
        address onBehalfOf_
    ) external onlyApprovedOperator(onBehalfOf_, msg.sender) {
        MorphoId cvMarket = getMarketId(cvToken_);

        // Increase the hedge position
        _increaseHedge(cvMarket, mgstAmount_, onBehalfOf_, minReserveOut_);
    }

    function decreaseHedge(
        address cvToken_,
        uint256 reserveToSupply_,
        uint256 reserveFromMorpho_,
        uint256 minMgstOut_,
        address onBehalfOf_
    ) external onlyApprovedOperator(onBehalfOf_, msg.sender) {
        MorphoId cvMarket = getMarketId(cvToken_);

        // Transfer the external amount of reserves to this contract, if necessary
        if (reserveToSupply_ > 0) {
            reserve.safeTransferFrom(onBehalfOf_, address(this), reserveToSupply_);
        }

        // Decrease the hedge position
        _decreaseHedge(cvMarket, reserveToSupply_, reserveFromMorpho_, onBehalfOf_, minMgstOut_);
    }

    function unwindAndWithdraw(
        address cvToken_,
        uint256 amount_,
        uint256 reserveToSupply_,
        uint256 reserveFromMorpho_,
        uint256 minMgstOut_,
        address onBehalfOf_
    ) external onlyApprovedOperator(onBehalfOf_, msg.sender) {
        MorphoId cvMarket = getMarketId(cvToken_);

        // Decrease the hedge position, if necessary
        _decreaseHedge(cvMarket, reserveToSupply_, reserveFromMorpho_, onBehalfOf_, minMgstOut_);

        // Withdraw the collateral from the morpho market
        _withdrawCollateral(cvMarket, amount_, onBehalfOf_);
    }

    // TODO can we assume the reserve amounts that are needed based on the user's position? (need to use the balance lib)
    function unwindAndWithdrawAll(
        address cvToken_,
        uint256 reserveToSupply_,
        uint256 reserveFromMorpho_,
        uint256 minMgstOut_,
        address onBehalfOf_
    ) external onlyApprovedOperator(onBehalfOf_, msg.sender) {
        MorphoId cvMarket = getMarketId(cvToken_);

        // Decrease the hedge position
        _decreaseHedge(cvMarket, reserveToSupply_, reserveFromMorpho_, onBehalfOf_, minMgstOut_);

        // Get the user's deposited balance of cvToken in the morpho market
        MorphoPosition memory position = morpho.position(cvMarket, onBehalfOf_);

        // Withdraw all the collateral from the morpho market
        _withdrawCollateral(cvMarket, position.collateral, onBehalfOf_);
    }

    function withdraw(
        address cvToken_,
        uint256 amount_,
        address onBehalfOf_
    ) external onlyApprovedOperator(onBehalfOf_, msg.sender) {
        MorphoId cvMarket = getMarketId(cvToken_);

        // Withdraw the collateral from the morpho market
        _withdrawCollateral(cvMarket, amount_, onBehalfOf_);
    }

    function withdrawAll(
        address cvToken_,
        address onBehalfOf_
    ) external onlyApprovedOperator(onBehalfOf_, msg.sender) {
        MorphoId cvMarket = getMarketId(cvToken_);

        // Get the user's deposited balance of cvToken in the morpho market
        MorphoPosition memory position = morpho.position(cvMarket, onBehalfOf_);

        // Withdraw all the collateral from the morpho market
        _withdrawCollateral(cvMarket, position.collateral, onBehalfOf_);
    }

    function withdrawReserves(
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
        // The router expects the path in reverse order
        // TODO how to handle the fees that are hard-coded here?
        ISwapRouter.ExactInputParams memory params = ISwapRouter.ExactInputParams({
            path: abi.encodePacked(reserve, uint24(500), weth, uint24(3000), mgst),
            recipient: msg.sender,
            deadline: block.timestamp,
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
        // TODO how to handle the fees that are hard-coded here?
        ISwapRouter.ExactInputParams memory params = ISwapRouter.ExactInputParams({
            path: abi.encodePacked(mgst, uint24(3000), weth, uint24(500), reserve),
            recipient: msg.sender,
            deadline: block.timestamp,
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

    function addCvToken(address cvToken_, bytes32 cvMarket_) external onlyOwner {
        // Ensure the cvToken is not zero
        if (cvToken_ == address(0)) revert InvalidParam("cvToken");

        // Ensure the cvMarket ID is not zero
        if (cvMarket_ == bytes32(0)) revert InvalidParam("cvMarket");

        // Get the morpho market params for the cvMarket ID
        // Confirm that the tokens match
        MorphoId cvMarket = MorphoId.wrap(cvMarket_);
        MorphoParams memory marketParams = morpho.idToMarketParams(cvMarket);
        if (marketParams.collateralToken != cvToken_) revert InvalidParam("cvMarket");
        if (marketParams.loanToken != address(mgst)) revert InvalidParam("cvMarket");

        // Store the cvMarket ID
        cvMarkets[cvToken_] = cvMarket;
    }
}
