# DecentralizedStableCoin and DSCEngine

## Introduction

Stablecoins are a type of cryptocurrency designed to minimize price volatility by pegging their value to a reserve asset, such as a fiat currency like the USD or commodities like gold. They play a crucial role in the cryptocurrency ecosystem by providing a stable medium of exchange, a store of value, and a unit of account. This stability is essential for facilitating everyday transactions, enabling predictable pricing, and serving as a safe haven during periods of high market volatility.

Popular examples of stablecoins include Tether (USDT), USD Coin (USDC), and DAI. Each of these stablecoins utilizes different mechanisms to maintain their peg, ranging from fiat reserves held in banks (USDT and USDC) to algorithmic and crypto-collateralized systems (DAI).

## DecentralizedStableCoin (DSC)

### Overview

The `DecentralizedStableCoin` (DSC) is a decentralized stablecoin pegged to the USD. It is designed to provide relative stability through an algorithmic control mechanism, which handles the minting and burning of tokens. The DSC is collateralized with exogenous assets like WBTC, WETH, and XAUT (gold tokens).

### Key Features

- **Decentralized Governance**: No centralized authority controls the minting and burning of DSC. Instead, this process is governed by the DSCEngine contract.
- **Collateralized System**: The system uses exogenous collateral such as WBTC, WETH, and XAUT to back the value of the DSC, ensuring stability and trust.
- **Algorithmic Stability Mechanism**: The DSCEngine algorithmically manages the minting and burning of DSC to maintain its peg to the USD.

## Contracts Overview

### List of Contracts and Their Roles

1. **DecentralizedStableCoin.sol**
   - **Role**: Implements the ERC20 standard for the Decentralized StableCoin (DSC) with additional functionalities such as burnable and ownable.
   - **Key Features**:
     - **Burnable**: Allows tokens to be burned, reducing the total supply.
     - **Ownable**: Enables control over owner-only functions.

2. **DSCEngine.sol**
   - **Role**: Serves as the core of the DSC system, managing all logic related to minting, burning, depositing, and withdrawing collateral.
   - **Key Features**:
     - **Collateral Management**: Allows users to deposit and redeem collateral tokens.
     - **Minting and Burning**: Handles the minting of new DSC tokens and burning of existing ones.
     - **Liquidation**: Manages the liquidation process if a user's health factor falls below a minimum threshold.

3. **DSCEngineTest.sol**
   - **Role**: Contains tests to verify the functionality and reliability of the DSCEngine and DecentralizedStableCoin contracts.
   - **Key Features**:
     - **Unit Tests**: Tests individual functions within the contracts.
     - **Integration Tests**: Ensures that different components of the system work together correctly.

4. **Invariants.sol**
   - **Role**: Ensures the stability and correctness of the DSC system through invariant testing.
   - **Key Features**:
     - **Invariant Checks**: Confirms that certain conditions always hold true throughout the contract's lifecycle.
     - **Security Tests**: Validates the security properties of the DSC system.

5. **Handler.sol**
   - **Role**: Manages user interactions and ensures the correct order of function calls in tests.
   - **Key Features**:
     - **Function Management**: Handles the sequence of operations such as depositing collateral, minting DSC, and more.
     - **Testing Support**: Facilitates complex testing scenarios for the DSC system.

6. **HelperConfig.sol**
   - **Role**: Provides configuration settings and mock deployments for different environments.
   - **Key Features**:
     - **Network Configuration**: Sets up network-specific configurations and addresses.
     - **Mock Deployments**: Deploys mock contracts for testing purposes.

7. **DeployDSC.sol**
   - **Role**: Script for deploying the DecentralizedStableCoin and DSCEngine contracts.
   - **Key Features**:
     - **Deployment Script**: Automates the deployment process for the core contracts.
     - **Configuration Integration**: Utilizes the HelperConfig settings for deployment.

---

This package provides a comprehensive suite of contracts and testing tools to ensure the robust functionality of the DecentralizedStableCoin system. Each contract plays a vital role in maintaining the stability, security, and usability of the DSC ecosystem.


## Installation

### Prerequisites

- [Node.js](https://nodejs.org/)
- [Yarn](https://yarnpkg.com/)
- [Foundry](https://github.com/foundry-rs/foundry)

### Clone the Repository

```bash
git clone https://github.com/yourusername/DecentralizedStableCoin.git
cd DecentralizedStableCoin
```

### Install Dependencies

```bash
yarn install
forge install
```
### Compile the Contracts

```bash
forge build
```
### Deploy the Contracts

```bash
forge script script/DeployDSC.s.sol:DeployDSC --fork-url <your_rpc_url> --broadcast
```
### Run Tests

```bash
forge test
```
## Contract Details
### DecentralizedStableCoin.sol

This contract implements the ERC20 standard with additional functionalities:

- **Burnable**: The token can be burned, reducing the total supply.
- **Ownable**: The contract ownership is controlled, enabling owner-only functions.

#### Constructor

```bash
constructor() ERC20("DecentralizedStableCoin", "DSC") Ownable(address(msg.sender)) {}
```
Initializes the token with the name "DecentralizedStableCoin" and the symbol "DSC", and sets the deployer as the initial owner.

Functions:

- `burn(uint256 _amount)`: Allows the owner to burn a specified amount of DSC, provided the amount is greater than zero and does not exceed the sender's balance.
- `mint(address _to, uint256 _amount)`: Allows the owner to mint a specified amount of DSC to a specified address, provided the amount is greater than zero and the address is not zero.

### DSCEngine.sol

This contract is the core of the DSC system, handling all logic for minting, burning, depositing, and withdrawing collateral.

#### Constructor
```bash
constructor(
    address[] memory tokenAddresses,
    address[] memory priceFeedAddresses,
    address _dscAddress
) {
    // Initialize the price feeds and collateral tokens
}
```

Functions:

- `depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)`: Allows users to deposit collateral tokens.
- `mintDSC(uint256 amountDscToMint)`: Allows users to mint DSC, provided they have sufficient collateral.
- `redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral)`: Allows users to redeem their collateral.
- `burnDSC(uint256 amount)`: Allows users to burn DSC to reduce their debt.
- `liquidate(address tokenCollateralAddress, address user, uint256 debtToCover)`: Allows the system to liquidate a user if their health factor is below the minimum threshold.

Events:

- `CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount)`: Emitted when a user deposits collateral.
- `CollateralRedeemed(address indexed redeemedFrom, address indexed redeemedTo, address indexed token, uint256 amount)`: Emitted when collateral is redeemed.

## Example Workflow
#### Deposit Collateral
```bash
ERC20(weth).approve(address(dscEngine), amount);
dscEngine.depositCollateral(weth, amount);
```
#### Mint DSC
```bash
dscEngine.mintDSC(amount);
```
#### Burn DSC
```bash
dscEngine.burnDSC(amount);
```
#### Redeem Collateral
```bash
dscEngine.redeemCollateral(xaut, amount);
```
#### Liquidation
```bash
dscEngine.liquidate(weth, user, debtToCover);
```

## Conclusion
The DecentralizedStableCoin and DSCEngine contracts provide a robust, decentralized solution for maintaining a stablecoin pegged to the USD. By leveraging exogenous collateral and algorithmic control mechanisms, DSC aims to offer stability, transparency, and security in the volatile cryptocurrency market.

## Licence
This project is licensed under the MIT License.