# Probability Engine & Reputation System

A comprehensive smart contract system built for the Stacks blockchain using Clarity, providing verifiable randomness generation and on-chain reputation management.

## Overview

This smart contract combines two powerful systems:

1. **Probability Engine**: Generates verifiable random numbers using multiple entropy sources
2. **Reputation System**: Tracks and manages user reputation scores on-chain

## Features

### 🎲 Probability Engine

- **Multiple Entropy Sources**: Combine various entropy sources for enhanced randomness
- **Verifiable Randomness**: Complete audit trail for all random number generation
- **Source Management**: Add, configure, and manage entropy sources with different weights
- **Range Generation**: Generate random numbers within specified ranges
- **History Tracking**: Store complete generation history for verification

### ⭐ Reputation System

- **Reputation Scoring**: Track user reputation from 0-1000 points
- **Level Classification**: Automatic categorization (New, Poor, Average, Good, Excellent)
- **Interaction Tracking**: Monitor positive vs total interactions
- **Validator Network**: Trusted validators can update reputation scores
- **Minimum Reputation Gates**: Check if users meet reputation thresholds

## Contract Architecture

### Data Structures

```clarity
;; Entropy Sources
entropy-sources: {
  source-type: string,
  weight: uint,
  last-used: uint,
  is-active: bool
}

;; User Reputation
user-reputation: {
  score: uint,
  total-interactions: uint,
  positive-interactions: uint,
  last-updated: uint,
  reputation-level: string
}

;; Randomness History
randomness-history: {
  requester: principal,
  block-height: uint,
  entropy-hash: buff,
  result: uint,
  timestamp: uint,
  entropy-sources-used: list
}
```

## Core Functions

### Entropy Management

#### `add-entropy-source`
```clarity
(define-public (add-entropy-source (source-type (string-ascii 32)) (weight uint)))
```
- **Access**: Contract owner only
- **Purpose**: Add new entropy source to the system
- **Parameters**: 
  - `source-type`: Description of the entropy source
  - `weight`: Relative weight of the source
- **Returns**: Source ID on success

#### `generate-random`
```clarity
(define-public (generate-random (min-val uint) (max-val uint) (entropy-source-ids (list 10 uint))))
```
- **Access**: Public
- **Purpose**: Generate verifiable random number
- **Parameters**:
  - `min-val`: Minimum value (inclusive)
  - `max-val`: Maximum value (exclusive)
  - `entropy-source-ids`: List of entropy sources to use
- **Requirements**: Minimum 3 active entropy sources
- **Returns**: Random number within specified range

### Reputation Management

#### `initialize-reputation`
```clarity
(define-public (initialize-reputation))
```
- **Access**: Public
- **Purpose**: Initialize reputation profile for caller
- **Starting Score**: 100 points
- **Returns**: Success boolean

#### `update-reputation`
```clarity
(define-public (update-reputation (user principal) (interaction-positive bool)))
```
- **Access**: Public
- **Purpose**: Update user reputation based on interaction
- **Parameters**:
  - `user`: Principal to update
  - `interaction-positive`: Whether interaction was positive
- **Returns**: New reputation score

#### `add-reputation-validator`
```clarity
(define-public (add-reputation-validator))
```
- **Access**: Public
- **Purpose**: Register as a reputation validator
- **Returns**: Success boolean

#### `validate-reputation-update`
```clarity
(define-public (validate-reputation-update (user principal) (interaction-positive bool) (confidence-score uint)))
```
- **Access**: Registered validators only
- **Purpose**: Validator-driven reputation updates
- **Parameters**:
  - `user`: User to update
  - `interaction-positive`: Type of interaction
  - `confidence-score`: Validator confidence (0-1000)

### Query Functions

#### `get-user-reputation`
```clarity
(define-read-only (get-user-reputation (user principal)))
```
Returns complete reputation data for a user.

#### `verify-randomness`
```clarity
(define-read-only (verify-randomness (request-id uint)))
```
Verify the generation of a specific random number.

#### `has-minimum-reputation`
```clarity
(define-read-only (has-minimum-reputation (user principal) (min-score uint)))
```
Check if user meets minimum reputation threshold.

#### `get-contract-stats`
```clarity
(define-read-only (get-contract-stats))
```
Get overall contract statistics.

## Reputation Levels

| Score Range | Level | Description |
|-------------|-------|-------------|
| 800-1000 | Excellent | Highest reputation tier |
| 600-799 | Good | High reputation tier |
| 400-599 | Average | Medium reputation tier |
| 200-399 | Poor | Low reputation tier |
| 0-199 | New | Starting reputation tier |

## Usage Examples

### Basic Random Number Generation

```clarity
;; Generate random number between 1 and 100 using entropy sources 1, 2, 3
(contract-call? .probability-engine generate-random u1 u101 (list u1 u2 u3))
```

### Initialize and Update Reputation

```clarity
;; Initialize reputation
(contract-call? .probability-engine initialize-reputation)

;; Update reputation after positive interaction
(contract-call? .probability-engine update-reputation 'SP1ABC...DEF true)
```

### Check User Reputation

```clarity
;; Get user reputation data
(contract-call? .probability-engine get-user-reputation 'SP1ABC...DEF)

;; Check if user has minimum reputation of 500
(contract-call? .probability-engine has-minimum-reputation 'SP1ABC...DEF u500)
```

## Security Features

- **Access Control**: Owner-only functions for critical operations
- **Input Validation**: Comprehensive parameter validation
- **Entropy Requirements**: Minimum entropy sources for randomness
- **Reputation Bounds**: Score capping at maximum values
- **Audit Trail**: Complete history of all operations

## Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| 100 | ERR-OWNER-ONLY | Function restricted to contract owner |
| 101 | ERR-INVALID-ENTROPY | Invalid entropy source parameters |
| 102 | ERR-INSUFFICIENT-ENTROPY | Not enough active entropy sources |
| 103 | ERR-INVALID-RANGE | Invalid min/max range specified |
| 104 | ERR-USER-NOT-FOUND | User not found in system |
| 105 | ERR-INVALID-SCORE | Invalid score parameter |

## Deployment

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Stacks wallet for deployment
- STX tokens for transaction fees

### Steps

1. **Clone and Setup**
```bash
git clone <repository-url>
cd probability-engine
clarinet check
```

2. **Test Locally**
```bash
clarinet console
```

3. **Deploy to Testnet**
```bash
clarinet deploy --testnet
```

4. **Deploy to Mainnet**
```bash
clarinet deploy --mainnet
```

## Testing

Run the test suite:
```bash
npm install
npm test
```

Test coverage includes:
- Entropy source management
- Random number generation
- Reputation initialization and updates
- Validator operations
- Error handling
- Edge cases

## Integration Guide

### For DApps Requiring Randomness

```javascript
// Example integration for web apps
const randomResult = await contractCall({
  contractName: 'probability-engine',
  functionName: 'generate-random',
  functionArgs: [
    uintCV(1),     // min value
    uintCV(101),   // max value
    listCV([uintCV(1), uintCV(2), uintCV(3)]) // entropy sources
  ]
});
```

### For Reputation-Gated Features

```javascript
// Check user reputation before allowing action
const userRep = await contractCall({
  contractName: 'probability-engine',
  functionName: 'has-minimum-reputation',
  functionArgs: [
    standardPrincipalCV('SP1ABC...DEF'),
    uintCV(500)
  ]
});
```

## Best Practices

### Entropy Management
- Use diverse entropy sources for better randomness
- Regularly monitor entropy source status
- Implement fallback mechanisms for inactive sources

### Reputation Management
- Initialize reputation for new users
- Update reputation consistently after interactions
- Use reputation thresholds for access control
- Implement reputation recovery mechanisms

### Security Considerations
- Validate all inputs before contract calls
- Handle error cases gracefully
- Monitor contract usage patterns
- Implement rate limiting if needed

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

For questions, issues, or contributions:
- Create an issue on GitHub
- Join our Discord community
- Check the documentation wiki