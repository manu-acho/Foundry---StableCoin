



## Stable Coin Characteristics
1. Relative Stability: Anchored/Pegged to the USD > $1.00
    1. Implement Chainlink Price feed to retrieve asset prices in USD
    2. Define a function to exchange ETH & BTC to their USD equivalent
2. Stability Mechanism (Minting): Algorithmic (Decentralised)
    1. The stable coin can only be minted with enough collateral
3. Collateral: Exogenous (Crypto)
    1. wEth
    2. wBTC

## Contract Layout
// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions



## IERC20 Standard
The IERC20 standard is a set of functions and events defined in an Ethereum interface that outlines specific rules and behaviors for issuing and managing fungible tokens on the Ethereum blockchain. This standard provides a blueprint for creating interoperable contracts in the Ethereum ecosystem.
Key Components of the IERC20 Standard

The IERC20 interface includes the following methods and events: 
# Methods:

    totalSupply: Returns the total token supply.
    balanceOf: Provides the number of tokens held by a given address.
    transfer: Transfers a specific amount of tokens to a specified address, and returns a boolean value indicating success.
    transferFrom: Allows a contract or another address to transfer tokens on behalf of the token holder if they have been previously allowed to do so via the approve method.
    approve: Allows a spender to withdraw a specified amount of tokens repeatedly from your account up to the approved amount. If this function is called again it overwrites the current allowance with a new amount.
    allowance: Returns the amount which a spender is still allowed to withdraw from an owner.

# Events:

    Transfer(address indexed from, address indexed to, uint256 value): Must be triggered when tokens are transferred, including zero value transfers.
    Approval(address indexed owner, address indexed spender, uint256 value): Must be triggered on any successful call to approve(address spender, uint256 value).

# Purpose of the IERC20 Standard

The primary purpose of the IERC20 standard is to ensure that different token implementations are interoperable across the Ethereum network. It allows various applications including wallets, decentralized exchanges, and distributed finance applications to handle tokens across multiple interfaces and contracts without needing to know the specific implementation details of each token.
