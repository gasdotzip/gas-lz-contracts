<p align="center">
 <img width="100px" src="https://www.gas.zip/gasLogo400x400.png" align="center" />
 <h3 align="center">Gas.zip LayerZero v2<br>Gas Reloader</h3>
 <p align="center">Batched gas reloader for 50+ supported LayerZero v2 chains.</p>
</p>

### Overview

Gas.zip is the fastest one-stop gas refuel bridge for over 200+ chains. Gas.zip has a LayerZero gas reloader at [https://lz.gas.zip](https://lz.gas.zip), allowing users to bridge to mutiple LayerZero destination chains with a single inbound transaction. All software is licensed under MIT and is verified on-chain at the [respective addresses](https://dev.gas.zip/layerzero/chain-support/inbound). 

Additional documentation and implementations can be found at [https://dev.gas.zip](https://dev.gas.zip). 

### Depositing to Gas LayerZero v2

All `sendDeposits()` calls into the Gas LayerZero contract and must be encoded as a `uint256` where the leftmost 16 bits are the destination chain ID and the rightmost 240 bits are the amount (in `wei`) you'd like to recieve on the destination chain.

#### Example of Process

1. **Select the Source Chain**: Start by selecting your source chain to deposit from.

2. **Select the Destination Chains**: Select your destination chains to recieve funds. In the [example](https://dev.gas.zip/layerzero/v2/code-examples/completeFlow), these are Gnosis (v2 LZ chain ID 30145) and Fuse (v2 LZ chain ID 30138).

3. **Select the Amount**: Decide the amount of native currency you want to send to each chain. In the [example](https://dev.gas.zip/layerzero/v2/code-examples/completeFlow), 0.000002 ETH is the amount bridged to both Gnosis and Fuse. The Ether input for each chain must be converted to Wei.

4. **Estimate Fees**: Call the `estimateFees()` function with the correct parameters. This function takes three arguments: `v2LZids`, `messages` and `options`. The aggregated return from `estimateFees()` is used as a parameter in `sendDeposits()`.

5. **Check Wallet Balance**: Ensure your wallet balance exceeds the estimated fees plus the total value in Wei, else the contract will revert due to insufficent funds.

6. **Proceed with the Transaction**: After all the checks, proceed with the transaction by calling the `sendDeposits()` function with the correct parameters.

### Complete Flow Code Example v2

Below is a complete logic transaction flow into the LayerZero Gas.zip contract that handles `estimateFees()` prior to calling `sendDeposits()`.

```ts twoslash [viem]
import { encodePacked, parseEther, http, createWalletClient, publicActions } from 'viem'
import { optimism } from 'viem/chains'
import { privateKeyToAccount } from 'viem/accounts'
import { estimateFeesAbi, lzDepositAbi } from './abis'
 
const account = privateKeyToAccount('0x...')
 
const client = createWalletClient({
  account,
  chain: optimism,
  transport: http(),
}).extend(publicActions)
 
type ChainParams = {
  [key: string]: {
    v2LZid: number
    chainId: string
    valueInEther: string
  }
}
 
const contractParams: ChainParams = {
  gnosis: {
    v2LZid: 30145,
    chainId: '100',
    valueInEther: '0.000002',
  },
  fuse: {
    v2LZid: 30138,
    chainId: '122',
    valueInEther: '0.000002',
  },
}
 
// Estimate
const createReceiveOptions = (gasLimit: bigint) => {
  return encodePacked(
    ['bytes', 'uint8', 'uint16', 'uint8', 'bytes'],
    [encodePacked(['uint16'], [3]), 1, 16 + 1, 1, encodePacked(['uint128'], [gasLimit])],
  )
}
 
const createNativeOptions = (gasLimit: bigint, amount: bigint, to: string) => {
  return encodePacked(
    ['bytes', 'uint8', 'uint16', 'uint8', 'bytes'],
    [
      createReceiveOptions(gasLimit),
      1,
      32 + 16 + 1,
      2,
      encodePacked(['uint128', 'bytes32'], [amount, `0x${to.slice(2).padStart(64, '0')}` as `0x${string}`]),
    ],
  )
}
 
async function estimateFees(): Promise<bigint> {
  const nullAddress = '0x0000000000000000000000000000000000000000'
  const feeChains: {
    v2LZid: number
    chainId: string
  }[] = []
  const options: `0x${string}`[] = []
  const messages: `0x${string}`[] = []
 
  for (const chain in contractParams) {
    const selection = contractParams[chain]
    feeChains.push({
      v2LZid: selection.v2LZid,
      chainId: selection.chainId,
    })
    options.push(createNativeOptions(BigInt(20_000), parseEther(selection.valueInEther), nullAddress))
    messages.push('0x')
  }
 
  let fees: bigint[] = []
  try {
    const v2LZids = feeChains.map((feeChain) => feeChain.v2LZid)
 
    fees = (await client.readContract({
      address: '0x26DA582889f59EaaE9dA1f063bE0140CD93E6a4f',
      abi: estimateFeesAbi,
      functionName: 'estimateFees',
      args: [v2LZids, messages, options],
    })) as bigint[]
  } catch (error) {
    console.error('Read Contract Error', error)
  }
 
  const lzFees = fees.reduce((p, c) => p + c, BigInt(0))
  return lzFees
}
 
// Deposit
const createOptimizedAdapterParams = (dstChainId: bigint, nativeAmount: bigint) => {
  return (dstChainId << BigInt(224)) | nativeAmount
}
 
;(async () => {
  const lzFee = await estimateFees()
  const adapterParamsDeposit: bigint[] = []
  for (const chain in contractParams) {
    const selection = contractParams[chain]
    adapterParamsDeposit.push(
      createOptimizedAdapterParams(BigInt(selection.v2LZid), parseEther(selection.valueInEther)),
    )
  }
 
  const { request } = await client.simulateContract({
    address: '0x26DA582889f59EaaE9dA1f063bE0140CD93E6a4f',
    abi: lzDepositAbi,
    functionName: 'sendDeposits',
    value: lzFee,
    args: [adapterParamsDeposit, account.address],
  })
 
  await client.writeContract(request)
})().catch((error) => console.error(error))

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
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'
import { limitsAbi } from './abis'
 
const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
 
const lzId = 30110
 
async function getLimit(lzId: number): Promise<bigint> {
  const config = (await client.readContract({
    address: '0x90E595783E43eb89fF07f63d27B8430e6B44bD9c', // executor
    abi: limitsAbi,
    functionName: 'dstConfig',
    args: [lzId],
  })) as bigint[]
 
  return config[3]
}
 
getLimit(lzId)
  .then((limit) => {
    console.log(`The limit is: ${limit}`)
  })
  .catch((error) => console.error(error))

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
