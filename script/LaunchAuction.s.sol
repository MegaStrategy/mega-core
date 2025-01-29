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
import {IAuction} from "axis-core-1.0.1/interfaces/modules/IAuction.sol";
import {IFixedPriceBatch} from "axis-core-1.0.1/interfaces/modules/auctions/IFixedPriceBatch.sol";
import {ICallback} from "axis-core-1.0.1/interfaces/ICallback.sol";
import {IBaseDirectToLiquidity} from "src/lib/axis/IBaseDirectToLiquidity.sol";
import {IUniswapV3DirectToLiquidity} from "src/lib/axis/IUniswapV3DirectToLiquidity.sol";

// Mega contracts
import {Issuer} from "src/policies/Issuer.sol";

contract LaunchAuction is WithEnvironment {
    using TransferHelper for ERC20;

    function launch(
        string calldata chain_,
        string calldata auctionFilePath_,
        string calldata ipfsHash_
    ) public {
        _loadEnv(chain_);

        console2.log("Loading auction data from ", auctionFilePath_);
        string memory auctionData = vm.readFile(auctionFilePath_);

        uint256 capacity = vm.parseJsonUint(auctionData, ".auctionParams.capacity");

        // Mint tokens to the caller
        // This requires the caller to have the "admin" role
        vm.startBroadcast();
        console2.log("Minting tokens to the caller", msg.sender);
        Issuer(_envAddressNotZero("mega.policies.Issuer")).mint(msg.sender, capacity);
        vm.stopBroadcast();

        // Approve the AuctionHouse to transfer the tokens
        vm.startBroadcast();
        console2.log("Approving the AuctionHouse to transfer the tokens");
        ERC20(_envAddressNotZero("mega.modules.Token")).safeApprove(
            _envAddressNotZero("axis.BatchAuctionHouse"), capacity
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
            curator: address(0),
            referrerFee: 0,
            callbacks: ICallback(_envAddressNotZero("axis.BatchUniswapV3DirectToLiquidity")),
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
            capacity: capacity,
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
    }
}
