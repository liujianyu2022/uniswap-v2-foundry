## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

```shell
$ forge build
$ forge test
$ forge fmt
$ forge snapshot
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>

$ anvil
$ cast <subcommand>

$ forge --help
$ anvil --help
$ cast --help
```

## dependency

```shell
$ forge install ethers-io/ethers.js --no-commit                     // install ethersjs
$ forge install OpenZeppelin/openzeppelin-contracts --no-commit     // install openzepplin
```
