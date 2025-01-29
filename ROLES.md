# ROLES

This document describes the roles that are used in the MegaStrategy protocol.

## Role Definitions

| Role | Policy | Actions |
|------|----------|-------------|
| admin | RolesAdmin | Grant and revoke roles to addresses, push new admin addresses |
| admin | Banker | Initialize and shutdown the Banker policy |
| admin | Emergency | Emergency shutdown/restart of treasury withdrawals and minting |
| admin | Issuer | Create and issue option tokens (oTokens) |
| admin | PriceConfig | Install and upgrade price submodules |
| manager | Banker | Create and manage debt token auctions |
| manager | Issuer | Reclaim expired option tokens, sweep proceeds to treasury |
| manager | PriceConfig | Update price feeds and strategies, update asset moving averages, execute actions on price submodules |
| custodian | TreasuryCustodian | Grant/reduce withdrawer approvals, grant/reduce debtor approvals, withdraw reserves, manage debt levels, revoke policy approvals |
