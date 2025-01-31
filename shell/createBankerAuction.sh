#!/bin/bash

# Creates an auction through the Banker policy
# Usage: ./createBankerAuction.sh --input <auctionFilePath> --account <cast account> --testnet <true|false> --broadcast <true|false> --env <env file>
#
# Environment variables:
# RPC_URL
# CHAIN

# Exit if any error occurs
set -e

# Load named arguments
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source $SCRIPT_DIR/lib/arguments.sh
load_named_args "$@"

# Load environment variables
load_env

# Set sane defaults
BROADCAST=${broadcast:-false}
TESTNET=${testnet:-false}

# Validate named arguments
echo ""
echo "Validating arguments"
validate_text "$input" "No auction input file specified. Provide the path to the auction input file after the --input flag."
validate_text "$account" "No account specified. Provide the cast wallet after the --account flag."

# Validate environment variables
echo ""
echo "Validating environment variables"
validate_text "$CHAIN" "No chain specified. Specify the CHAIN in the $ENV_FILE file."
validate_text "$RPC_URL" "No RPC URL specified. Specify the RPC_URL in the $ENV_FILE file."

# Set the CLOAK_API_URL to the testnet version if TESTNET is true
if [ "$TESTNET" = "true" ]; then
    CLOAK_API_URL="https://api-testnet-v3.up.railway.app/"
else
    CLOAK_API_URL="https://api-production-8b39.up.railway.app/"
fi

# Check if the CLOAK_API_URL ends with a slash
if [ "${CLOAK_API_URL: -1}" != "/" ]; then
    # Append a slash to the CLOAK_API_URL
    CLOAK_API_URL="$CLOAK_API_URL/"
fi

# Get the address of the cast wallet
echo ""
echo "Getting address for cast account $account"
CAST_ADDRESS=$(cast wallet address --account $account)

echo ""
echo "Summary:"
echo "  Deploy from account: $account"
echo "  Sender: $CAST_ADDRESS"
echo "  Chain: $CHAIN"
echo "  RPC URL: $RPC_URL"
echo "  Auction input file: $input"
echo "  Testnet: $TESTNET"
echo "  Cloak API URL: $CLOAK_API_URL"

# Validate and set forge script flags
source $SCRIPT_DIR/lib/forge.sh
set_broadcast_flag $BROADCAST

# Validate that the auction info has the required fields
echo ""
echo "Validating auction info"
if ! jq -e '.auctionInfo.name' $input > /dev/null 2>&1; then
    echo "Error: auctionInfo.name is required"
    exit 1
fi

if ! jq -e '.auctionInfo.description' $input > /dev/null 2>&1; then
    echo "Error: auctionInfo.description is required"
    exit 1
fi

if ! jq -e '.auctionInfo.tagline' $input > /dev/null 2>&1; then
    echo "Error: auctionInfo.tagline is required"
    exit 1
fi

if ! jq -e '.auctionInfo.links.projectBanner' $input > /dev/null 2>&1; then
    echo "Error: auctionInfo.links.projectBanner is required"
    exit 1
fi

if ! jq -e '.auctionInfo.links.projectLogo' $input > /dev/null 2>&1; then
    echo "Error: auctionInfo.links.projectLogo is required"
    exit 1
fi

if ! jq -e '.auctionInfo.links.payoutTokenLogo' $input > /dev/null 2>&1; then
    echo "Error: auctionInfo.links.payoutTokenLogo is required"
    exit 1
fi

if ! jq -e '.auctionInfo.links.website' $input > /dev/null 2>&1; then
    echo "Error: auctionInfo.links.website is required"
    exit 1
fi

# Extract the "auctionInfo" key from the input file and store it in the tmp directory
echo ""
echo "Extracting auction info from $input for upload to IPFS"
mkdir -p tmp
AUCTION_INFO=$(jq -r '.auctionInfo' $input)
echo "$AUCTION_INFO" > tmp/auctionInfo.json

# Upload the data to IPFS
echo ""
echo "Uploading data to IPFS"
echo "If nothing happens, you may need to run 'npx fleek login' to authenticate, and then select a project using 'npx fleek projects switch'"
IPFS_OUTPUT=$(npx fleek storage add tmp/auctionInfo.json)
# Extract the IPFS CID (59 characters long) from the fleek output
IPFS_HASH=$(echo "$IPFS_OUTPUT" | grep -o "[a-zA-Z0-9]\{59\}")

# Verify we got a valid hash
if [ -z "$IPFS_HASH" ]; then
    echo "Error: Failed to extract IPFS hash from fleek output"
    exit 1
else
    echo "IPFS hash: $IPFS_HASH"
fi

# Run
echo ""
echo "Running the auction creation script"
CLOAK_API_URL=$CLOAK_API_URL forge script script/BankerAuction.s.sol --sig "create(string,string,string)()" $CHAIN $input $IPFS_HASH --rpc-url $RPC_URL --account $account --sender $CAST_ADDRESS $BROADCAST_FLAG -vvv

# Determine the dApp URL
DAPP_URL="https://app.axis.finance/"
if [ "$TESTNET" = "true" ]; then
    DAPP_URL="https://testnet.axis.finance/"
fi

# Output the auction ID
echo ""
echo "Auction created"
echo "You can view the auction at $DAPP_URL"
