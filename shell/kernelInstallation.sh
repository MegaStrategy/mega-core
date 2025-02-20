#!/bin/bash

# Usage: ./kernelInstallation.sh --chain <chain> --env <env> --account <account> --broadcast <true|false>
#
# Environment variables:
# - RPC_URL
# - CHAIN

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

# Apply defaults to command-line arguments
BROADCAST=${broadcast:-false}

# Check that the CHAIN environment variable is set
if [ -z "$CHAIN" ]; then
    echo "CHAIN environment variable is not set. Please set it in the .env file or provide it as an environment variable."
    exit 1
fi

# Check that the forge account is set
if [ -z "$account" ]; then
    echo "Error: account is not set"
    exit 1
fi

# Check that the RPC URL is set
if [ -z "$RPC_URL" ]; then
    echo "Error: RPC_URL is not set"
    exit 1
fi

echo "Chain: $CHAIN"
echo "Using RPC at URL: $RPC_URL"
echo "Using forge account: $account"

# Set BROADCAST_FLAG based on BROADCAST
BROADCAST_FLAG=""
if [ "$BROADCAST" = "true" ] || [ "$BROADCAST" = "TRUE" ]; then
    BROADCAST_FLAG="--broadcast"
    echo "Broadcast: enabled"
else
    echo "Broadcast: disabled"
fi

forge script ./script/deploy/Deploy.s.sol:Deploy \
    --sig "kernelInstallation(string)()" $CHAIN \
    --rpc-url $RPC_URL --account $account --slow -vvv \
    $BROADCAST_FLAG
