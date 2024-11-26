#!/bin/bash

# Usage:
# ./banker_salts.sh --env <.env>
#
# Expects the following environment variables:
# CHAIN: The chain to deploy to, based on values from the ./script/env.json file.

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

# Check that the CHAIN environment variable is set
if [ -z "$CHAIN" ]; then
    echo "CHAIN environment variable is not set. Please set it in the .env file or provide it as an environment variable."
    exit 1
fi

echo "Using chain: $CHAIN"

forge script script/salts/banker/BankerSalts.s.sol:BankerSalts --sig "generate(string)()" $CHAIN
