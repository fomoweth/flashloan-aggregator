// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {FlashLoanAggregator} from "src/FlashLoanAggregator.sol";
import {MockExecutor} from "test/mocks/MockExecutor.sol";
import {MockFlashLender} from "test/mocks/MockFlashLender.sol";

contract FlashLoanAggregatorTest is Test {
	using SafeERC20 for IERC20;

	address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
	address internal constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

	address internal constant AAVE_V2 = 0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9;
	address internal constant AAVE_V3 = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
	address internal constant SPARK = 0xC13e21B648A5Ee794902342038FF3aDAB66BE987; // Aave V3 Fork
	address internal constant BALANCER_V2 = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
	address internal constant BALANCER_V3 = 0xbA1333333333a1BA1108E8412f11850A5C319bA9;
	address internal constant MAKER = 0x60744434d6339a6B27d73d9Eda62b6F66a0a04FA;
	address internal constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
	address internal constant UNI_V3_USDC_WETH = 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640;
	address internal constant SUSHI_V3_SUSHI_WETH = 0x87C7056BBE6084f03304196Be51c6B90B6d85Aa2;

	uint256 internal constant ERC3156_FL_TYPE = 0;
	uint256 internal constant AAVE_FL_SIMPLE_TYPE = 1;
	uint256 internal constant AAVE_FL_TYPE = 2;
	uint256 internal constant BALANCER_V2_FL_TYPE = 3;
	uint256 internal constant BALANCER_V3_FL_TYPE = 4;
	uint256 internal constant MORPHO_FL_TYPE = 5;
	uint256 internal constant UNISWAP_V3_FL_TYPE = 6;

	FlashLoanAggregator internal aggregator;
	MockExecutor internal executor;
	MockFlashLender internal lender;

	function setUp() public virtual {
		vm.createSelectFork("ethereum", 23109679);

		aggregator = new FlashLoanAggregator();
		executor = new MockExecutor(address(aggregator));
		lender = new MockFlashLender();

		deal(WETH, address(lender), 10000 ether);
		deal(WETH, address(this), 10 ether);
		deal(DAI, address(this), 5000 ether);

		IERC20(WETH).forceApprove(address(executor), type(uint256).max);
		IERC20(DAI).forceApprove(address(executor), type(uint256).max);
	}

	function test_initiate_flashLoan_erc3156() public {
		bytes memory call = abi.encodeCall(IERC20.transferFrom, (address(this), address(executor), 10 ether));
		bytes memory data = abi.encodeCall(MockExecutor.callback, (abi.encode(WETH, call)));

		executor.execute(ERC3156_FL_TYPE, address(lender), WETH, 20 ether, data);
		assertEq(IERC20(WETH).balanceOf(address(executor)), 10 ether);
	}

	function test_initiate_flashLoan_maker() public {
		bytes memory call = abi.encodeCall(IERC20.transferFrom, (address(this), address(executor), 5000 ether));
		bytes memory data = abi.encodeCall(MockExecutor.callback, (abi.encode(DAI, call)));

		executor.execute(ERC3156_FL_TYPE, MAKER, DAI, 50000 ether, data);
		assertEq(IERC20(DAI).balanceOf(address(executor)), 5000 ether);
	}

	function test_initiate_flashLoanSimple() public {
		bytes memory call = abi.encodeCall(IERC20.transferFrom, (address(this), address(executor), 10 ether));
		bytes memory data = abi.encodeCall(MockExecutor.callback, (abi.encode(WETH, call)));

		executor.execute(AAVE_FL_SIMPLE_TYPE, AAVE_V3, WETH, 20 ether, data);
		assertGt(IERC20(WETH).balanceOf(address(executor)), 0);
	}

	function test_initiate_flashLoanSimple_spark() public {
		bytes memory call = abi.encodeCall(IERC20.transferFrom, (address(this), address(executor), 10 ether));
		bytes memory data = abi.encodeCall(MockExecutor.callback, (abi.encode(WETH, call)));

		executor.execute(AAVE_FL_SIMPLE_TYPE, SPARK, WETH, 20 ether, data);
		assertGt(IERC20(WETH).balanceOf(address(executor)), 0);
	}

	function test_initiate_flashLoan_aave_v3() public {
		bytes memory call = abi.encodeCall(IERC20.transferFrom, (address(this), address(executor), 10 ether));
		bytes memory data = abi.encodeCall(MockExecutor.callback, (abi.encode(WETH, call)));

		executor.execute(AAVE_FL_TYPE, AAVE_V3, WETH, 20 ether, data);
		assertGt(IERC20(WETH).balanceOf(address(executor)), 0);
	}

	function test_initiate_flashLoan_aave_v2() public {
		bytes memory call = abi.encodeCall(IERC20.transferFrom, (address(this), address(executor), 10 ether));
		bytes memory data = abi.encodeCall(MockExecutor.callback, (abi.encode(WETH, call)));

		executor.execute(AAVE_FL_TYPE, AAVE_V2, WETH, 20 ether, data);
		assertGt(IERC20(WETH).balanceOf(address(executor)), 0);
	}

	function test_initiate_flashLoan_spark() public {
		bytes memory call = abi.encodeCall(IERC20.transferFrom, (address(this), address(executor), 10 ether));
		bytes memory data = abi.encodeCall(MockExecutor.callback, (abi.encode(WETH, call)));

		executor.execute(AAVE_FL_TYPE, SPARK, WETH, 20 ether, data);
		assertGt(IERC20(WETH).balanceOf(address(executor)), 0);
	}

	function test_initiate_flashLoan_balancer_v2() public {
		bytes memory call = abi.encodeCall(IERC20.transferFrom, (address(this), address(executor), 10 ether));
		bytes memory data = abi.encodeCall(MockExecutor.callback, (abi.encode(WETH, call)));

		executor.execute(BALANCER_V2_FL_TYPE, BALANCER_V2, WETH, 20 ether, data);
		assertEq(IERC20(WETH).balanceOf(address(executor)), 10 ether);
	}

	function test_initiate_flashLoan_balancer_v3() public {
		bytes memory call = abi.encodeCall(IERC20.transferFrom, (address(this), address(executor), 10 ether));
		bytes memory data = abi.encodeCall(MockExecutor.callback, (abi.encode(WETH, call)));

		executor.execute(BALANCER_V3_FL_TYPE, BALANCER_V3, WETH, 20 ether, data);
		assertEq(IERC20(WETH).balanceOf(address(executor)), 10 ether);
	}

	function test_initiate_flashLoan_morpho() public {
		bytes memory call = abi.encodeCall(IERC20.transferFrom, (address(this), address(executor), 10 ether));
		bytes memory data = abi.encodeCall(MockExecutor.callback, (abi.encode(WETH, call)));

		executor.execute(MORPHO_FL_TYPE, MORPHO, WETH, 20 ether, data);
		assertEq(IERC20(WETH).balanceOf(address(executor)), 10 ether);
	}

	function test_initiate_flash_uniswap() public {
		bytes memory call = abi.encodeCall(IERC20.transferFrom, (address(this), address(executor), 10 ether));
		bytes memory data = abi.encodeCall(MockExecutor.callback, (abi.encode(WETH, call)));

		executor.execute(UNISWAP_V3_FL_TYPE, UNI_V3_USDC_WETH, WETH, 20 ether, data);
		assertGt(IERC20(WETH).balanceOf(address(executor)), 0);
	}

	function test_initiate_flash_sushi() public {
		bytes memory call = abi.encodeCall(IERC20.transferFrom, (address(this), address(executor), 10 ether));
		bytes memory data = abi.encodeCall(MockExecutor.callback, (abi.encode(WETH, call)));

		executor.execute(UNISWAP_V3_FL_TYPE, SUSHI_V3_SUSHI_WETH, WETH, 20 ether, data);
		assertGt(IERC20(WETH).balanceOf(address(executor)), 0);
	}
}
