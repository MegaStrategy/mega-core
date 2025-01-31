// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import {WithEnvironment} from "./WithEnvironment.s.sol";
import {console2} from "@forge-std/console2.sol";

import {CloakConsumer} from "./CloakConsumer.s.sol";
import {Point} from "axis-core-1.0.1/lib/ECIES.sol";

import {IBanker} from "src/policies/interfaces/IBanker.sol";

contract BankerAuctionScript is WithEnvironment, CloakConsumer {
    function _createAuction(
        IBanker.DebtTokenParams memory dtParams_,
        IBanker.AuctionParams memory auctionParams_
    ) internal {
        // Create the auction
        vm.startBroadcast();
        IBanker(_envAddressNotZero("mega.policies.Banker")).auction(dtParams_, auctionParams_);
        vm.stopBroadcast();

        console2.log("Auction created");
    }

    function create(
        string calldata chain_,
        string calldata auctionFilePath_,
        string calldata ipfsHash_
    ) external {
        _loadEnv(chain_);

        // Get public key
        Point memory publicKey = _getPublicKey();

        // Load the data from the auction file and construct into the required format
        IBanker.DebtTokenParams memory dtParams;
        IBanker.AuctionParams memory auctionParams;
        {
            console2.log("Loading auction data from ", auctionFilePath_);
            string memory auctionData = vm.readFile(auctionFilePath_);

            // Set up debt token params
            dtParams = IBanker.DebtTokenParams({
                underlying: address(_envAddressNotZero("external.tokens.USDC")),
                maturity: uint48(
                    block.timestamp + uint48(vm.parseJsonUint(auctionData, ".auctionParams.maturity"))
                ),
                conversionPrice: vm.parseJsonUint(auctionData, ".auctionParams.conversionPrice")
            });

            // Set up auction params
            auctionParams = IBanker.AuctionParams({
                start: uint48(
                    block.timestamp + uint48(vm.parseJsonUint(auctionData, ".auctionParams.startDelay"))
                ),
                duration: uint48(vm.parseJsonUint(auctionData, ".auctionParams.duration")),
                capacity: uint96(vm.parseJsonUint(auctionData, ".auctionParams.capacity")),
                auctionPublicKey: publicKey,
                infoHash: ipfsHash_
            });
        }

        // Create auction
        _createAuction(dtParams, auctionParams);
    }
}
