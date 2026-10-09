# Deploy notes — BITFIRST

Nothing here has been executed on a public network yet. These are the steps.

## 1. Testnet (free)

- Faucet: https://www.bnbchain.org/en/testnet-faucet  (needs ~0.1 tBNB only)
- Network: BSC Testnet, chain ID **97**
- RPC: https://data-seed-prebsc-1-s1.bnbchain.org:8545
- Explorer: https://testnet.bscscan.com

## 2. Compiler settings (must match for verification)

| Setting | Value |
|---|---|
| Solidity | 0.8.24 |
| Optimizer | enabled |
| Runs | 200 |
| EVM version | default for 0.8.24 |
| Licence | MIT |

## 3. Constructor arguments (order matters)

```
communityLock      0x...   -> CommunityLock / OwnerReleaseVault address
liquidityWallet    0x...   -> your liquidity wallet
teamVesting        0x...   -> TeamVesting contract address
developmentWallet  0x...   -> your development wallet
schoolWallet       0x...   -> school wallet
charityWallet      0x...   -> charity wallet
```

All six must be different, non-zero addresses. The constructor reverts otherwise.

## 4. Mainnet

Same steps, chain ID **56**. Gas is real BNB. Deploy is cheap; the **liquidity
pool is the real cost** and it is the only step that actually needs money.

## 5. Before any of this

- Legal / compliance review for your jurisdiction (in India: FIU-IND / PMLA angle).
- A second pair of eyes on the contracts — compiling clean is not an audit.
