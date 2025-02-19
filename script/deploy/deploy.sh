#!/bin/bash

# Usage:
# ./deploy.sh --sequence <sequence-file> --account <account> --broadcast <false> --verify <false> --resume <false> --env <.env>
#
# Environment variables:
# CHAIN:              Chain name to deploy to. Corresponds to names in "./script/env.json".
# ETHERSCAN_API_KEY:  API key for Etherscan verification. Should be specified in .env.
# RPC_URL:            URL for the RPC node. Should be specified in .env.
# VERIFIER_URL:       URL for the Etherscan API verifier. Should be specified when used on an unsupported chain.
# PRIVATE_KEY:        Private key for the deployer account. Should be specified in .env.

# Exit if there is an error
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

# Apply defaults to command-line arguments
SEQUENCE_FILE=$sequence
BROADCAST=${broadcast:-false}
VERIFY=${verify:-false}
RESUME=${resume:-false}

# Check that the CHAIN environment variable is set
if [ -z "$CHAIN" ]; then
    echo "CHAIN environment variable is not set. Please set it in the .env file or provide it as an environment variable."
    exit 1
fi

# Check if SEQUENCE_FILE is set
if [ -z "$SEQUENCE_FILE" ]; then
    echo "No sequence file specified. Provide the relative path after the command."
    exit 1
fi

# Check if SEQUENCE_FILE exists
if [ ! -f "$SEQUENCE_FILE" ]; then
    echo "Sequence file ($SEQUENCE_FILE) not found. Provide the correct relative path after the command."
    exit 1
fi

# Check that the forge account is set
if [ -z "$account" ]; then
    echo "Error: account is not set"
    exit 1
fi

# Get the address of the cast wallet
echo ""
echo "Getting address for cast account $account"
CAST_ADDRESS=$(cast wallet address --account $account)

echo "Sequence file: $SEQUENCE_FILE"
echo "Chain: $CHAIN"
echo "Using RPC at URL: $RPC_URL"
echo "Using forge account: $account"
echo "Sender: $CAST_ADDRESS"

# Set BROADCAST_FLAG based on BROADCAST
BROADCAST_FLAG=""
if [ "$BROADCAST" = "true" ] || [ "$BROADCAST" = "TRUE" ]; then
    BROADCAST_FLAG="--broadcast"
    echo "Broadcast: enabled"
else
    echo "Broadcast: disabled"
fi

# Set VERIFY_FLAG based on VERIFY
VERIFY_FLAG=""
if [ "$VERIFY" = "true" ] || [ "$VERIFY" = "TRUE" ]; then

    # Check if ETHERSCAN_API_KEY is set
    if [ -z "$ETHERSCAN_API_KEY" ]; then
        echo "No Etherscan API key found. Provide the key in .env or disable verification."
        exit 1
    fi

    if [ -n "$VERIFIER_URL" ]; then
        echo "Using verifier at URL: $VERIFIER_URL"
        VERIFY_FLAG="--verify --etherscan-api-key $ETHERSCAN_API_KEY --verifier-url $VERIFIER_URL"
    else
        echo "Using standard verififer"
        VERIFY_FLAG="--verify --etherscan-api-key $ETHERSCAN_API_KEY"
    fi

    echo "Verification: enabled"
else
    echo "Verification: disabled"
fi

# Set RESUME_FLAG based on RESUME
RESUME_FLAG=""
if [ "$RESUME" = "true" ] || [ "$RESUME" = "TRUE" ]; then
    RESUME_FLAG="--resume"
    echo "Resume: enabled"
else
    echo "Resume: disabled"
fi

# Deploy using script
forge script ./script/deploy/Deploy.s.sol:Deploy \
    --sig "deploy(string,string)()" $CHAIN $SEQUENCE_FILE \
    --rpc-url $RPC_URL --account $account --slow -vvv \
    --sender $CAST_ADDRESS \
    $BROADCAST_FLAG \
    $VERIFY_FLAG \
    $RESUME_FLAG

# Lint
pnpm run lint
