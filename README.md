# FlashLoan Aggregator

A unified interface for executing flash loans across multiple DeFi protocols. This contract provides a single, gas-optimized entry point for flash loans from various lending protocols, eliminating the need to integrate with each protocol individually.

## Supported Protocols

| Protocol        | ID     | Description                     |
| --------------- | ------ | ------------------------------- |
| ERC-3156        | `0x00` | Standard flash loan interface   |
| AAVE V3 Simple  | `0x01` | AAVE V3 single-asset flash loan |
| AAVE V2/V3 Full | `0x02` | AAVE multi-asset flash loan     |
| Balancer V2     | `0x03` | Balancer V2 vault flash loan    |
| Balancer V3     | `0x04` | Balancer V3 vault flash loan    |
| Morpho          | `0x05` | Morpho protocol flash loan      |
| Uniswap V3      | `0x06` | Uniswap V3 pool flash loan      |

## Key Features

-   **Universal Interface**: Single contract to access flash loans from 7+ protocols
-   **Gas Optimized**: Assembly-optimized implementation for minimal gas overhead
-   **Delegatecall Pattern**: Maintains caller context for seamless integration
-   **Security First**: Comprehensive validation and authorization checks
-   **Protocol Agnostic**: Abstracts away protocol-specific implementation details

## Gas Optimization

The contract uses several optimization techniques:

-   **Assembly Implementation**: Core logic written in assembly for gas efficiency
-   **Transient Storage**: Uses EIP-1153 transient storage for temporary state
-   **Minimal Proxy Pattern**: Designed for delegatecall usage
-   **Packed Storage**: EIP-7201 namespaced storage slots

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test -vvv
```

### Basic Integration

```solidity
contract MyFlashLoanStrategy {
    address immutable aggregator;

    constructor(address _aggregator) {
        aggregator = _aggregator;
    }

    // Your callback logic here
    function execute(bytes calldata data) external {
        // This gets called during the flash loan
        // Token balance is now available in this contract
        // Implement your arbitrage/liquidation/etc logic here
        // Ensure you have enough balance to repay the loan + fees
    }

    fallback() external payable {
		address handler = aggregator;
		assembly ("memory-safe") {
			calldatacopy(0x00, 0x00, calldatasize())

			let success := delegatecall(gas(), handler, 0x00, calldatasize(), codesize(), 0x00)

			returndatacopy(0x00, 0x00, returndatasize())

			switch success
			case 0x00 {
				revert(0x00, returndatasize())
			}
			default {
				return(0x00, returndatasize())
			}
		}
	}
}
```
