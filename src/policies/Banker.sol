// SPDX-License-Identifier: TBD
pragma solidity 0.8.19;

// Axis dependencies
import {BaseCallback, Callbacks} from "axis-core-1.0.1/bases/BaseCallback.sol";
import {IAuctionHouse, IAuction} from "axis-core-1.0.1/interfaces/IAuctionHouse.sol";
import {IFeeManager} from "axis-core-1.0.1/interfaces/IFeeManager.sol";
import {IEncryptedMarginalPrice} from
    "axis-core-1.0.1/interfaces/modules/auctions/IEncryptedMarginalPrice.sol";
import {toKeycode as toAxisKeycode} from "axis-core-1.0.1/modules/Keycode.sol";

import {Kernel, Policy, Keycode, toKeycode, Permissions} from "src/Kernel.sol";

// Modules
import {TRSRYv1} from "src/modules/TRSRY/TRSRY.v1.sol";
import {TOKENv1} from "src/modules/TOKEN/TOKEN.v1.sol";
import {ROLESv1, RolesConsumer} from "src/modules/ROLES/OlympusRoles.sol";

// Other Local
import {ConvertibleDebtToken} from "src/lib/ConvertibleDebtToken.sol";
import {uint2str} from "src/lib/Uint2Str.sol";

// External
import {ERC20} from "solmate-6.8.0/tokens/ERC20.sol";
import {TransferHelper} from "src/lib/TransferHelper.sol";

import {IBanker} from "./interfaces/IBanker.sol";

/// @title  Banker
/// @notice Policy that launches EMP-style auctions to sell convertible debt tokens
contract Banker is Policy, RolesConsumer, BaseCallback, IBanker {
    using TransferHelper for ERC20;

    // ========== STATE ========== //

    // Modules
    TRSRYv1 internal TRSRY;
    TOKENv1 internal TOKEN;
    uint8 internal _tokenDecimals;

    // Local state
    bool public locallyActive;

    // Auction parameters
    uint48 internal constant ONE_HUNDRED_PERCENT = 100e2;
    uint48 public maxDiscount;
    uint24 public minFillPercent;
    uint48 public referrerFee;
    uint256 public maxBids;

    /// @notice Mapping of CDTs created by this contract
    mapping(address cdt => bool) public createdBy;

    /// @notice Series counter for each underlying asset
    mapping(address underlying => uint256 series) public seriesCounter;

    /// @notice CDT address lookup using underlying asset and series number
    mapping(address underlying => mapping(uint256 series => address cdt)) public cdts;

    // ========== SETUP ========== //

    // Uses callback permissions 11100111, so must be prefixed with 0xE7
    constructor(
        Kernel kernel_,
        address auctionHouse_
    )
        Policy(kernel_)
        BaseCallback(
            auctionHouse_,
            Callbacks.Permissions({
                onCreate: true,
                onCancel: true,
                onCurate: true,
                onPurchase: false,
                onBid: false,
                onSettle: true,
                receiveQuoteTokens: true,
                sendBaseTokens: true
            })
        )
    {}

    /// @inheritdoc Policy
    function configureDependencies() external override returns (Keycode[] memory dependencies) {
        dependencies = new Keycode[](3);
        dependencies[0] = toKeycode("TRSRY");
        dependencies[1] = toKeycode("TOKEN");
        dependencies[2] = toKeycode("ROLES");

        TRSRY = TRSRYv1(getModuleAddress(dependencies[0]));
        TOKEN = TOKENv1(getModuleAddress(dependencies[1]));
        ROLES = ROLESv1(getModuleAddress(dependencies[2]));

        _tokenDecimals = TOKEN.decimals();
    }

    /// @inheritdoc Policy
    function requestPermissions()
        external
        view
        override
        returns (Permissions[] memory permissions)
    {
        Keycode TRSRY_KEYCODE = TRSRY.KEYCODE();
        Keycode TOKEN_KEYCODE = TOKEN.KEYCODE();

        permissions = new Permissions[](6);
        permissions[0] = Permissions(TRSRY_KEYCODE, TRSRYv1.withdrawReserves.selector);
        permissions[1] = Permissions(TRSRY_KEYCODE, TRSRYv1.increaseWithdrawApproval.selector);
        permissions[2] = Permissions(TRSRY_KEYCODE, TRSRYv1.decreaseWithdrawApproval.selector);
        permissions[3] = Permissions(TOKEN_KEYCODE, TOKENv1.mint.selector);
        permissions[4] = Permissions(TOKEN_KEYCODE, TOKENv1.increaseMintApproval.selector);
        permissions[5] = Permissions(TOKEN_KEYCODE, TOKENv1.decreaseMintApproval.selector);
    }

    // ========== INITIALIZATION ========== //

    function initialize(
        uint48 maxDiscount_,
        uint24 minFillPercent_,
        uint48 referrerFee_,
        uint256 maxBids_
    ) external onlyRole("admin") {
        locallyActive = true;

        maxDiscount = maxDiscount_;
        minFillPercent = minFillPercent_;
        referrerFee = referrerFee_;
        maxBids = maxBids_;
    }

    function shutdown() external onlyRole("admin") {
        locallyActive = false;
    }

    modifier onlyWhileActive() {
        if (!locallyActive) revert Inactive();
        _;
    }

    // ========== AUCTION ========== //

    /// @inheritdoc IBanker
    function auction(
        DebtTokenParams calldata dtParams_,
        AuctionParams calldata aParams_
    ) external override onlyRole("manager") onlyWhileActive {
        // Inputs are validated when creating the debt token and launching the auction

        // Create debt token
        address debtToken = _createDebtToken(dtParams_);

        // Get the number of decimals for the underlying asset and calculate the min price
        uint8 decimals = ERC20(dtParams_.underlying).decimals();
        // Calculate the min price for the debt token
        // Round up to be conservative
        uint256 minPrice =
            mulDivUp(10 ** decimals, ONE_HUNDRED_PERCENT - maxDiscount, ONE_HUNDRED_PERCENT);

        // Calculate min bid size from max bids
        // Round up to be conservative
        uint256 minBidSize = mulDivUp(minPrice, aParams_.capacity, maxBids * 10 ** decimals);

        // Create auction for debt token
        bytes memory implParams = abi.encode(
            IEncryptedMarginalPrice.AuctionDataParams({
                minPrice: minPrice,
                minFillPercent: minFillPercent,
                minBidSize: minBidSize,
                publicKey: aParams_.auctionPublicKey
            })
        );

        IAuction.AuctionParams memory auctionParams = IAuction.AuctionParams({
            start: aParams_.start,
            duration: aParams_.duration,
            capacityInQuote: false,
            capacity: aParams_.capacity,
            implParams: implParams
        });

        IAuctionHouse.RoutingParams memory routingParams = IAuctionHouse.RoutingParams({
            auctionType: toAxisKeycode("EMPA"),
            baseToken: debtToken,
            quoteToken: dtParams_.underlying,
            curator: address(this),
            referrerFee: referrerFee,
            callbacks: this,
            callbackData: bytes(""),
            derivativeType: toAxisKeycode(""),
            derivativeParams: bytes(""),
            wrapDerivative: false
        });

        uint96 lotId =
            IAuctionHouse(AUCTION_HOUSE).auction(routingParams, auctionParams, aParams_.infoHash);

        // Curate the auction so that it can be confirmed off-chain as being originated by this contract
        // The contract has no curator fee so it doesn't affect the outcome
        IAuctionHouse(AUCTION_HOUSE).curate(lotId, bytes(""));

        // Emit event
        emit DebtAuction(lotId);
    }

    // ========== CALLBACKS ========== //

    /// @inheritdoc BaseCallback
    function _onCreate(
        uint96,
        address seller_,
        address baseToken_,
        address,
        uint256 capacity_,
        bool prefund_,
        bytes calldata
    ) internal override {
        // Lot ID is validated by the higher-level function

        // Validate that the seller is this contract
        if (seller_ != address(this)) revert OnlyLocal();

        // Prefund should be true since this is a batch auction
        if (!prefund_) revert InvalidParam("prefund");

        // Issue the debt to the auction house to sell
        // This function validates additional parameters
        _issue(baseToken_, msg.sender, capacity_, false);
    }

    /// @inheritdoc BaseCallback
    function _onCancel(uint96 lotId_, uint256 refund_, bool, bytes calldata) internal override {
        // Lot ID is validated by the higher level function

        // Get the base token for the lot
        (, address baseToken,,,,,,,) = IAuctionHouse(AUCTION_HOUSE).lotRouting(lotId_);

        // Burn the refunded amount of debt tokens on this contract
        ConvertibleDebtToken(baseToken).burn(refund_);
    }

    /// @inheritdoc BaseCallback
    /// @dev        Not implemented
    ///             This implicitly means that curator fees are not supported, as the AuctionHouse
    ///             will revert if the curator fee is set and the curator fees are not sent.
    function _onCurate(uint96, uint256, bool, bytes calldata) internal override {}

    /// @inheritdoc BaseCallback
    /// @dev        Not implemented
    function _onPurchase(
        uint96,
        address,
        uint256,
        uint256,
        bool,
        bytes calldata
    ) internal override {}

    /// @inheritdoc BaseCallback
    /// @dev        Not implemented
    function _onBid(uint96, uint64, address, uint256, bytes calldata) internal override {}

    /// @inheritdoc BaseCallback
    /// @dev        Not implemented
    function _onSettle(
        uint96 lotId_,
        uint256 proceeds_,
        uint256 refund_,
        bytes calldata
    ) internal override {
        // Lot ID is validated by the higher level function

        // Get the base token for the lot
        (, address baseToken, address quoteToken,,,,,,) =
            IAuctionHouse(AUCTION_HOUSE).lotRouting(lotId_);

        // Burn the refund
        ConvertibleDebtToken(baseToken).burn(refund_);

        // Send the proceeds to the treasury
        // The proceeds are sent here by the auction house
        // because the receiveQuoteTokens flag is set for the callback
        // We allow the admin to configure a savings vault to deposit
        // the proceeds into prior to sending to the treasury (e.g. sUSDS for USDS)
        ERC20(quoteToken).safeTransfer(address(TRSRY), proceeds_);

        emit AuctionSucceeded(baseToken, refund_, quoteToken, proceeds_);
    }

    // ========== FACTORY ========== //

    /// @inheritdoc IBanker
    function createDebtToken(
        address asset_,
        uint48 maturity_,
        uint256 conversionPrice_
    ) external override onlyRole("manager") onlyWhileActive returns (address) {
        return _createDebtToken(DebtTokenParams(asset_, maturity_, conversionPrice_));
    }

    function _createDebtToken(
        DebtTokenParams memory dtParams_
    ) internal returns (address debtToken) {
        // Need to validate that the conversion price is non-zero
        // This contract does not need to set the conversion price later
        // so we ensure it is set initially
        if (dtParams_.conversionPrice == 0) revert InvalidParam("conversionPrice");

        // Get the series for the debt token
        // Increment first to start at 1
        uint256 series = ++seriesCounter[dtParams_.underlying];

        // Get the name and symbol for the debt token
        // This is based on the series for the underlying asset
        (string memory name, string memory symbol) =
            _computeNameAndSymbol(dtParams_.underlying, series);

        // Create the debt token
        debtToken = address(
            new ConvertibleDebtToken(
                name,
                symbol,
                dtParams_.underlying,
                address(TOKEN),
                dtParams_.maturity,
                dtParams_.conversionPrice,
                address(this) // issuer is this contract
            )
        );

        // Mark the debt token as created by this contract and store the address
        createdBy[debtToken] = true;
        cdts[dtParams_.underlying][series] = debtToken;

        // Emit an event
        emit ConvertibleDebtTokenCreated(
            debtToken,
            dtParams_.underlying,
            address(TOKEN),
            dtParams_.maturity,
            dtParams_.conversionPrice
        );

        return debtToken;
    }

    // ========== ISSUANCE =========== //

    /// @inheritdoc IBanker
    /// @dev        This function will perform the following:
    ///             - Transfer the underlying asset from the recipient to the treasury
    ///             - Issue the debt tokens to the recipient
    function issue(
        address debtToken_,
        address to_,
        uint256 amount_
    ) external override onlyRole("manager") onlyWhileActive {
        // Issue the debt tokens
        _issue(debtToken_, to_, amount_, true);
    }

    /// @notice Issues debt tokens to a recipient
    function _issue(
        address debtToken_,
        address to_,
        uint256 amount,
        bool transferUnderlying_
    ) internal {
        // Validate that the debt token was created by this issuer
        if (!createdBy[debtToken_]) revert InvalidDebtToken();
        ConvertibleDebtToken debtToken = ConvertibleDebtToken(debtToken_);

        // Check that the amount is not zero
        if (amount == 0) revert InvalidParam("amount");

        // Get the particulars from the debt token
        (ERC20 underlying,, uint48 maturity, uint256 conversionPrice) = debtToken.getTokenData();

        // Validate that the debt token has not matured
        if (block.timestamp >= maturity) revert DebtTokenMatured();

        // If needed, transfer the underlying asset from the recipient to the treasury
        if (transferUnderlying_) {
            underlying.safeTransferFrom(to_, address(TRSRY), amount);
        }

        // Increase this contract's withdrawal approval for the underlying asset by the amount issued
        // This is to ensure that the debt token can be redeemed
        TRSRY.increaseWithdrawApproval(address(this), underlying, amount);

        // Increase this contract's mint approval for the amount divided by the conversion rate
        // This is to ensure that the debt token can be converted
        // This is rounded up, to avoid a situation where the conversion is not possible
        uint256 mintAmount = _getConvertedAmount(amount, conversionPrice, true);
        TOKEN.increaseMintApproval(address(this), mintAmount);

        // Mint the debt tokens to the recipient
        debtToken.mint(to_, amount);

        // Emit an event
        emit DebtIssued(debtToken_, to_, amount);
    }

    // ========== SETTLEMENT =========== //

    // This version is currently a FCFS model
    // Consider a different format, even though would be a lot more complicated
    // This version also assumes that repayment funds sit in the TRSRY
    // until the user redeems them.
    // Therefore, there isn't a notion of calling a loan and repaying it early
    // If the system wants to do this, it simply gets the right balance
    // and leaves it in the treasury until the funds are pulled to burn the
    // debt tokens.
    // If we do want to allow for early paybacks (and thus loss of the conversion
    // option earlier than expected), we would need to offer the holders something
    // more in return. This adds complexity and probably isn't worth it
    // for the first version.
    // On the other hand, it can be useful to have "repaid" the debt from
    // an accounting standpoint so that more policy levers are available.
    // For example, in order to do buy backs of the token below the backing
    // value, we need to have paid back all outstanding debts so as to not
    // increase credit risk by exchanging reserves for tokens.

    /// @inheritdoc IBanker
    function redeem(address debtToken_, uint256 amount_) external onlyWhileActive {
        // Validate that the debt token was created by this issuer
        if (!createdBy[debtToken_]) revert InvalidDebtToken();
        ConvertibleDebtToken debtToken = ConvertibleDebtToken(debtToken_);

        // Get the particulars from the debt token
        (ERC20 underlying,, uint48 maturity, uint256 conversionPrice) = debtToken.getTokenData();

        // Check that the debt token has matured, otherwise revert
        if (block.timestamp < maturity) revert DebtTokenNotMatured();

        // Check that the amount is not zero
        if (amount_ == 0) revert InvalidParam("amount");

        // Burn the debt tokens from the sender
        // Requires approval from the sender
        debtToken.burnFrom(msg.sender, amount_);

        // Transfer the underlying asset to the sender from the TRSRY
        TRSRY.withdrawReserves(msg.sender, underlying, amount_);

        // Calculate the amount of tokens that could have been minted against the debt tokens
        uint256 mintAmount = _getConvertedAmount(amount_, conversionPrice, false);

        // Decrease the mint approval for the mint amount
        // We do this since the debt token has been burned to avoid an extra dangling mint allowance
        TOKEN.decreaseMintApproval(address(this), mintAmount);

        // Emit an event
        emit DebtRepaid(debtToken_, msg.sender, amount_);
    }

    /// @inheritdoc IBanker
    function convert(address debtToken_, uint256 amount_) external override onlyWhileActive {
        // Validate the debt token was created by this issuer
        if (!createdBy[debtToken_]) revert InvalidDebtToken();
        ConvertibleDebtToken debtToken = ConvertibleDebtToken(debtToken_);

        // Check that the amount is not zero
        if (amount_ == 0) revert InvalidParam("amount");

        // Get the particulars from the debt token
        (ERC20 underlying,,, uint256 conversionPrice) = debtToken.getTokenData();

        // Burn the debt tokens from the sender
        // Requires approval from the sender
        debtToken.burnFrom(msg.sender, amount_);

        // Calculate the amount of TOKEN to mint
        uint256 mintAmount = _getConvertedAmount(amount_, conversionPrice, false);

        // Mint the TOKEN to the sender
        TOKEN.mint(msg.sender, mintAmount);

        // Reduce this contract's withdrawal approval for the underlying asset by the amount converted
        // We do this since the debt token has been burned to avoid an extra dangling allowance
        TRSRY.decreaseWithdrawApproval(address(this), underlying, amount_);

        // Emit an event
        emit DebtConverted(debtToken_, msg.sender, amount_, mintAmount);
    }

    // ========== HELPERS =========== //

    /// @notice Convert an amount of underlying asset to TOKEN at the conversion price
    /// @dev    The conversion rate is the price of TOKEN in the underlying asset that the tokens can be converted at
    ///         e.g. if the underlying asset has 18 decimals, the conversion rate is 15e18, and the amount is 75e18,
    ///         then they will receive 5e18 TOKEN.
    ///
    /// @param  amount_             The amount of underlying asset to convert
    /// @param  conversionPrice_    The conversion price of TOKEN in the underlying asset
    /// @param  roundUp_            Whether to round up the converted amount
    /// @return convertedAmount     The amount of TOKEN that will be minted
    function _getConvertedAmount(
        uint256 amount_,
        uint256 conversionPrice_,
        bool roundUp_
    ) internal view returns (uint256 convertedAmount) {
        if (roundUp_) {
            return mulDivUp(amount_, 10 ** _tokenDecimals, conversionPrice_);
        }

        return (amount_ * 10 ** _tokenDecimals) / conversionPrice_;
    }

    /// @inheritdoc IBanker
    function getConvertedAmount(
        address debtToken_,
        uint256 amount_
    ) external view override returns (uint256 convertedAmount) {
        // Validate that the debt token was created by this issuer
        if (!createdBy[debtToken_]) revert InvalidDebtToken();

        (,,, uint256 conversionPrice) = ConvertibleDebtToken(debtToken_).getTokenData();
        convertedAmount = _getConvertedAmount(amount_, conversionPrice, false);
        return convertedAmount;
    }

    /// @notice     Computes the name and symbol of a vesting token
    ///
    /// @param      underlying_ The address of the underlying token
    /// @param      series_     The series of token for the underlying
    /// @return     string      The name of the vesting token
    /// @return     string      The symbol of the vesting token
    function _computeNameAndSymbol(
        address underlying_,
        uint256 series_
    ) internal view returns (string memory, string memory) {
        // Convert the series number to a string
        string memory ss = uint2str(series_);

        return (
            string(abi.encodePacked("Convertible ", ERC20(underlying_).name(), " - Series ", ss)),
            string(abi.encodePacked("cv", ERC20(underlying_).symbol(), "-", ss))
        );
    }

    // ========== ADMIN FUNCTIONS ========== //

    // Set auction parameters

    /// @notice set the max discount to sell debt at (stored as minPrice)
    /// @param maxDiscount_ max percent discount acceptable to sell debt at in basis points, 1% = 100
    function setMaxDiscount(
        uint48 maxDiscount_
    ) external onlyRole("admin") {
        // Validate max discount is less than 100%
        if (maxDiscount_ > ONE_HUNDRED_PERCENT) revert InvalidParam("discount");

        maxDiscount = maxDiscount_;

        emit MaxDiscountSet(maxDiscount_);
    }

    function setMinFillPercent(
        uint24 minFillPercent_
    ) external onlyRole("admin") {
        // Validate min fill percent is not zero and at most 100%
        if (minFillPercent_ == 0 || minFillPercent_ > ONE_HUNDRED_PERCENT) {
            revert InvalidParam("minFillPercent");
        }

        minFillPercent = minFillPercent_;

        emit MinFillPercentSet(minFillPercent_);
    }

    function setMaxBids(
        uint256 maxBids_
    ) external onlyRole("admin") {
        // Must be greater than zero
        if (maxBids_ == 0) revert InvalidParam("maxBids");

        maxBids = maxBids_;

        emit MaxBidsSet(maxBids_);
    }

    /// @dev Note: the max referrer fee on the auction house can change
    //       This could result in a previously valid setting no longer being valid
    //       It would need to be updated, otherwise it would not be possible to create auctions
    function setReferrerFee(
        uint48 referrerFee_
    ) external onlyRole("admin") {
        (, uint48 maxReferrerFee,) = IFeeManager(AUCTION_HOUSE).getFees(toAxisKeycode("EMPA"));

        // Must be a valid percent and within the auction house's limit
        if (referrerFee_ > maxReferrerFee) revert InvalidParam("referrerFee");

        referrerFee = referrerFee_;

        emit ReferrerFeeSet(referrerFee_);
    }
}

function mulDivUp(uint256 x, uint256 y, uint256 z) pure returns (uint256) {
    uint256 xy = x * y;
    return xy % z == 0 ? xy / z : xy / z + 1;
}
