# MegaStrategy

MegaStrategy is a system to create a token that allows for leveraged exposure to the backing assets.

## Wallet Configuration

A wallet must be configured with `cast wallet` before deploying or interacting with the system.

## Deployment

Use the `script/deploy/deploy.sh` script to deploy the system.

The following must be performed to deploy and activate the system:

1. Deploy the system using the `deploy.sh` script
2. Install the modules and policies into the Kernel using the `kernelInstallation.sh` script
3. Grant admin and manager roles using the `Tasks.s.sol` script

-   e.g. `forge script ./script/Tasks.s.sol --sig "addAdmin(string,address)()" base-sepolia <ADMIN_ADDRESS> --rpc-url <RPC_URL> --account <CAST_ACCOUNT> --froms <SIGNER_ADDRESS> --slow -vvv --broadcast`

4. Initialize the Banker using the `Tasks.s.sol` script

## Tasks

Use the `script/Tasks.s.sol` script to perform tasks such as creating option tokens and issuing them.
