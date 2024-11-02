# CraftMeme 🚀

Welcome to MemeCoin Launchpad, a decentralized platform where users can create and launch their own ERC-20 memecoins, provide liquidity via Uniswap, and enjoy safe, controlled token vesting to minimize potential bad actors in the space. This project was built for the QuickNode Hackathon and utilizes various QuickNode services to streamline operations and ensure a smooth user experience.

<p align="center">
<img src="./images/CraftMeme.webp" width="500" alt="Name">
</p>

- [CraftMeme 🚀](#craftmeme-)
  - [Overview](#overview)
  - [Deployed Contracts on Base Sepolia](#deployed-contracts-on-base-sepolia)
  - [Deployed Contracts on ETH Sepolia](#deployed-contracts-on-eth-sepolia)
  - [Project Architecture](#project-architecture)
  - [Core Features](#core-features)
    - [ERC-20 Factory](#erc-20-factory)
    - [Uniswap Liquidity Integration](#uniswap-liquidity-integration)
    - [Liquidity Thresholds](#liquidity-thresholds)
    - [Token Vesting](#token-vesting)
    - [Multisignature Governance](#multisignature-governance)
      - [Security Features](#security-features)
  - [Technology Stack](#technology-stack)
  - [QuickNode Integrations](#quicknode-integrations)
    - [QuickNode RPCs](#quicknode-rpcs)
    - [QuickNode Alerts](#quicknode-alerts)
    - [QuickNode IPFS Pinning](#quicknode-ipfs-pinning)
    - [Sign Protocol Attestations and Schemas](#sign-protocol-attestations-and-schemas)
  - [Smart Contracts](#smart-contracts)
    - [Factory Contract](#factory-contract)
    - [Vesting Contract](#vesting-contract)
    - [Multisig Contract](#multisig-contract)
  - [Potential Future Enhancements](#potential-future-enhancements)
  - [Future Scope](#future-scope)
    - [Enhanced QuickNode Integrations](#enhanced-quicknode-integrations)
    - [Multi-chain Expansion](#multi-chain-expansion)
  - [License](#license)

## Overview

MemeCoin Launchpad is designed to be a simple, secure, and user-friendly platform where users can create and launch ERC-20 meme tokens, provide liquidity via Uniswap, and ensure fair distribution using a vesting mechanism. Our goal is to build a reliable launchpad for meme tokens that not only enables users to create and trade tokens but also prevents bad actors from executing rugpulls or scams.

This platform integrates with QuickNode services, Uniswap, and OpenZeppelin libraries to provide a seamless token creation and liquidity experience.

## Deployed Contracts on Base Sepolia

- MultiSigContract : https://base-sepolia.blockscout.com/address/0xc3D976e1d4B8B4bf8361bAED9928E5df546d18c3?tab=write_contract
- VestingContract : https://base-sepolia.blockscout.com/address/0x13caa03C683825c31C3429c8ecD58c15D6FbD2f1?tab=contract
- LiquidityManager : https://base-sepolia.blockscout.com/address/0x432891844dD3215844B47827d5A6581c4Cb72378?tab=contract
- FactoryTokenContract : https://base-sepolia.blockscout.com/address/0xd47BDd29C984722B229141dE99C80c210de04E02?tab=read_contract

## Deployed Contracts on ETH Sepolia

- MultiSigContract : https://eth-sepolia.blockscout.com/address/0x14636fe21e5AB1071768218ce59358d238462212
- VestingContract : https://eth-sepolia.blockscout.com/address/0x510a34176fC0CAfD03a7386a77aeE41aC7bd7a09
- LiquidityManager : https://eth-sepolia.blockscout.com/address/0x87B8A985EBE3B44E6eF06fA938bD8B4202DDD2dF
- FactoryTokenContract : https://eth-sepolia.blockscout.com/address/0x4C43423d55dBa56370448468096cEA3B3cC2e88A

## Project Architecture

The project consists of the following main components:

1. ERC-20 Token Factory: A smart contract factory for users to create their own meme tokens.
2. Liquidity Integration with Uniswap: Allows token creators to provide initial liquidity and facilitate trades on Uniswap.
3. Vesting Contracts: To ensure that liquidity providers receive their tokens gradually over a set period to prevent rugpulls.
4. Multisignature Contract Ownership: Enhanced security for token creators by requiring multiple signers to approve changes to the token contract.

<p align="center">
<img src="./images/Architectrure.PNG" width="1250" alt="Project">
</p>

## Core Features

### ERC-20 Factory

The MemeCoin Launchpad allows users to create their own meme tokens through an ERC-20 token factory. The factory contract uses the OpenZeppelin ERC-20 library for reliable and secure token implementation.

- Parameters:
  - Token Name
  - Token Symbol
  - initial Supply
  - Token Owner
  - Additional parameters like minting, burning, and custom fee mechanisms can be added if needed.

### Uniswap Liquidity Integration

Once a meme token is created, the token creator can choose to provide liquidity through Uniswap. This feature allows the token to be traded on the decentralized exchange, creating a marketplace for buying and selling meme tokens.

- Initial Liquidity: Users can provide a minimum amount of testnet USDC/USDT tokens (e.g., 20 USDC/USDT) to meet the liquidity threshold.
- If the liquidity threshold is not met, the token will not be tradeable on Uniswap until the threshold is achieved.

### Liquidity Thresholds

To ensure that meme tokens are liquid enough to be traded fairly, the platform requires a minimum liquidity threshold (e.g., 20 USDC/USDT). Once this threshold is met, the tokens become eligible for trade on Uniswap.

### Token Vesting

To prevent sudden dumps and rugpulls, MemeCoin Launchpad implements a vesting schedule for tokens purchased during the initial liquidity provision. The purchased tokens are locked and gradually released over a 10-month period. This helps maintain price stability and encourages long-term holding.

- Vesting Breakdown:
  - Month 1: 8% of the purchased tokens released
  - Gradual increase each month, with full release by Month 10.

### Multisignature Governance

For added security, meme tokens created on the platform will have multisignature governance. This ensures that no single individual can make malicious changes or drain the contract. Multiple signers must approve actions related to the contract, such as minting or changing ownership.

#### Security Features

- Rugpull Protection: Vesting contracts ensure that liquidity providers receive their tokens over time, preventing sudden mass sell-offs.
- Multisig Ownership: Requires multiple signers for sensitive actions, preventing a single point of failure.
- OpenZeppelin Libraries: The token contracts utilize well-audited OpenZeppelin libraries to ensure security and compliance with ERC-20 standards.

## Technology Stack

- Smart Contracts: Solidity, OpenZeppelin ERC-20, Sign Protocol
- Uniswap V4: Liquidity pool creation and token swapping
- Blockscout: Smart Contract Deployment and Verifications
- QuickNode Services: Various integrations for enhanced functionality (IPFS Pinning, RPCs, etc.)
- Frontend: Next.js, Wagmi for interacting with smart contracts
- Testnets: Ethereum Sepolia, Base Sepolia for development and testing

## QuickNode Integrations

Our platform leverages several QuickNode services to enhance functionality and security:

### QuickNode RPCs

We utilize QuickNode RPCs for fast and reliable blockchain interactions, enabling efficient communication between our frontend and smart contracts.

### QuickNode Alerts

We integrate QuickNode Alerts to track wallet activities and important events on the blockchain, providing real-time monitoring and notifications for critical transactions.

### QuickNode IPFS Pinning

We use QuickNode IPFS Pinning to store and serve metadata associated with meme tokens, ensuring persistent and decentralized storage of token information.

### Sign Protocol Attestations and Schemas

We incorporate Sign Protocol Attestations and Schemas to verify user identities and ensure the authenticity of transactions, adding an extra layer of security to our platform.

## Smart Contracts

### Factory Contract

The ERC-20 Factory allows users to create meme tokens on demand.

- Functions:
  - createToken(name, symbol, initialSupply, owner)
  - provideLiquidity(tokenAddress, amount)

### Vesting Contract

Handles the gradual release of tokens to prevent sudden sell-offs.

- Functions:
  - lockTokens(user, amount, duration)
  - releaseTokens(user)

### Multisig Contract

Provides security for memetoken owners by requiring multiple approvals for sensitive actions.

- Functions:
  - addSigner(address)
  - removeSigner(address)
  - approveTransaction()

## Potential Future Enhancements

- Staking: Introduce staking pools where memecoin holders can earn rewards for holding their tokens.
- Cross-chain Support: Expand to other blockchains (e.g., Polygon, BSC) to widen the reach of meme tokens.
- Governance: Allow memetoken holders to vote on project-related decisions using a decentralized governance model.

## Future Scope

As we continue to develop and expand CraftMeme, we plan to incorporate more advanced QuickNode integrations and transition to a multi-chain architecture. Our future plans include:

### Enhanced QuickNode Integrations

1. **QuickNode Streams**: Implement real-time data streaming to provide instant updates on token liquidity, trades, and wallet activities. This will enable features like:
   - Real-time price tracking
   - Instant notifications for significant events (e.g., liquidity threshold reached, large transactions)
   - Dynamic dashboard updates reflecting the latest blockchain data

2. **QuickNode Functions**: Leverage serverless computing to offload complex calculations and automate processes, including:
   - Advanced analytics and market trend analysis
   - Automated smart contract interactions
   - Customizable transaction processing workflows

3. **QuickNode Alerts**: Expand our alert system to cover a wider range of events and conditions, allowing for:
   - Customizable notification triggers based on user preferences
   - Multi-channel alerts (webhook, email, mobile push notifications)
   - Advanced filtering and prioritization of alerts

### Multi-chain Expansion

We aim to extend CraftMeme's functionality across multiple blockchain networks, providing:

1. **Cross-chain Token Creation**: Enable users to create meme tokens on multiple chains simultaneously.
2. **Interoperability Features**: Implement cross-chain swaps and transfers for meme tokens.
3. **Chain Agnostic Wallet Management**: Develop a unified interface for managing meme tokens across different blockchain networks.
4. **Multi-chain Analytics**: Provide comprehensive analytics and insights aggregated from multiple blockchain sources.

These enhancements will transform CraftMeme into a robust, multi-chain platform for creating, trading, and managing meme tokens, offering unparalleled flexibility and functionality in the Web3 ecosystem.

## License

MIT License
