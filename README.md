# Token Sale Distributor

## Overview
The Token Sale Distributor is a smart contract system designed to manage the distribution of tokens during a token sale. It allows for the allocation of tokens to various recipients, ensuring that the distribution is handled securely and efficiently.

## Features
- **Token Allocation**: Admins can set allocations for multiple recipients.
- **Vesting Schedule**: Supports both linear and monthly vesting schedules.
- **Claiming Tokens**: Recipients can claim their vested tokens.
- **Admin Management**: Admins can change the contract's admin and implementation.

## Smart Contracts
- **TokenSaleDistributor**: Main contract that handles token allocations and claims.
- **TokenSaleDistributorProxy**: Proxy contract that allows for upgradable implementations.
- **TokenSaleDistributorStorage**: Storage contract that holds the state variables.
- **TokenSaleDistributorProxyStorage**: Storage for the proxy contract.

## Getting Started

### Prerequisites
- Node.js (version >= 12.x)
- npm (Node package manager)

### Installation
1. Clone the repository:
   ```bash
   git clone https://github.com/forchain/token-sale-distributor.git
   cd token-sale-distributor
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

### Running the Project
1. Start the Hardhat local network:
   ```bash
   npx hardhat node
   ```

2. Deploy the contracts:
   ```bash
   npx hardhat run scripts/deploy.js --network localhost
   ```

## Testing

### Running Tests
To run the tests for the Token Sale Distributor, follow these steps:

1. Ensure that the Hardhat local network is running:
   ```bash
   npx hardhat node
   ```

2. In a new terminal window, run the tests:
   ```bash
   npx hardhat test
   ```

### Test Cases
The tests include:
- **Withdrawal Functionality**: Verifies that only the admin can withdraw tokens from the contract.
- **Access Control**: Ensures that non-admin users cannot withdraw tokens.

## Interacting with the Contracts
- Use the Hardhat console or write scripts to interact with the deployed contracts.
- Ensure you have the correct admin privileges to call restricted functions.

## Usage
- Admins can set allocations for users using the `setAllocations` function.
- Users can claim their tokens using the `claim` function.

## License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments
- OpenZeppelin for their secure smart contract libraries.