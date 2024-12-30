// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.19;

import {console2} from "@forge-std/console2.sol";
import {WithEnvironment} from "./WithEnvironment.s.sol";
import {CloakConsumer} from "./CloakConsumer.s.sol";

import {toKeycode} from "axis-core-1.0.1/modules/Keycode.sol";
import {IAuctionHouse} from "axis-core-1.0.1/interfaces/IAuctionHouse.sol";
import {IAuction} from "axis-core-1.0.1/interfaces/modules/IAuction.sol";
import {IEncryptedMarginalPrice} from
    "axis-core-1.0.1/interfaces/modules/auctions/IEncryptedMarginalPrice.sol";
import {ICallback} from "axis-core-1.0.1/interfaces/ICallback.sol";

contract LaunchAuction is WithEnvironment, CloakConsumer {
    function launch(string calldata chain_, string calldata ipfsHash_) public {
        _loadEnv(chain_);

        // TODO: instead of a custom callback, use the Uniswap V3 DTL and have the auction owner mint the tokens manually.

        // Prepare the routing parameters
        IAuctionHouse.RoutingParams memory routing = IAuctionHouse.RoutingParams({
            auctionType: toKeycode("EMPA"),
            baseToken: _envAddressNotZero("mega.modules.Token"),
            quoteToken: _envAddressNotZero("external.tokens.WETH"),
            curator: address(0),
            referrerFee: 0,
            callbacks: ICallback(_envAddressNotZero("mega.policies.Launch")),
            callbackData: "",
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
            capacity: 100_000e18, // 100,000 TOKEN
            implParams: abi.encode(empParams)
        });

        // Create the auction
        uint96 lotId = IAuctionHouse(_envAddressNotZero("axis.BatchAuctionHouse")).auction(
            routing, auction, ipfsHash_
        );

        console2.log("Auction created with lot ID", lotId);
    }
}
