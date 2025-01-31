// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.19;

import {console2} from "@forge-std/console2.sol";
import {WithEnvironment} from "./WithEnvironment.s.sol";

// Libraries
import {TransferHelper} from "src/lib/TransferHelper.sol";
import {ERC20} from "@solmate-6.8.0/tokens/ERC20.sol";

// Axis dependencies
import {toKeycode} from "axis-core-1.0.1/modules/Keycode.sol";
import {IAuctionHouse} from "axis-core-1.0.1/interfaces/IAuctionHouse.sol";
import {IFeeManager} from "axis-core-1.0.1/interfaces/IFeeManager.sol";
import {IAuction} from "axis-core-1.0.1/interfaces/modules/IAuction.sol";
import {IFixedPriceBatch} from "axis-core-1.0.1/interfaces/modules/auctions/IFixedPriceBatch.sol";
import {ICallback} from "axis-core-1.0.1/interfaces/ICallback.sol";
import {IBaseDirectToLiquidity} from "src/lib/axis/IBaseDirectToLiquidity.sol";
import {IUniswapV3DirectToLiquidity} from "src/lib/axis/IUniswapV3DirectToLiquidity.sol";
import {IUniswapV3DTLWithAllocatedAllowlist} from
    "axis-periphery-1.0.0/callbacks/liquidity/IUniswapV3DTLWithAllocatedAllowlist.sol";

// Mega contracts
import {Issuer} from "src/policies/Issuer.sol";

contract LaunchAuction is WithEnvironment {
    using TransferHelper for ERC20;

    function _parseJsonAddress(
        string memory data_,
        string memory path_
    ) internal pure returns (address) {
        return vm.parseJsonAddress(data_, path_);
    }

    function _parseJsonAddressNotZero(
        string memory data_,
        string memory path_
    ) internal pure returns (address) {
        address jsonAddress = _parseJsonAddress(data_, path_);
        if (jsonAddress == address(0)) {
            // solhint-disable-next-line custom-errors
            revert(string.concat("Address is zero at path ", path_));
        }

        return jsonAddress;
    }

    function launch(
        string calldata chain_,
        string calldata auctionFilePath_,
        string calldata ipfsHash_
    ) public {
        _loadEnv(chain_);

        console2.log("Loading auction data from ", auctionFilePath_);
        string memory auctionData = vm.readFile(auctionFilePath_);

        // Determine the amount of tokens to mint to the caller
        // Capacity + curator fee + DTL
        uint256 auctionHouseAmount;
        uint256 dtlAmount;
        {
            uint256 capacity = vm.parseJsonUint(auctionData, ".auctionParams.capacity");

            // Curator fee
            address curator = _parseJsonAddress(auctionData, ".auctionParams.curator");
            uint256 curatorFee;
            if (curator != address(0)) {
                uint48 curatorFeePercent = IFeeManager(_envAddressNotZero("axis.BatchAuctionHouse"))
                    .getCuratorFee(toKeycode("FPBA"), curator);
                curatorFee = capacity * uint256(curatorFeePercent) / uint256(100e2);
            }

            // DTL liquidity
            uint24 poolPercent =
                uint24(vm.parseJsonUint(auctionData, ".callbackParams.poolPercent"));
            dtlAmount = capacity * uint256(poolPercent) / uint256(100e2);

            auctionHouseAmount = capacity + curatorFee;
            console2.log("  Capacity", capacity);
            console2.log("  Curator fee", curatorFee);
            console2.log("  DTL liquidity", dtlAmount);
        }

        // Mint tokens to the caller
        // This requires the caller to have the "admin" role
        vm.startBroadcast();
        console2.log("Minting tokens to the caller", msg.sender);
        Issuer(_envAddressNotZero("mega.policies.Issuer")).mint(
            msg.sender, auctionHouseAmount + dtlAmount
        );
        vm.stopBroadcast();

        // Approve the AuctionHouse to transfer the tokens
        vm.startBroadcast();
        console2.log("Approving the AuctionHouse to transfer the tokens");
        ERC20(_envAddressNotZero("mega.modules.Token")).safeApprove(
            _envAddressNotZero("axis.BatchAuctionHouse"), auctionHouseAmount
        );
        vm.stopBroadcast();

        // Approve the DTL callback to transfer the tokens
        vm.startBroadcast();
        console2.log("Approving the DTL callback to transfer the tokens");
        ERC20(_envAddressNotZero("mega.modules.Token")).safeApprove(
            _envAddressNotZero(
                "axis.callbacks.BatchUniswapV3DirectToLiquidityWithAllocatedAllowlist"
            ),
            dtlAmount
        );
        vm.stopBroadcast();

        // Prepare Uniswap V3 DTL callback parameters
        IUniswapV3DirectToLiquidity.UniswapV3OnCreateParams memory uniswapV3Params =
        IUniswapV3DirectToLiquidity.UniswapV3OnCreateParams({
            poolFee: uint24(vm.parseJsonUint(auctionData, ".callbackParams.poolFee")),
            maxSlippage: uint24(vm.parseJsonUint(auctionData, ".callbackParams.maxSlippage"))
        });

        // Prepare BaseDTL callback parameters
        IBaseDirectToLiquidity.OnCreateParams memory dtlParams = IBaseDirectToLiquidity
            .OnCreateParams({
            poolPercent: uint24(vm.parseJsonUint(auctionData, ".callbackParams.poolPercent")),
            vestingStart: uint48(vm.parseJsonUint(auctionData, ".callbackParams.vestingStart")),
            vestingExpiry: uint48(vm.parseJsonUint(auctionData, ".callbackParams.vestingExpiry")),
            recipient: _envAddressNotZero("mega.modules.OlympusTreasury"),
            implParams: abi.encode(uniswapV3Params)
        });

        // Prepare the routing parameters
        IAuctionHouse.RoutingParams memory routing = IAuctionHouse.RoutingParams({
            auctionType: toKeycode("FPBA"),
            baseToken: _envAddressNotZero("mega.modules.Token"),
            quoteToken: _envAddressNotZero("external.tokens.WETH"),
            curator: _parseJsonAddress(auctionData, ".auctionParams.curator"), // Curator, zero address is allowed
            referrerFee: 0,
            callbacks: ICallback(
                _envAddressNotZero(
                    "axis.callbacks.BatchUniswapV3DirectToLiquidityWithAllocatedAllowlist"
                )
            ),
            callbackData: abi.encode(dtlParams),
            derivativeType: toKeycode(""),
            derivativeParams: "",
            wrapDerivative: false
        });

        // Prepare the FPB parameters
        IFixedPriceBatch.AuctionDataParams memory fpbParams = IFixedPriceBatch.AuctionDataParams({
            price: vm.parseJsonUint(auctionData, ".auctionParams.price"),
            minFillPercent: uint24(vm.parseJsonUint(auctionData, ".auctionParams.minFillPercent"))
        });

        // Prepare the auction parameters
        IAuction.AuctionParams memory auction = IAuction.AuctionParams({
            start: uint48(
                block.timestamp + uint48(vm.parseJsonUint(auctionData, ".auctionParams.startDelay"))
            ),
            duration: uint48(vm.parseJsonUint(auctionData, ".auctionParams.duration")),
            capacityInQuote: false,
            capacity: vm.parseJsonUint(auctionData, ".auctionParams.capacity"),
            implParams: abi.encode(fpbParams)
        });

        // Create the auction
        vm.startBroadcast();
        console2.log("Creating the auction");
        uint96 lotId = IAuctionHouse(_envAddressNotZero("axis.BatchAuctionHouse")).auction(
            routing, auction, ipfsHash_
        );
        vm.stopBroadcast();

        console2.log("Auction created with lot ID", lotId);

        // Next steps:
        // - Set the Merkle root for the allowlist
    }

    /// @notice Sets the Merkle root for the allowlist on the given lot id
    /// @dev    Must be run as the seller
    function setMerkleRoot(string calldata chain_, uint96 lotId_, bytes32 merkleRoot_) public {
        _loadEnv(chain_);

        IUniswapV3DTLWithAllocatedAllowlist dtl = IUniswapV3DTLWithAllocatedAllowlist(
            _envAddressNotZero(
                "axis.callbacks.BatchUniswapV3DirectToLiquidityWithAllocatedAllowlist"
            )
        );

        console2.log("Setting the Merkle root for the allowlist on lot id", lotId_);

        vm.startBroadcast();
        dtl.setMerkleRoot(lotId_, merkleRoot_);
        vm.stopBroadcast();
    }
}
