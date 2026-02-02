# LUKSO LSP Integrations & Patterns

Solidity code examples of how to use the LUKSO LSP smart contracts and ideas of what can be built with them.

## Getting started

1. [Install foundry](https://getfoundry.sh/).

2. Install the [**`bun`** package manager](https://bun.sh/package-manager).

3. Install the dependencies

```bash
forge install
bun install
```

## Development

### Add new packages

You can install new packages and dependencies using **`bun`** or Foundry.

```bash
bun add @remix-project/remixd
```

### Build

To generate the artifacts (contract ABIs and bytecode), simply run:

```shell
bun run build
```

The contract ABIs will placed under the `artifacts/` folder.

### Testing with mainnet fork

The best way to test these LSP integrations is to write the Foundry tests with addresses of contracts and user's Universal Profile from LUKSO Mainnet and perform the tests with Foundry mainnet fork testing mode.

```shell
forge test --fork-url https://rpc.mainnet.lukso.network --match-contract AutomaticSLYXSwapAfterNFTSalesTest
```

### Format Solidity code

```shell
bun run format
```

The formatting rules can be adjusted in the [`foundry.toml`](./foundry.toml) file, under the `[fmt]` section.

<!-- ### Gas Snapshots

```shell
forge snapshot
``` -->

<!-- ### Anvil

```shell
$ anvil
```
-->

## Documentation

This template repository is based on Foundry, **a blazing fast, portable and modular toolkit for EVM application development written in Rust.** It includes:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

You can find more documentation at: https://book.getfoundry.sh/
