// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IFlashLoanAggregator} from "src/interfaces/IFlashLoanAggregator.sol";

/// @title FlashLoanAggregator
/// @dev A unified interface for executing flash loans across multiple DeFi protocols
///
/// Supported protocols:
/// - ERC-3156 (protocol 0x00)
/// - AAVE V3 simple flash loan (protocol 0x01)
/// - AAVE V2 & V3 full flash loan (protocol 0x02)
/// - Balancer V2 (protocol 0x03)
/// - Balancer V3 (protocol 0x04)
/// - Morpho (protocol 0x05)
/// - Uniswap V3 (protocol 0x06)
///
/// The contract is designed to be used via delegatecall to maintain the caller's context
/// while providing a unified interface for flash loan execution across different protocols.
contract FlashLoanAggregator is IFlashLoanAggregator {
	/// @notice ERC-3156 callback success return value: keccak256("ERC3156FlashBorrower.onFlashLoan")
	uint256 private constant CALLBACK_SUCCESS = 0x439148f0bbc682ca079e46d6e2c2f0c1e3b820f1a291b069d8882abf8cf18dd9;

	/// @notice Storage slot for flash loan provider address using EIP-7201 namespaced storage
	/// @dev keccak256(abi.encode(uint256(keccak256("flash.aggregator.provider")) - 1)) & ~bytes32(uint256(0xff))
	uint256 private constant PROVIDER_SLOT = 0x9f737c8f60f336cc44d5777156552d790e2f4a34e097d21fe7dcbe365c879100;

	/// @notice Storage slot for flash loan token address using EIP-7201 namespaced storage
	/// @dev keccak256(abi.encode(uint256(keccak256("flash.aggregator.token")) - 1)) & ~bytes32(uint256(0xff))
	uint256 private constant TOKEN_SLOT = 0xd0a1971e04df53460d3c2cb63568a5d62245b50323e912caa60033daa2801b00;

	/// @notice Storage slot for flash loan amount using EIP-7201 namespaced storage
	/// @dev keccak256(abi.encode(uint256(keccak256("flash.aggregator.amount")) - 1)) & ~bytes32(uint256(0xff))
	uint256 private constant AMOUNT_SLOT = 0x888b2e90ceb60e07214b12678db5e6a4b614cb1df2ded6cc9980e71a18363c00;

	/// @notice Contract's own address stored as immutable for delegatecall detection
	uint256 private immutable SELF = uint256(uint160(address(this)));

	/// @notice Ensures function can only be called via delegatecall
	/// @dev This prevents direct calls to the contract and ensures proper context preservation
	modifier onlyDelegate() {
		_checkDelegated();
		_;
	}

	/// @inheritdoc IFlashLoanAggregator
	function initiate(
		uint256 protocol,
		address provider,
		address token,
		uint256 amount,
		bytes calldata data
	) external payable onlyDelegate {
		assembly ("memory-safe") {
			// Validate provider address is not zero
			if iszero(shl(0x60, provider)) {
				mstore(0x00, 0x7626db82) // InvalidProvider()
				revert(0x1c, 0x04)
			}

			// Validate token address is not zero
			if iszero(shl(0x60, token)) {
				mstore(0x00, 0xc891add2) // InvalidAsset()
				revert(0x1c, 0x04)
			}

			// Validate amount is greater than zero
			if iszero(amount) {
				mstore(0x00, 0x5945ea56) // InsufficientAmount()
				revert(0x1c, 0x04)
			}

			// Validate callback data is provided
			if iszero(data.length) {
				mstore(0x00, 0xdfe93090) // InvalidDataLength()
				revert(0x1c, 0x04)
			}

			let ptr := mload(0x40)
			let length  // total call data length

			switch protocol
			// ERC-3156 Standard Flash Loan
			case 0x00 {
				mstore(ptr, 0x5cffe9de) // flashLoan(address,address,uint256,bytes)
				mstore(add(ptr, 0x20), address()) // receiver
				mstore(add(ptr, 0x40), token) // token address
				mstore(add(ptr, 0x60), amount) // amount to borrow
				mstore(add(ptr, 0x80), 0x80) // offset to data
				mstore(add(ptr, 0xa0), data.length) // data length
				calldatacopy(add(ptr, 0xc0), data.offset, data.length) // copy data
				length := add(0xc4, data.length)
			}
			// AAVE V3 FlashLoan Simple
			case 0x01 {
				mstore(ptr, 0x42b0b77c) // flashLoanSimple(address,address,uint256,bytes,uint16)
				mstore(add(ptr, 0x20), address()) // receiver
				mstore(add(ptr, 0x40), token) // token address
				mstore(add(ptr, 0x60), amount) // amount to borrow
				mstore(add(ptr, 0x80), 0xa0) // offset to params
				mstore(add(ptr, 0xa0), 0x00) // referralCode = 0
				mstore(add(ptr, 0xc0), data.length) // params length
				calldatacopy(add(ptr, 0xe0), data.offset, data.length) // copy params
				length := add(0xe4, data.length)
			}
			// AAVE V2 & V3
			case 0x02 {
				mstore(ptr, 0xab9c4b5d) // flashLoan(address,address[],uint256[],uint256[],address,bytes,uint16)
				mstore(ptr, 0xab9c4b5d) // Function selector
				mstore(add(ptr, 0x20), address()) // receiver
				mstore(add(ptr, 0x40), 0xe0) // offset to assets array
				mstore(add(ptr, 0x60), 0x120) // offset to amounts array
				mstore(add(ptr, 0x80), 0x160) // offset to interestRateModes array
				mstore(add(ptr, 0xa0), address()) // onBehalfOf
				mstore(add(ptr, 0xc0), 0x1a0) // offset to params
				mstore(add(ptr, 0xe0), 0x00) // referralCode = 0
				// assets array (length = 1)
				mstore(add(ptr, 0x100), 0x01) // array length
				mstore(add(ptr, 0x120), token) // assets[0]
				// amounts array (length = 1)
				mstore(add(ptr, 0x140), 0x01) // array length
				mstore(add(ptr, 0x160), amount) // amounts[0]
				// interest rate modes array (length = 1, all stable rate = 0)
				mstore(add(ptr, 0x180), 0x01) // array length
				mstore(add(ptr, 0x1a0), 0x00) // interestRateModes[0] = 0 (stable)
				mstore(add(ptr, 0x1c0), data.length) // params length
				calldatacopy(add(ptr, 0x1e0), data.offset, data.length) // copy params
				length := add(0x1e4, data.length)
			}
			// Balancer V2
			case 0x03 {
				mstore(ptr, 0x5c38449e) // flashLoan(address,address[],uint256[],bytes)
				mstore(add(ptr, 0x20), address()) // recipient
				mstore(add(ptr, 0x40), 0x80) // offset to tokens array
				mstore(add(ptr, 0x60), 0xc0) // offset to amounts array
				mstore(add(ptr, 0x80), 0x100) // offset to userData
				// tokens array (length = 1)
				mstore(add(ptr, 0xa0), 0x01) // array length
				mstore(add(ptr, 0xc0), token) // tokens[0]
				// amounts array (length = 1)
				mstore(add(ptr, 0xe0), 0x01) // array length
				mstore(add(ptr, 0x100), amount) // amounts[0]
				// user data
				mstore(add(ptr, 0x120), data.length) // userData length
				calldatacopy(add(ptr, 0x140), data.offset, data.length) // copy userData
				length := add(0x144, data.length)
			}
			// Balancer V3
			case 0x04 {
				let offset := add(ptr, 0x44)
				mstore(offset, 0x958fa280) // receiveFlashLoan(address,uint256,bytes)
				mstore(add(offset, 0x20), token) // token address
				mstore(add(offset, 0x40), amount) // amount to borrow
				mstore(add(offset, 0x60), 0x60) // offset to data
				mstore(add(offset, 0x80), data.length) // data length
				calldatacopy(add(offset, 0xa0), data.offset, data.length) // copy data
				mstore(ptr, 0x48c89491) // unlock(bytes)
				mstore(add(ptr, 0x20), 0x20) // offset to data
				mstore(add(ptr, 0x40), add(0x84, data.length)) // data length
				length := add(0xc8, data.length)
			}
			// Morpho
			case 0x05 {
				// Store token in transient storage for callback
				tstore(TOKEN_SLOT, token)

				mstore(ptr, 0xe0232b42) // flashLoan(address,uint256,bytes)
				mstore(add(ptr, 0x20), token) // token address
				mstore(add(ptr, 0x40), amount) // amount to borrow
				mstore(add(ptr, 0x60), 0x60) // offset to data
				mstore(add(ptr, 0x80), data.length) // data length
				calldatacopy(add(ptr, 0xa0), data.offset, data.length) // copy data
				length := add(0xa4, data.length)
			}
			// Uniswap V3
			case 0x06 {
				// First, get the pool's token0 and token1 to validate the requested token
				mstore(ptr, 0x0dfe1681d21220a7) // token0() + token1() selectors

				// Call token0()
				if iszero(staticcall(gas(), provider, add(ptr, 0x18), 0x04, 0x00, 0x20)) {
					revert(add(ptr, 0x18), 0x04)
				}

				// Call token1()
				if iszero(staticcall(gas(), provider, add(ptr, 0x1c), 0x04, 0x20, 0x20)) {
					revert(add(ptr, 0x1c), 0x04)
				}

				let token0 := mload(0x00)
				let token1 := mload(0x20)

				// Validate that requested token is either token0 or token1
				if and(iszero(eq(token, token0)), iszero(eq(token, token1))) {
					mstore(0x00, 0xc891add2) // InvalidAsset()
					revert(0x1c, 0x04)
				}

				// Store token and amount in transient storage for callback
				tstore(TOKEN_SLOT, token)
				tstore(AMOUNT_SLOT, amount)

				mstore(ptr, 0x490e6cbc) // flash(address,uint256,uint256,bytes)
				mstore(add(ptr, 0x20), address()) // recipient
				// Set amount0 or amount1 based on which token is requested
				mstore(add(ptr, 0x40), mul(amount, eq(token, token0))) // amount0
				mstore(add(ptr, 0x60), mul(amount, eq(token, token1))) // amount1
				mstore(add(ptr, 0x80), 0x80) // offset to data
				mstore(add(ptr, 0xa0), data.length) // data length
				calldatacopy(add(ptr, 0xc0), data.offset, data.length) // copy data
				length := add(0xc4, data.length)
			}
			default {
				mstore(0x00, 0xd8d9e573) // UnsupportedProtocol(uint256)
				mstore(0x20, protocol)
				revert(0x1c, 0x24)
			}

			// Store provider address for callback validation
			tstore(PROVIDER_SLOT, provider)

			// Execute the flash loan call to the provider
			if iszero(call(gas(), provider, 0x00, add(ptr, 0x1c), length, codesize(), 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}
	}

	/// @notice Internal function to check if contract is being called via delegatecall
	/// @dev Reverts if called directly
	function _checkDelegated() private view {
		uint256 self = SELF;
		assembly ("memory-safe") {
			if eq(self, address()) {
				mstore(0x00, 0x9ccd6d76) // NotDelegated()
				revert(0x1c, 0x04)
			}
		}
	}

	/// @notice Fallback function that handles all flash loan callbacks from different protocols
	/// @dev Uses function selector to route to appropriate callback handler
	/// All handlers follow the same pattern:
	/// 1. Validate the callback is from authorized provider
	/// 2. Extract token and amount information
	/// 3. Execute user's callback logic via delegatecall
	/// 4. Verify sufficient balance for repayment
	/// 5. Approve/transfer tokens back to provider
	/// 6. Return appropriate success value (if required)
	fallback() external payable onlyDelegate {
		assembly ("memory-safe") {
			function execute(ptr, length) {
				if iszero(delegatecall(gas(), address(), ptr, length, codesize(), 0x00)) {
					returndatacopy(ptr, 0x00, returndatasize())
					revert(ptr, returndatasize())
				}
			}

			function approve(token, amount) {
				mstore(0x00, 0x095ea7b3000000000000000000000000) // approve(address,address,uint256)
				mstore(0x14, caller())
				mstore(0x34, amount)

				if iszero(and(eq(mload(0x00), 0x01), call(gas(), token, 0x00, 0x10, 0x44, 0x00, 0x20))) {
					mstore(0x34, 0x00)
					pop(call(gas(), token, 0x00, 0x10, 0x44, codesize(), 0x00))
					mstore(0x34, amount)

					if iszero(
						and(
							or(and(eq(mload(0x00), 0x01), gt(returndatasize(), 0x1f)), iszero(returndatasize())),
							call(gas(), token, 0x00, 0x10, 0x44, 0x00, 0x20)
						)
					) {
						mstore(0x00, 0x282a9838) // RepaymentFailed()
						revert(0x1c, 0x04)
					}
				}

				mstore(0x34, 0x00)
			}

			function transfer(token, amount) {
				mstore(0x00, 0xa9059cbb000000000000000000000000) // transfer(address,uint256)
				mstore(0x14, caller())
				mstore(0x34, amount)

				if iszero(
					and(
						or(and(eq(mload(0x00), 0x01), gt(returndatasize(), 0x1f)), iszero(returndatasize())),
						call(gas(), token, 0x00, 0x10, 0x44, 0x00, 0x20)
					)
				) {
					mstore(0x00, 0x282a9838) // RepaymentFailed()
					revert(0x1c, 0x04)
				}

				mstore(0x34, 0x00)
			}

			function checkBalance(token, amount) {
				mstore(0x00, 0x70a08231000000000000000000000000) // balanceOf(address)
				mstore(0x14, address())

				if lt(
					mul(mload(0x20), and(gt(returndatasize(), 0x1f), staticcall(gas(), token, 0x10, 0x24, 0x20, 0x20))),
					amount
				) {
					mstore(0x00, 0xf4d678b8) // InsufficientBalance()
					revert(0x1c, 0x04)
				}
			}

			// Verify callback is from authorized provider
			if iszero(eq(tload(PROVIDER_SLOT), caller())) {
				mstore(0x00, 0xf5c6c81a) // UnauthorizedCallback()
				revert(0x1c, 0x04)
			}

			// Setup variables for callback handling
			let ptr := mload(0x40)
			let selector := shr(0xe0, calldataload(0x00)) // Extract function selector
			let token
			let amount

			switch selector
			// Aave V3: executeOperation(address,uint256,uint256,address,bytes)
			case 0x1b11d0ff {
				// Validate initiator is this contract
				if iszero(eq(calldataload(0x64), address())) {
					mstore(0x00, 0xbfda1f28) // InvalidInitiator()
					revert(0x1c, 0x04)
				}

				// Extract parameters
				token := calldataload(0x04)
				amount := add(calldataload(0x24), calldataload(0x44))

				// Execute user logic
				calldatacopy(ptr, 0xc4, calldataload(0xa4))
				execute(ptr, calldataload(0xa4))

				// Repay flash loan
				checkBalance(token, amount)
				approve(token, amount)

				// Return success
				mstore(0x00, 0x01)
				return(0x00, 0x20)
			}
			// ERC-3156: onFlashLoan(address,address,uint256,uint256,bytes)
			case 0x23e30c8b {
				// Validate initiator is this contract
				if iszero(eq(calldataload(0x04), address())) {
					mstore(0x00, 0xbfda1f28) // InvalidInitiator()
					revert(0x1c, 0x04)
				}

				// Extract parameters
				token := calldataload(0x24)
				amount := add(calldataload(0x44), calldataload(0x64))

				// Execute user logic
				calldatacopy(ptr, 0xc4, calldataload(0xa4))
				execute(ptr, calldataload(0xa4))

				// Repay flash loan
				checkBalance(token, amount)
				approve(token, amount)

				// Return ERC-3156 success constant
				mstore(0x00, CALLBACK_SUCCESS)
				return(0x00, 0x20)
			}
			// Morpho: onMorphoFlashLoan(uint256,bytes)
			case 0x31f57072 {
				// Get token from transient storage (set during initiate)
				token := tload(TOKEN_SLOT)
				amount := calldataload(0x04) // totalAmount (amount + fee)

				// Execute user logic
				calldatacopy(ptr, 0x64, calldataload(0x44))
				execute(ptr, calldataload(0x44))

				// Repay flash loan
				checkBalance(token, amount)
				approve(token, amount)
			}
			// Aave V2 & V3: executeOperation(address[],uint256[],uint256[],address,bytes)
			case 0x920f5c84 {
				// Validate initiator is this contract
				if iszero(eq(calldataload(0x64), address())) {
					mstore(0x00, 0xbfda1f28) // InvalidInitiator()
					revert(0x1c, 0x04)
				}

				// Validate array length is 1 (single asset flash loan)
				let offset := add(calldataload(0x04), 0x04)
				if iszero(eq(calldataload(offset), 0x01)) {
					mstore(0x00, 0x0fe4a1df) // InvalidParametersLength()
					revert(0x1c, 0x04)
				}

				// Extract parameters
				token := calldataload(add(offset, 0x20)) // assets[0]
				amount := add(
					calldataload(add(calldataload(0x24), 0x24)), // amounts[0]
					calldataload(add(calldataload(0x44), 0x24)) // premiums[0]
				)

				// Execute user logic
				offset := add(calldataload(0x84), 0x04)
				calldatacopy(ptr, add(offset, 0x20), calldataload(offset))
				execute(ptr, calldataload(offset))

				// Repay flash loan
				checkBalance(token, amount)
				approve(token, amount)

				// Return success
				mstore(0x00, 0x01)
				return(0x00, 0x20)
			}
			// Balancer V3: receiveFlashLoan(address,uint256,bytes)
			case 0x958fa280 {
				// Extract parameters
				token := calldataload(0x04)
				amount := calldataload(0x24)

				let length := calldataload(0x64)
				calldatacopy(ptr, 0x84, length)

				{
					// Receive flash loan tokens from the vault
					mstore(0x0c, 0xae639329000000000000000000000000) // sendTo(address,address,uint256)
					mstore(0x2c, shl(0x60, token))
					mstore(0x40, address())
					mstore(0x60, amount)

					if iszero(call(gas(), caller(), 0x00, 0x1c, 0x64, codesize(), 0x00)) {
						returndatacopy(ptr, 0x00, returndatasize())
						revert(ptr, returndatasize())
					}

					mstore(0x60, 0x00)
					mstore(0x40, mload(0x40))
				}

				// Execute user logic
				execute(ptr, length)

				// Repay flash loan
				checkBalance(token, amount)
				transfer(token, amount)

				{
					// Settle the repayment with the vault
					mstore(0x00, 0x15afd409000000000000000000000000) // settle(address,uint256)
					mstore(0x14, token)
					mstore(0x34, amount)

					if iszero(call(gas(), caller(), 0x00, 0x10, 0x44, codesize(), 0x00)) {
						returndatacopy(ptr, 0x00, returndatasize())
						revert(ptr, returndatasize())
					}

					mstore(0x34, 0x00)
				}
			}
			// Uniswap V3: uniswapV3FlashCallback(uint256,uint256,bytes)
			case 0xe9cbafb0 {
				// Get token and original amount from transient storage
				token := tload(TOKEN_SLOT)
				amount := add(tload(AMOUNT_SLOT), add(calldataload(0x04), calldataload(0x24))) // original + fee0 + fee1

				// Execute user logic
				calldatacopy(ptr, 0x84, calldataload(0x64))
				execute(ptr, calldataload(0x64))

				// Repay flash loan
				checkBalance(token, amount)
				transfer(token, amount)
			}
			// Balancer V2: receiveFlashLoan(address[],uint256[],uint256[],bytes)
			case 0xf04f2707 {
				// Validate array length is 1 (single asset flash loan)
				let offset := add(calldataload(0x04), 0x04)
				if iszero(eq(calldataload(offset), 0x01)) {
					mstore(0x00, 0x0fe4a1df) // InvalidParametersLength()
					revert(0x1c, 0x04)
				}

				// Extract parameters
				token := calldataload(add(offset, 0x20)) // assets[0]
				amount := add(
					calldataload(add(calldataload(0x24), 0x24)), // amounts[0]
					calldataload(add(calldataload(0x44), 0x24)) // fees[0]
				)

				// Execute user logic
				offset := add(calldataload(0x64), 0x04)
				calldatacopy(ptr, add(offset, 0x20), calldataload(offset))
				execute(ptr, calldataload(offset))

				// Repay flash loan
				checkBalance(token, amount)
				transfer(token, amount)
			}
			default {
				mstore(0x00, 0xa519a14f) // UnsupportedSelector(bytes4)
				mstore(0x20, selector)
				revert(0x1c, 0x24)
			}
		}
	}

	/// @notice Allows contract to receive native ETH
	/// @dev Required for protocols that might send ETH during flash loan operations
	receive() external payable {}
}
