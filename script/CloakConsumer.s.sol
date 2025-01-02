// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.19;

import {Script} from "@forge-std/Script.sol";
import {Surl} from "surl-1.0.0/Surl.sol";
import {console2} from "@forge-std/console2.sol";

import {Point} from "axis-core-1.0.1/lib/ECIES.sol";

abstract contract CloakConsumer is Script {
    using Surl for string;

    function _getPublicKey() internal returns (Point memory publicKey) {
        // Get the URL for the Cloak API
        // It is assumed that the URL ends with a slash and was checked by the shell script
        string memory cloakUrl = vm.envString("CLOAK_API_URL");

        // Prepare headers
        string[] memory headers = new string[](2);
        headers[0] = "Accept: application/json";
        headers[1] = "Content-Type: application/json";

        string memory url = string.concat(cloakUrl, "new_key_pair");

        // Execute the API call
        console2.log("Requesting public key from ", url);
        (uint256 status, bytes memory response) = url.post(headers, "");

        string memory responseString = string(response);

        // Check the response status
        if (status >= 400) {
            // solhint-disable-next-line custom-errors
            revert("Failed to get public key");
        }

        // Extract the x and y values
        uint256 x = vm.parseJsonUint(responseString, ".x");
        uint256 y = vm.parseJsonUint(responseString, ".y");

        return Point(x, y);
    }
}
