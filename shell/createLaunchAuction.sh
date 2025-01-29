#!/bin/bash

# Creates an auction through the LaunchAuction script
# Usage: ./createLaunchAuction.sh --account <cast account> --allowlist <allowlist file> --testnet <true|false> --broadcast <true|false> --env <env file>
#
# Environment variables:
# RPC_URL
# CHAIN

# Exit if any error occurs
set -e

# Iterate through named arguments
# Source: https://unix.stackexchange.com/a/388038
while [ $# -gt 0 ]; do
    if [[ $1 == *"--"* ]]; then
        v="${1/--/}"
        declare $v="$2"
    fi

    shift
done

# Get the name of the .env file or use the default
ENV_FILE=${env:-".env"}
echo "Sourcing environment variables from $ENV_FILE"

# Load environment file
set -a # Automatically export all variables
source $ENV_FILE
set +a # Disable automatic export

# Set sane defaults
BROADCAST=${broadcast:-false}
TESTNET=${testnet:-false}

# Check if CHAIN is set
if [ -z "$CHAIN" ]; then
    echo "Error: CHAIN environment variable is not set"
    exit 1
fi

# Check if RPC_URL is set
if [ -z "$RPC_URL" ]; then
    echo "Error: RPC_URL environment variable is not set"
    exit 1
fi

# Check if the cast account was specified
if [ -z "$account" ]; then
    echo "Error: Cast account was not specified using --account. Set up using 'cast wallet'."
    exit 1
fi

# Check if the allowlist file was specified
if [ -z "$allowlist" ]; then
    echo "Error: Allowlist CSV file was not specified using --allowlist"
    exit 1
fi

# Check if the allowlist exists
if [ ! -f "$allowlist" ]; then
    echo "Error: Allowlist file $allowlist does not exist"
    exit 1
fi

# Check if the allowlist is a CSV file
if ! head -n 1 $allowlist | grep -qE '^address,amount$'; then
    echo "Error: Allowlist file $allowlist is not a valid CSV file with columns 'address' and 'amount'"
    exit 1
fi

# Get the address of the cast wallet
echo "Getting address for cast account $account"
CAST_ADDRESS=$(cast wallet address --account $account)
echo ""

echo "Chain: $CHAIN"
echo "RPC URL: $RPC_URL"
echo "Testnet: $TESTNET"
echo "Sender: $CAST_ADDRESS"

# Set BROADCAST_FLAG based on BROADCAST
BROADCAST_FLAG=""
if [ "$BROADCAST" = "true" ]; then
    BROADCAST_FLAG="--broadcast"
    echo "Broadcast: true"
else
    echo "Broadcast: false"
fi

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
