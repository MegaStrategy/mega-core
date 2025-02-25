// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.19;

import {console2} from "@forge-std/console2.sol";
import {WithEnvironment} from "./WithEnvironment.s.sol";

// Libraries
import {TransferHelper} from "src/lib/TransferHelper.sol";
import {ERC20} from "@solmate-6.8.0/tokens/ERC20.sol";

// Axis dependencies
import {toKeycode} from "@axis-core-1.0.1/modules/Keycode.sol";
import {IAuctionHouse} from "@axis-core-1.0.1/interfaces/IAuctionHouse.sol";
import {IFeeManager} from "@axis-core-1.0.1/interfaces/IFeeManager.sol";
import {IAuction} from "@axis-core-1.0.1/interfaces/modules/IAuction.sol";
import {IFixedPriceBatch} from "@axis-core-1.0.1/interfaces/modules/auctions/IFixedPriceBatch.sol";
import {ICallback} from "@axis-core-1.0.1/interfaces/ICallback.sol";
import {IBaseDirectToLiquidity} from "src/lib/Axis/IBaseDirectToLiquidity.sol";
import {IUniswapV3DirectToLiquidity} from "src/lib/Axis/IUniswapV3DirectToLiquidity.sol";
import {IUniswapV3DTLWithAllocatedAllowlist} from
    "@axis-periphery-1.0.0/callbacks/liquidity/IUniswapV3DTLWithAllocatedAllowlist.sol";
import {IMetadataRegistry} from "@axis-registry-1.0.0/interfaces/IMetadataRegistry.sol";

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
        string calldata ipfsHash_,
        bytes32 merkleRoot_
    ) public {
        _loadEnv(chain_);

        console2.log("Loading auction data from ", auctionFilePath_);
        string memory auctionData = vm.readFile(auctionFilePath_);

        // Validate the auction data
        // - Capacity is not zero
        // - Price is not zero
        // - Start is not zero
        // - Duration is not zero
        {
            uint256 capacity = vm.parseJsonUint(auctionData, ".auctionParams.capacity");
            if (capacity == 0) {
                // solhint-disable-next-line custom-errors
                revert("Capacity is zero");
            }

            uint256 price = vm.parseJsonUint(auctionData, ".auctionParams.price");
            if (price == 0) {
                // solhint-disable-next-line custom-errors
                revert("Price is zero");
            }

            uint256 start = vm.parseJsonUint(auctionData, ".auctionParams.start");
            if (start == 0) {
                // solhint-disable-next-line custom-errors
                revert("Start is zero");
            }

            uint256 duration = vm.parseJsonUint(auctionData, ".auctionParams.duration");
            if (duration == 0) {
                // solhint-disable-next-line custom-errors
                revert("Duration is zero");
            }
        }

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
            console2.log("  Capacity", capacity, "/1e18");
            console2.log("  Curator", curator);
            console2.log("  Curator fee", curatorFee, "/10000");
            console2.log("  Pool percent", poolPercent, "/10000");
            console2.log("  DTL liquidity", dtlAmount, "/1e18");
        }

        // Mint tokens to the caller
        // This requires the caller to have the "admin" role
        vm.startBroadcast();
        console2.log("");
        console2.log("Minting tokens to the caller", msg.sender);
        Issuer(_envAddressNotZero("mega.policies.Issuer")).mint(
            msg.sender, auctionHouseAmount + dtlAmount
        );
        console2.log("  Minted", auctionHouseAmount + dtlAmount, "/1e18", "tokens to the caller");
        vm.stopBroadcast();

        // Approve the AuctionHouse to transfer the tokens
        vm.startBroadcast();
        console2.log("");
        console2.log("Approving the AuctionHouse to transfer the tokens");
        ERC20(_envAddressNotZero("mega.modules.TOKEN")).safeApprove(
            _envAddressNotZero("axis.BatchAuctionHouse"), auctionHouseAmount
        );
        console2.log("  Approved", auctionHouseAmount, "/1e18", "tokens");
        vm.stopBroadcast();

        // Approve the DTL callback to transfer the tokens
        vm.startBroadcast();
        console2.log("");
        console2.log("Approving the DTL callback to transfer the tokens");
        ERC20(_envAddressNotZero("mega.modules.TOKEN")).safeApprove(
            _envAddressNotZero(
                "axis.callbacks.BatchUniswapV3DirectToLiquidityWithAllocatedAllowlist"
            ),
            dtlAmount
        );
        console2.log("  Approved", dtlAmount, "/1e18", "tokens");
        vm.stopBroadcast();

        // Prepare Uniswap V3 DTL callback parameters
        IUniswapV3DirectToLiquidity.UniswapV3OnCreateParams memory uniswapV3Params =
        IUniswapV3DirectToLiquidity.UniswapV3OnCreateParams({
            poolFee: uint24(vm.parseJsonUint(auctionData, ".callbackParams.poolFee")),
            maxSlippage: uint24(vm.parseJsonUint(auctionData, ".callbackParams.maxSlippage"))
        });
        console2.log("");
        console2.log("Uniswap V3 DTL params");
        console2.log("  Pool Fee", uniswapV3Params.poolFee, "/10000");
        console2.log("  Max Slippage", uniswapV3Params.maxSlippage, "/10000");

        // Prepare BaseDTL callback parameters
        IBaseDirectToLiquidity.OnCreateParams memory dtlParams = IBaseDirectToLiquidity
            .OnCreateParams({
            poolPercent: uint24(vm.parseJsonUint(auctionData, ".callbackParams.poolPercent")),
            vestingStart: uint48(vm.parseJsonUint(auctionData, ".callbackParams.vestingStart")),
            vestingExpiry: uint48(vm.parseJsonUint(auctionData, ".callbackParams.vestingExpiry")),
            recipient: _envAddressNotZero("mega.modules.TRSRY"),
            implParams: abi.encode(uniswapV3Params)
        });
        console2.log("  Pool Percent", dtlParams.poolPercent, "/10000");
        console2.log("  Vesting Start", dtlParams.vestingStart);
        console2.log("  Vesting Expiry", dtlParams.vestingExpiry);
        console2.log("  Recipient", dtlParams.recipient);

        // Prepare the routing parameters
        IAuctionHouse.RoutingParams memory routing = IAuctionHouse.RoutingParams({
            auctionType: toKeycode("FPBA"),
            baseToken: _envAddressNotZero("mega.modules.TOKEN"),
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
        console2.log("");
        console2.log("Routing Params");
        console2.log("  Auction Type", "FPBA");
        console2.log("  Base Token", routing.baseToken);
        console2.log("  Quote Token", routing.quoteToken);
        console2.log("  Curator", routing.curator);
        console2.log("  Referrer Fee", routing.referrerFee, "/10000");
        console2.log("  Callbacks", address(routing.callbacks));
        console2.log("  Derivative Type", "");
        console2.log("  Derivative Params", "");
        console2.log("  Wrap Derivative", false);

        // Prepare the FPB parameters
        IFixedPriceBatch.AuctionDataParams memory fpbParams = IFixedPriceBatch.AuctionDataParams({
            price: vm.parseJsonUint(auctionData, ".auctionParams.price"),
            minFillPercent: uint24(vm.parseJsonUint(auctionData, ".auctionParams.minFillPercent"))
        });
        console2.log("");
        console2.log("FPB Params");
        console2.log("  Price", fpbParams.price, "/1e18");
        console2.log("  Min Fill Percent", fpbParams.minFillPercent, "/10000");

        // Prepare the auction parameters
        IAuction.AuctionParams memory auction = IAuction.AuctionParams({
            start: uint48(vm.parseJsonUint(auctionData, ".auctionParams.start")),
            duration: uint48(vm.parseJsonUint(auctionData, ".auctionParams.duration")),
            capacityInQuote: false,
            capacity: vm.parseJsonUint(auctionData, ".auctionParams.capacity"),
            implParams: abi.encode(fpbParams)
        });
        console2.log("");
        console2.log("Auction Params");
        console2.log("  Start", auction.start);
        console2.log("  Duration", auction.duration);
        console2.log("  Capacity", auction.capacity, "/1e18");
        console2.log("  Capacity In Quote", auction.capacityInQuote);

        // Create the auction
        vm.startBroadcast();
        console2.log("Creating the auction");
        uint96 lotId = IAuctionHouse(_envAddressNotZero("axis.BatchAuctionHouse")).auction(
            routing, auction, ipfsHash_
        );
        vm.stopBroadcast();

        console2.log("Auction created with lot ID", lotId);

        // Set the Merkle root for the allowlist
        _setMerkleRoot(lotId, merkleRoot_);

        // Next steps:
        // - Set the Merkle root for the allowlist
    }

    function _setMerkleRoot(uint96 lotId_, bytes32 merkleRoot_) internal {
        // Update the merkle root on the callback
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

    /// @notice Updates the Merkle root and IPFS hash for the given lot id
    /// @dev    Must be run as the seller
    function updateAllowlist(
        string calldata chain_,
        uint96 lotId_,
        bytes32 merkleRoot_,
        string calldata ipfsHash_
    ) public {
        _loadEnv(chain_);

        // Update the merkle root on the callback
        _setMerkleRoot(lotId_, merkleRoot_);

        // Update the IPFS hash on the metadata registry
        // This will cause the subgraph to update
        IMetadataRegistry registry = IMetadataRegistry(_envAddressNotZero("axis.MetadataRegistry"));

        console2.log("Updating the IPFS hash on the metadata registry for lot id", lotId_);

        vm.startBroadcast();
        registry.registerAuction(_envAddressNotZero("axis.BatchAuctionHouse"), lotId_, ipfsHash_);
        vm.stopBroadcast();
    }
}
