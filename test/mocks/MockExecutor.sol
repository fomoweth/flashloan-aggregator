// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IFlashLoanAggregator} from "src/interfaces/IFlashLoanAggregator.sol";

contract MockExecutor {
	event Executed(address sender, address token, bytes data);

	address public immutable aggregator;

	constructor(address _aggregator) {
		aggregator = _aggregator;
	}

	function execute(
		uint256 protocol,
		address provider,
		address token,
		uint256 amount,
		bytes calldata data
	) external payable {
		(bool success, ) = aggregator.delegatecall(
			abi.encodeCall(IFlashLoanAggregator.initiate, (protocol, provider, token, amount, data))
		);
		require(success);
	}

	function callback(bytes memory data) external payable {
		address token;
		(token, data) = abi.decode(data, (address, bytes));
		(bool success, ) = token.call(data);
		require(success);

		emit Executed(msg.sender, token, data);
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

	receive() external payable {}
}
