// SPDX-License-Identifier: TBD
pragma solidity 0.8.19;

import {ERC20} from "solmate-6.8.0/tokens/ERC20.sol";
import {TransferHelper} from "src/lib/TransferHelper.sol";

// Axis dependencies
import {BaseCallback, Callbacks} from "axis-core-1.0.1/bases/BaseCallback.sol";

import {Kernel, Keycode, Permissions, Policy, toKeycode} from "src/Kernel.sol";

// Modules
import {TOKENv1} from "src/modules/TOKEN/TOKEN.v1.sol";
import {TRSRYv1} from "src/modules/TRSRY/TRSRY.v1.sol";

contract Launch is Policy, BaseCallback {
    using TransferHelper for ERC20;

    TRSRYv1 public TRSRY;
    TOKENv1 public TOKEN;
    ERC20 public quoteToken;

    // ========== SETUP ========== //

    constructor(
        address kernel_,
        address auctionHouse_
    )
        Policy(Kernel(kernel_))
        BaseCallback(
            auctionHouse_,
            Callbacks.Permissions({
                onCreate: true,
                onCancel: true,
                onCurate: false,
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
        dependencies = new Keycode[](2);
        dependencies[0] = toKeycode("TOKEN");
        dependencies[1] = toKeycode("TRSRY");

        TOKEN = TOKENv1(getModuleAddress(dependencies[0]));
        TRSRY = TRSRYv1(getModuleAddress(dependencies[1]));

        return dependencies;
    }

    /// @inheritdoc Policy
    function requestPermissions()
        external
        view
        override
        returns (Permissions[] memory permissions)
    {
        Keycode TOKEN_KEYCODE = TOKEN.KEYCODE();

        permissions = new Permissions[](1);
        permissions[0] = Permissions(TOKEN_KEYCODE, TOKENv1.mint.selector);

        return permissions;
    }

    // ========== CALLBACK FUNCTIONS ========== //

    /// @inheritdoc BaseCallback
    function _onCreate(
        uint96,
        address,
        address,
        address quoteToken_,
        uint256 capacity_,
        bool,
        bytes calldata
    ) internal override {
        quoteToken = ERC20(quoteToken_);

        // Mint the tokens to the AuctionHouse
        TOKEN.mint(msg.sender, capacity_);
    }

    /// @inheritdoc BaseCallback
    function _onCancel(uint96, uint256 refund_, bool, bytes calldata) internal override {
        // Burn the tokens that have been transferred to this contract
        TOKEN.burn(refund_);
    }

    /// @inheritdoc BaseCallback
    /// @dev        Not implemented
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
    function _onSettle(
        uint96,
        uint256 proceeds_,
        uint256 refund_,
        bytes calldata
    ) internal override {
        // Burn the tokens that have been refunded to this contract
        TOKEN.burn(refund_);

        // Send the proceeds to the treasury
        quoteToken.safeTransfer(address(TRSRY), proceeds_);
    }

    // TODO integrate with Uniswap V3 DTL. Might be easier to just use the Uniswap V3 DTL and mint tokens manually.
}
