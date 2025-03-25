# STX Staking Smart Contract

A Clarity smart contract for staking STX tokens with reward generation and flexible management.

## Overview

This smart contract implements a staking mechanism using the native STX token on the Stacks blockchain. Users can stake their STX tokens and earn rewards over time based on block height. The contract includes features such as:

- Fixed reward rate based on blocks elapsed
- Customizable minimum stake requirements
- Cooldown period for unstaking
- Emergency shutdown capabilities for contract owner
- Full admin controls for parameter adjustments

## Contract Features

### For Stakers

- **Stake STX**: Deposit STX tokens to start earning rewards
- **Claim Rewards**: Collect accrued rewards at any time
- **Unstake Process**: Initiate a cooldown period before withdrawing stake
- **Cancel Unstaking**: Option to cancel an unstake request during cooldown

### For Contract Owner

- **Reward Rate Management**: Adjust the reward rate per block
- **Parameter Controls**: Modify minimum stake amount, cooldown period, and early withdrawal fees
- **Emergency Controls**: Ability to shut down the contract and force-withdraw user funds in emergencies

## Key Functions

### User Functions

| Function | Description |
| -------- | ----------- |
| `start-unstake-cooldown` | Initiates the cooldown period for unstaking |
| `cancel-unstake-cooldown` | Cancels an ongoing unstake cooldown |
| `claim-rewards` | Claims all pending rewards |

### Read-Only Functions

| Function | Description |
| -------- | ----------- |
| `get-stake-info` | Returns detailed information about a user's stake |
| `get-pending-rewards` | Calculates the pending rewards for a user |
| `is-cooldown-complete` | Checks if a user's cooldown period is complete |
| `get-cooldown-remaining` | Returns the number of blocks remaining in cooldown |
| `get-contract-info` | Returns current contract parameters and status |
| `get-user-info` | Returns comprehensive user staking information |

### Admin Functions

| Function | Description |
| -------- | ----------- |
| `set-reward-rate` | Updates the reward rate per block per STX |
| `set-minimum-stake` | Sets the minimum stake amount (in microSTX) |
| `set-early-withdrawal-fee` | Updates the early withdrawal fee percentage |
| `set-staking-cooldown` | Adjusts the cooldown period length in blocks |
| `toggle-emergency-shutdown` | Enables/disables emergency mode |
| `emergency-withdraw` | Forces withdrawal of a user's stake (emergency only) |

## Error Codes

| Code | Description |
| ---- | ----------- |
| `err-not-owner` (u100) | Only contract owner can perform this action |
| `err-insufficient-funds` (u101) | Insufficient funds for operation |
| `err-no-stake-found` (u102) | No active stake found for user |
| `err-invalid-amount` (u103) | Invalid amount specified |
| `err-minimum-stake` (u104) | Amount below minimum stake requirement |
| `err-cooldown-active` (u105) | Cooldown period still active |
| `err-early-withdrawal-fee` (u106) | Early withdrawal fee applies |
| `err-emergency-shutdown` (u107) | Emergency shutdown mode error |
| `err-cooldown-cancel` (u108) | Error canceling cooldown |
| `err-invalid-parameter` (u200) | Invalid parameter value |
| `err-unauthorized-user` (u201) | Unauthorized user access |

## Security Features

The contract includes multiple security measures:

1. **Input Validation**: All admin-configurable parameters have reasonable limits
2. **Principal Validation**: Ensures valid recipient addresses for transfers
3. **Withdrawal Safeguards**: Cooldown period prevents instant unstaking
4. **Emergency Controls**: Fast response mechanism for critical issues

## Usage Examples

### Staking STX

```clarity
;; Stake 100 STX (100,000,000 microSTX)
(contract-call? .staking-contract stake u100000000)
```

### Claiming Rewards

```clarity
;; Claim all pending rewards
(contract-call? .staking-contract claim-rewards)
```

### Starting Unstake Process

```clarity
;; Initiate cooldown for unstaking
(contract-call? .staking-contract start-unstake-cooldown)
```

### Checking Stake Status

```clarity
;; Get all stake information for a user
(contract-call? .staking-contract get-user-info tx-sender)
```

## Contract Parameters

- **Reward Rate**: 10 microSTX per block per STX staked
- **Minimum Stake**: 1 STX (1,000,000 microSTX)
- **Cooldown Period**: 144 blocks (~1 day at 10 min blocks)
- **Early Withdrawal Fee**: 10%

## Development and Deployment

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) for local development
- [Stacks CLI](https://docs.stacks.co/stacks-cli/get-started) for deployment

### Testing

Run the included test suite to verify contract functionality:

```bash
clarinet test
```

### Deployment

Deploy to testnet or mainnet using the Stacks CLI:

```bash
stacks deploy --network=[testnet/mainnet] staking.clar
```

## Security Considerations

- The contract uses proper validation for all user inputs
- Admin functions are restricted to the contract owner
- Emergency shutdown features enable quick response to issues
- All numerical operations handle microSTX to avoid floating-point issues
