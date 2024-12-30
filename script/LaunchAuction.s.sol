// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.19;

import {console2} from "@forge-std/console2.sol";
import {WithEnvironment} from "./WithEnvironment.s.sol";
import {CloakConsumer} from "./CloakConsumer.s.sol";

// Libraries
import {TransferHelper} from "src/lib/TransferHelper.sol";
import {ERC20} from "@solmate-6.8.0/tokens/ERC20.sol";

// Axis dependencies
import {toKeycode} from "axis-core-1.0.1/modules/Keycode.sol";
import {IAuctionHouse} from "axis-core-1.0.1/interfaces/IAuctionHouse.sol";
import {IAuction} from "axis-core-1.0.1/interfaces/modules/IAuction.sol";
import {IEncryptedMarginalPrice} from
    "axis-core-1.0.1/interfaces/modules/auctions/IEncryptedMarginalPrice.sol";
import {ICallback} from "axis-core-1.0.1/interfaces/ICallback.sol";
import {IBaseDirectToLiquidity} from "src/lib/axis/IBaseDirectToLiquidity.sol";
import {IUniswapV3DirectToLiquidity} from "src/lib/axis/IUniswapV3DirectToLiquidity.sol";

// Mega contracts
import {Issuer} from "src/policies/Issuer.sol";

contract LaunchAuction is WithEnvironment, CloakConsumer {
    using TransferHelper for ERC20;

    function launch(string calldata chain_, string calldata ipfsHash_) public {
        _loadEnv(chain_);

        uint256 capacity = 100_000e18; // 100,000 TOKEN

        // Mint tokens to the caller
        // This requires the caller to have the "admin" role
        vm.startBroadcast();
        Issuer(_envAddressNotZero("mega.policies.Issuer")).mint(msg.sender, capacity);
        vm.stopBroadcast();

        // Approve the AuctionHouse to transfer the tokens
        vm.startBroadcast();
        ERC20(_envAddressNotZero("mega.modules.Token")).safeApprove(
            _envAddressNotZero("axis.BatchAuctionHouse"), capacity
        );
        vm.stopBroadcast();

        // Prepare Uniswap V3 DTL callback parameters
        IUniswapV3DirectToLiquidity.UniswapV3OnCreateParams memory uniswapV3Params =
        IUniswapV3DirectToLiquidity.UniswapV3OnCreateParams({
            poolFee: 3000, // 3%
            maxSlippage: 1000 // 0.1%
        });

        // Prepare BaseDTL callback parameters
        IBaseDirectToLiquidity.OnCreateParams memory dtlParams = IBaseDirectToLiquidity
            .OnCreateParams({
            poolPercent: 10e2, // 10% to the pool
            vestingStart: 0,
            vestingExpiry: 0,
            recipient: _envAddressNotZero("mega.modules.OlympusTreasury"),
            implParams: abi.encode(uniswapV3Params)
        });

        // Prepare the routing parameters
        IAuctionHouse.RoutingParams memory routing = IAuctionHouse.RoutingParams({
            auctionType: toKeycode("EMPA"),
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

        // Prepare the EMP parameters
        IEncryptedMarginalPrice.AuctionDataParams memory empParams = IEncryptedMarginalPrice
            .AuctionDataParams({
            minPrice: 1e16, // 0.01 WETH
            minFillPercent: 50e2, // 50%
            minBidSize: 1e16, // 0.01 WETH
            publicKey: _getPublicKey()
        });

        // Prepare the auction parameters
        IAuction.AuctionParams memory auction = IAuction.AuctionParams({
            start: 0,
            duration: 7 days,
            capacityInQuote: true,
            capacity: capacity,
            implParams: abi.encode(empParams)
        });

        // Create the auction
        vm.startBroadcast();
        uint96 lotId = IAuctionHouse(_envAddressNotZero("axis.BatchAuctionHouse")).auction(
            routing, auction, ipfsHash_
        );
        vm.stopBroadcast();

        console2.log("Auction created with lot ID", lotId);
    }
}
