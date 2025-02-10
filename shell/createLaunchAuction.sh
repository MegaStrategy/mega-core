#!/bin/bash

# Creates an auction through the LaunchAuction script
# Usage: ./createLaunchAuction.sh
#       --account <cast account>
#       --allowlist <allowlist file>
#       --merkleRoot <merkle root>
#       --testnet <true|false>
#       --broadcast <true|false>
#       --env <env file>
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
validate_text "$account" "No account specified. Provide the cast wallet after the --account flag."
validate_file "$allowlist" "No allowlist specified or it does not exist. Provide the path to the allowlist CSV file after the --allowlist flag."
validate_bytes32 "$merkleRoot" "No merkle root specified or it was not a valid bytes32 value. Provide the merkle root after the --merkleRoot flag."

# Check if the allowlist is a CSV file
if ! head -n 1 $allowlist | grep -qE '^address,amount$'; then
    echo "Error: Allowlist file $allowlist is not a valid CSV file with columns 'address' and 'amount'"
    exit 1
fi

# Validate environment variables
echo ""
echo "Validating environment variables"
validate_text "$CHAIN" "No chain specified. Specify the CHAIN in the $ENV_FILE file."
validate_text "$RPC_URL" "No RPC URL specified. Specify the RPC_URL in the $ENV_FILE file."

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
echo "  Testnet: $TESTNET"
echo "  Allowlist: $allowlist"
echo "  Merkle Root: $merkleRoot"

# Validate and set forge script flags
source $SCRIPT_DIR/lib/forge.sh
set_broadcast_flag $BROADCAST

LAUNCH_FILE="script/auctions/launch.json"

# Validate that the auction info has the required fields
echo ""
echo "Validating auction info"
if ! jq -e '.auctionInfo.name' $LAUNCH_FILE > /dev/null 2>&1; then
    echo "Error: auctionInfo.name is required"
    exit 1
fi

if ! jq -e '.auctionInfo.description' $LAUNCH_FILE > /dev/null 2>&1; then
    echo "Error: auctionInfo.description is required"
    exit 1
fi

if ! jq -e '.auctionInfo.tagline' $LAUNCH_FILE > /dev/null 2>&1; then
    echo "Error: auctionInfo.tagline is required"
    exit 1
fi

if ! jq -e '.auctionInfo.links.projectBanner' $LAUNCH_FILE > /dev/null 2>&1; then
    echo "Error: auctionInfo.links.projectBanner is required"
    exit 1
fi

if ! jq -e '.auctionInfo.links.projectLogo' $LAUNCH_FILE > /dev/null 2>&1; then
    echo "Error: auctionInfo.links.projectLogo is required"
    exit 1
fi

if ! jq -e '.auctionInfo.links.payoutTokenLogo' $LAUNCH_FILE > /dev/null 2>&1; then
    echo "Error: auctionInfo.links.payoutTokenLogo is required"
    exit 1
fi

if ! jq -e '.auctionInfo.links.website' $LAUNCH_FILE > /dev/null 2>&1; then
    echo "Error: auctionInfo.links.website is required"
    exit 1
fi

# Extract the "auctionInfo" key from the input file and store it in the tmp directory
echo ""
echo "Extracting auction info from $LAUNCH_FILE for upload to IPFS"
mkdir -p tmp
AUCTION_INFO=$(jq -r '.auctionInfo' $LAUNCH_FILE)

# Generate the allowlist from CSV
echo ""
echo "Formatting and validating allowlist from file $allowlist"
ALLOWLIST_JSON=$(awk -F, 'BEGIN {print "["} NR>1 && NF>1 {printf("%s[\"%s\",\"%s\"]", (NR==2)?"":",\n", $1, $2)} END {print "]"}' $allowlist)

# Set the "allowlist" key in the auction info
AUCTION_INFO=$(echo "$AUCTION_INFO" | jq --argjson allowlist "$ALLOWLIST_JSON" '.allowlist = $allowlist')

# Write the auction info to a file
echo ""
echo "Writing auction info to tmp/auctionInfo.json"
echo "$AUCTION_INFO" > tmp/auctionInfo.json

# Validate and format the auction info JSON file
echo ""
echo "Validating and formatting auction info JSON file"
AUCTION_INFO=$(jq -s . tmp/auctionInfo.json)

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
forge script script/LaunchAuction.s.sol --sig "launch(string,string,string)()" $CHAIN $LAUNCH_FILE $IPFS_HASH --rpc-url $RPC_URL --account $account --sender $CAST_ADDRESS $BROADCAST_FLAG -vvv

# Determine the dApp URL
DAPP_URL="https://app.axis.finance/"
if [ "$TESTNET" = "true" ]; then
    DAPP_URL="https://testnet.axis.finance/"
fi

# Output the auction ID
echo ""
echo "Auction created"
echo "You can view the auction at $DAPP_URL"
