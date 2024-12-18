#!/bin/bash

# Creates an auction through the Banker policy
# Usage: ./createBankerAuction.sh --input <auctionFilePath> --account <cast account> --broadcast <true|false>
#
# Environment variables:
# RPC_URL
# CHAIN
# CLOAK_API_URL

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

# Check if the input argument exists
if [ -z "$input" ]; then
    echo "Error: --input argument is required to specify the auction input file"
    exit 1
fi

# Check if the input file exists
if [ ! -f "$input" ]; then
    echo "Error: auction input file $input does not exist"
    exit 1
fi

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

# Check if CLOAK_API_URL is set
if [ -z "$CLOAK_API_URL" ]; then
    echo "Error: CLOAK_API_URL environment variable is not set"
    exit 1
fi

# Check if the CLOAK_API_URL ends with a slash
if [ "${CLOAK_API_URL: -1}" != "/" ]; then
    # Append a slash to the CLOAK_API_URL
    CLOAK_API_URL="$CLOAK_API_URL/"
fi

# Check if the cast account was specified
if [ -z "$account" ]; then
    echo "Error: Cast account was not specified using --account. Set up using 'cast wallet'."
    exit 1
fi

# Get the address of the cast wallet
echo "Getting address for cast account $account"
CAST_ADDRESS=$(cast wallet address --account $account)
echo ""

echo "Auction input file: $input"
echo "Chain: $CHAIN"
echo "RPC URL: $RPC_URL"
echo "Sender: $CAST_ADDRESS"

# Set BROADCAST_FLAG based on BROADCAST
BROADCAST_FLAG=""
if [ "$BROADCAST" = "true" ]; then
    BROADCAST_FLAG="--broadcast"
    echo "Broadcast: true"
else
    echo "Broadcast: false"
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
echo "If nothing happens, you may need to run 'npx fleek login' to authenticate, and then select a project using 'npx fleek projects select'"
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
forge script script/BankerAuction.s.sol --sig "create(string,string,string)()" $CHAIN $input $IPFS_HASH --rpc-url $RPC_URL --account $account --froms $CAST_ADDRESS $BROADCAST_FLAG -vvv
