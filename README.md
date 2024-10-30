[![Mentioned in Awesome Foundry](https://awesome.re/mentioned-badge-flat.svg)](https://github.com/crisgarner/awesome-foundry)
# NFT Collateralized Lending Platform

## All Tests Pass for `NFTManagementFacet`

![alt text](screenshots/NFTManagementFacetTests.png)

## All Tests Pass for `CollateralManagerFacet`

![alt text](screenshots/CollateralManagerFacetTests.png)

## All Tests Pass for `LendingFacet`

![alt text](screenshots/LendingFacetTests.png)

## All Tests Pass for `TreasuryFacet`

![alt text](screenshots/TreasuryFacetTests.png)

This is a mimimal template for [Diamonds](https://github.com/ethereum/EIPs/issues/2535) which allows facet selectors to be generated on the go in solidity tests!

## Installation

- Clone this repo
- Install dependencies

```bash
$ yarn && forge update
```

### Compile

```bash
$ npx hardhat compile
```

## Deployment

### Hardhat

```bash
$ npx hardhat run scripts/deploy.js
```

### Foundry

```bash
$ forge t
```

`Note`: A lot of improvements are still needed so contributions are welcome!!

Bonus: The [DiamondLoupefacet](contracts/facets/DiamondLoupeFacet.sol) uses an updated [LibDiamond](contracts/libraries//LibDiamond.sol) which utilises solidity custom errors to make debugging easier especially when upgrading diamonds. Take it for a spin!!

Need some more clarity? message me [on twitter](https://twitter.com/Timidan_x), Or join the [EIP-2535 Diamonds Discord server](https://discord.gg/kQewPw2)
