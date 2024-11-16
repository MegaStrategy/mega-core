// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "@forge-std/Script.sol";

contract Delpoy is Script {
    function run() public {
        vm.broadcast(vm.promptSecretUint("Deployer private key"));
    }
}
