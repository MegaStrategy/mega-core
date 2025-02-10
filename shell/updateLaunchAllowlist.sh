#!/bin/bash

# Updates the metadata for the launch auction
# Usage: ./updateLaunchAllowlist.sh
#       --lotId <lotId>
#       --allowlist <allowlist file>
#       --merkleRoot <merkleRoot>
#       --account <cast account>
#       [--broadcast <true|false>]
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

# Validate named arguments
echo ""
echo "Validating arguments"
validate_number "$lotId" "No lotId specified or it was not a valid number. Provide the lotId after the --lotId flag."
validate_file "$allowlist" "No allowlist specified or it does not exist. Provide the path to the allowlist CSV file after the --allowlist flag."
validate_bytes32 "$merkleRoot" "No merkleRoot specified or it was not a valid bytes32 value. Provide the merkleRoot after the --merkleRoot flag."
validate_text "$account" "No account specified. Provide the cast wallet after the --account flag."

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
echo "  Account: $account"
echo "  Sender: $CAST_ADDRESS"
echo "  Chain: $CHAIN"
echo "  RPC URL: $RPC_URL"
echo "  LotId: $lotId"
echo "  Allowlist: $allowlist"
echo "  Merkle Root: $merkleRoot"

# Validate and set forge script flags
source $SCRIPT_DIR/lib/forge.sh
set_broadcast_flag $BROADCAST

LAUNCH_FILE="script/auctions/launch.json"

# Upload the auction metadata to IPFS
# This will set the IPFS_HASH environment variable
source $SCRIPT_DIR/lib/auctionMetadata.sh
upload_auction_metadata $LAUNCH_FILE $allowlist

# Run
echo ""
echo "Running the script"
forge script ./script/LaunchAuction.s.sol \
    --sig "updateAllowlist(string,uint96,bytes32,string)" $CHAIN $lotId $merkleRoot $IPFS_HASH \
    --rpc-url $RPC_URL \
    --account $account \
    --sender $CAST_ADDRESS \
    $BROADCAST_FLAG \
    --slow \
    -vvv

echo ""
echo "Allowlist updated"
