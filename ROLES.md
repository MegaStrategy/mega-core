# ROLES

This document describes the roles that are used in the MegaStrategy protocol.

## Role Definitions

| Role      | Policy            | Actions                                                                                                  |
| --------- | ----------------- | -------------------------------------------------------------------------------------------------------- |
| admin     | Banker            | Initialize the Banker policy                                                                             |
| admin     | Issuer            | Activate the policy. Create and issue option tokens (oTokens)                                            |
| admin     | PriceConfig       | Install and upgrade price submodules                                                                     |
| admin     | RolesAdmin        | Grant and revoke roles to addresses, push new admin addresses                                            |
| admin     | TreasuryCustodian | Grant/reduce withdrawer/debtor approvals, withdraw reserves, manage debt levels, revoke policy approvals |
| emergency | Banker            | Shutdown the Banker policy                                                                               |
| emergency | Emergency         | Emergency shutdown of treasury withdrawals and minting                                                   |
| emergency | Issuer            | Shutdown the Issuer policy                                                                               |
| manager   | Banker            | Create and manage debt token auctions                                                                    |
| manager   | Issuer            | Reclaim expired option tokens, sweep proceeds to treasury                                                |
| manager   | PriceConfig       | Update price feeds and strategies, update asset moving averages, execute actions on price submodules     |
