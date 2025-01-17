# MegaStrategy

MegaStrategy is a system to create a token that allows for leveraged exposure to the backing assets.

## Setup

1. Install `forge`: [https://getfoundry.sh](https://getfoundry.sh)
    - This should be the stable version, 0.3.0
2. Run `pnpm install` to install all npm and forge/soldeer dependencies

## Wallet Configuration

A wallet must be configured with `cast wallet` before deploying or interacting with the system.

## Deployment

Use the `script/deploy/deploy.sh` script to deploy the system.

The following must be performed to deploy and activate the system:

1. Copy the `.env.example` file to `.env` (or similar if using multiple chains) and populate with the correct values
2. Deploy the system using the `deploy.sh` script
3. Install the modules and policies into the Kernel using the `kernelInstallation.sh` script
4. Grant admin and manager roles using the `Tasks.s.sol` script

-   e.g. `forge script ./script/Tasks.s.sol --sig "addAdmin(string,address)()" base-sepolia <ADMIN_ADDRESS> --rpc-url <RPC_URL> --account <CAST_ACCOUNT> --sender <SIGNER_ADDRESS> --slow -vvv --broadcast`

5. Initialize the Banker using the `Tasks.s.sol` script

## Tasks

Use the `script/Tasks.s.sol` script to perform tasks such as creating option tokens and issuing them.

## Convertible Debt Auctions

The Banker policy can create convertible debt auctions. The `shell/createBankerAuction.sh` script can be used to create an auction.

This script has additional requirements that need to be manually configured:

-   jq
-   The fleek CLI tool must be authenticated using `npx fleek login`
-   The fleek CLI tool must be configured to use the correct project using `npx fleek projects select`
-   Populating an environment file with the required values

To create the auction:

1. Create a JSON file with the auction details. See [script/auctions/IMG.json](script/auctions/IMG.json) for an example.
2. Run the `createBankerAuction.sh` script: `./shell/createBankerAuction.sh --account <CAST_ACCOUNT> --auctionFilePath <PATH_TO_AUCTION_FILE> --testnet <true|false> --broadcast <true|false>`
