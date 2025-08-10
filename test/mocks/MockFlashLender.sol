// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC3156FlashBorrower} from "@openzeppelin/interfaces/IERC3156FlashBorrower.sol";
import {IERC3156FlashLender} from "@openzeppelin/interfaces/IERC3156FlashLender.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";

contract MockFlashLender is IERC3156FlashLender {
	using SafeERC20 for IERC20;

	bytes32 public constant CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");

	function flashLoan(
		IERC3156FlashBorrower receiver,
		address token,
		uint256 amount,
		bytes calldata data
	) external returns (bool) {
		require(IERC20(token).balanceOf(address(this)) >= amount);

		IERC20(token).safeTransfer(address(receiver), amount);

		require(receiver.onFlashLoan(msg.sender, token, amount, 0, data) == CALLBACK_SUCCESS);

		IERC20(token).safeTransferFrom(address(receiver), address(this), amount);

		require(IERC20(token).balanceOf(address(this)) >= amount);

		return true;
	}

	function maxFlashLoan(address token) external view returns (uint256) {
		return IERC20(token).balanceOf(address(this));
	}

	function flashFee(address /* token */, uint256 /* amount */) external view virtual returns (uint256) {
		return 0;
	}
}
