<p align="center">
 <img width="100px" src="https://www.gas.zip/_next/image?url=%2F_next%2Fstatic%2Fmedia%2FgasPump.e8ffd1df.png&w=128&q=75" align="center" />
 <h3 align="center">Gas.zip LayerZero v2<br>Gas Reloader</h3>
 <p align="center">Batched gas reloader for 50+ supported LayerZero v2 chains.</p>
</p>

### Overview

Gas.zip is the fastest one-stop gas refuel bridge for over 140+ chains. Gas.zip has a LayerZero gas reloader at [https://lz.gas.zip](https://lz.gas.zip), allowing users to bridge to mutiple LayerZero destination chains with a single inbound transaction. All software is licensed under MIT and is verified on-chain at the [respective addresses](https://dev.gas.zip/layerzero/chain-support/inbound). 

Additional documentation and implementations can be found at [https://dev.gas.zip](https://dev.gas.zip). 

### Depositing to Gas LayerZero v2

All `sendDeposits()` calls into the Gas LayerZero contract and must be encoded as a `uint256` where the leftmost 16 bits are the destination chain ID and the rightmost 240 bits are the amount (in `wei`) you'd like to recieve on the destination chain.

#### Example of Process

1. **Select the Source Chain**: Start by selecting your source chain to deposit from.

2. **Select the Destination Chains**: Select your destination chains to recieve funds. In the [example](/layerzero/v2/code-examples/completeFlow), these are Gnosis (v2 LZ chain ID 30145) and Fuse (v2 LZ chain ID 30138).

3. **Select the Amount**: Decide the amount of native currency you want to send to each chain. In the [example](/layerzero/v2/code-examples/completeFlow), 0.000002 ETH is the amount bridged to both Gnosis and Fuse. The Ether input for each chain must be converted to Wei.

4. **Estimate Fees**: Call the `estimateFees()` function with the correct parameters. This function takes three arguments: `v2LZids`, `messages` and `options`. The aggregated return from `estimateFees()` is used as a parameter in `sendDeposits()`.

5. **Check Wallet Balance**: Ensure your wallet balance exceeds the estimated fees plus the total value in Wei, else the contract will revert due to insufficent funds.

6. **Proceed with the Transaction**: After all the checks, proceed with the transaction by calling the `sendDeposits()` function with the correct parameters.

### Complete Flow Code Example v2

Below is a complete logic transaction flow into the LayerZero Gas.zip contract that handles `estimateFees()` prior to calling `sendDeposits()`.

```ts twoslash [viem]
// @filename: ./abis.ts
export const estimateFeesAbi = [
  {
    type: 'function',
    name: 'estimateFees',
    inputs: [
      {
        name: '_dstEids',
        type: 'uint32[]',
        internalType: 'uint32[]',
      },
      {
        name: '_messages',
        type: 'bytes[]',
        internalType: 'bytes[]',
      },
      {
        name: '_options',
        type: 'bytes[]',
        internalType: 'bytes[]',
      },
    ],
    outputs: [
      {
        name: 'nativeFees',
        type: 'uint256[]',
        internalType: 'uint256[]',
      },
    ],
    stateMutability: 'view',
  },
] as const

export const lzDepositAbi = [
  {
    inputs: [
      {
        internalType: 'uint256[]',
        name: '_depositParams',
        type: 'uint256[]',
      },
      {
        internalType: 'address',
        name: 'to',
        type: 'address',
      },
    ],
    name: 'sendDeposits',
    outputs: [],
    stateMutability: 'payable',
    type: 'function',
  },
] as const
```

### Example for `limits`

Every route combination has a specifc maximum it can send/recieve on the other side. If you exceed this amount, the contract will revert. Use the following to check what the maximum limit is on your desired destination chain.

**WARNING:** If a chain returns `0`, that means the inbound to outbound combination is not supported and the transaction will revert. The result must be > `0`.

```tsx twoslash [viem]
// @filename: ./abis.ts
export const limitsAbi = [
  {
    constant: true,
    inputs: [
      {
        name: '_key1',
        type: 'uint32',
      },
    ],
    name: 'dstConfig',
    outputs: [
      {
        components: [
          {
            name: 'baseGas',
            type: 'uint64',
          },
          {
            name: 'multiplier',
            type: 'uint16',
          },
          {
            name: 'floorMarginUSD',
            type: 'uint128',
          },
          {
            name: 'nativeCap',
            type: 'uint128',
          },
        ],
        type: 'tuple',
      },
    ],
    type: 'function',
  },
]
```

### Questions & Contact 

Please feel free to ask questions in the Gas.zip [Discord channel](https://discord.gg/gasdotzip) or DM us on [Twitter](https://twitter.com/gasdotzip). 
