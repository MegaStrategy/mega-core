// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.19;

import {Script} from "@forge-std/Script.sol";
import {WithEnvironment} from "./WithEnvironment.s.sol";
import {console2} from "@forge-std/console2.sol";
import {Surl} from "surl-1.0.0/Surl.sol";

import {Banker} from "../src/policies/Banker.sol";
import {Point} from "axis-core-1.0.1/lib/ECIES.sol";

contract BankerAuctionScript is Script, WithEnvironment {
    using Surl for string;

    function _createAuction(
        Banker.DebtTokenParams memory dtParams_,
        Banker.AuctionParams memory auctionParams_
    ) internal {
        // Create the auction
        vm.startBroadcast();
        Banker(_envAddressNotZero("mega.policies.Banker")).auction(dtParams_, auctionParams_);
        vm.stopBroadcast();

        console2.log("Auction created");
    }

    function _getPublicKey() internal returns (Point memory publicKey) {
        // Get the URL for the Cloak API
        string memory cloakUrl = vm.envString("CLOAK_API_URL");

        // Prepare headers
        string[] memory headers = new string[](2);
        headers[0] = "Accept: application/json";
        headers[1] = "Content-Type: application/json";

        string memory url = string.concat(cloakUrl, "public-key");

        // Execute the API call
        console2.log("Requesting public key from ", url);
        (uint256 status, bytes memory response) = url.post(headers, "");

        string memory responseString = string(response);
        console2.log("Response: ", responseString);

        // Check the response status
        if (status >= 400) {
            revert("Failed to get public key");
        }

        // Extract the x and y values
        uint256 x = vm.parseJsonUint(responseString, "x");
        uint256 y = vm.parseJsonUint(responseString, "y");

        return Point(x, y);
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
        Banker.DebtTokenParams memory dtParams;
        Banker.AuctionParams memory auctionParams;
        {
            console2.log("Loading auction data from ", auctionFilePath_);
            string memory auctionData = vm.readFile(auctionFilePath_);

            // Set up debt token params
            dtParams = Banker.DebtTokenParams({
                underlying: address(_envAddressNotZero("external.tokens.USDC")),
                maturity: uint48(
                    block.timestamp + uint48(vm.parseJsonUint(auctionData, "auctionParams.maturity"))
                ),
                conversionPrice: vm.parseJsonUint(auctionData, "auctionParams.conversionPrice")
            });

            // Set up auction params
            auctionParams = Banker.AuctionParams({
                start: uint48(
                    block.timestamp + uint48(vm.parseJsonUint(auctionData, "auctionParams.startDelay"))
                ),
                duration: uint48(vm.parseJsonUint(auctionData, "auctionParams.duration")),
                capacity: uint96(vm.parseJsonUint(auctionData, "auctionParams.capacity")),
                auctionPublicKey: publicKey,
                infoHash: ipfsHash_
            });
        }

        // Create auction
        _createAuction(dtParams, auctionParams);
    }
}
