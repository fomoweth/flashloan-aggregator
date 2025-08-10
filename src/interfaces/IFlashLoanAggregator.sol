// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title IFlashLoanAggregator
/// @notice Interface for FlashLoanAggregator
interface IFlashLoanAggregator {
	/// @notice Thrown when flash loan amount is zero
	error InsufficientAmount();

	/// @notice Thrown when contract doesn't have enough balance to repay flash loan
	error InsufficientBalance();

	/// @notice Thrown when token address is invalid (zero address)
	error InvalidAsset();

	/// @notice Thrown when callback data length is zero
	error InvalidDataLength();

	/// @notice Thrown when flash loan initiator is not this contract
	error InvalidInitiator();

	/// @notice Thrown when array parameters have incorrect length (should be 1)
	error InvalidParametersLength();

	/// @notice Thrown when provider address is invalid (zero address)
	error InvalidProvider();

	/// @notice Thrown when contract is called directly instead of via delegatecall
	error NotDelegated();

	/// @notice Thrown when token approval or transfer fails during repayment
	error RepaymentFailed();

	/// @notice Thrown when callback is received from unauthorized provider
	error UnauthorizedCallback();

	/// @notice Thrown when unsupported protocol identifier is used
	error UnsupportedProtocol(uint256 protocol);

	/// @notice Thrown when unsupported function selector is called
	error UnsupportedSelector(bytes4 selector);

	/// @notice Initiates a flash loan from the specified protocol and provider
	/// @param protocol Protocol identifier (0x00-0x06)
	/// @param provider Address of the flash loan provider contract
	/// @param token Address of the token to borrow
	/// @param amount Amount of tokens to borrow
	/// @param data Callback data to pass to the user's logic
	/// @dev Protocol mapping:
	/// 0x00: ERC-3156 standard
	/// 0x01: AAVE V3 simple flash loan
	/// 0x02: AAVE V2 & V3 full flash loan
	/// 0x03: Balancer V2
	/// 0x04: Balancer V3
	/// 0x05: Morpho
	/// 0x06: Uniswap V3
	function initiate(
		uint256 protocol,
		address provider,
		address token,
		uint256 amount,
		bytes calldata data
	) external payable;
}
