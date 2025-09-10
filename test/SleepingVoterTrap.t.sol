// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {SleepingVoterTrap} from "../src/SleepingVoterTrap.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";

/// @title MockERC20
/// @notice A mock ERC20 token for testing purposes.
contract MockERC20 is IERC20 {
    mapping(address => uint256) public balances;
    string public name;
    string public symbol;
    uint8 public decimals;

    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }

    function balanceOf(address account) external view returns (uint256) {
        return balances[account];
    }

    function transfer(address, uint256) external returns (bool) {
        return true;
    }

    function allowance(address, address) external view returns (uint256) {
        return 0;
    }

    function approve(address, uint256) external returns (bool) {
        return true;
    }

    function transferFrom(address, address, uint256) external returns (bool) {
        return true;
    }

    function mint(address to, uint256 amount) public {
        balances[to] += amount;
    }
}

/// @title SleepingVoterTrapTest
/// @notice Test suite for the SleepingVoterTrap contract.
contract SleepingVoterTrapTest is Test {
    SleepingVoterTrap public trap;
    MockERC20 public mockToken;
    address public trackedAddress;
    address public operator;
    address public anotherAddress;

    function setUp() public {
        trap = new SleepingVoterTrap();
        mockToken = new MockERC20("Mock UNI", "mUNI", 18);
        trackedAddress = trap.trackedAddress();
        operator = address(this);
        anotherAddress = address(0x2);

        // Deploy the mock token's code at the hardcoded token address
        vm.etch(address(trap.token()), address(mockToken).code);

        // Mint some tokens to the tracked address
        MockERC20(address(trap.token())).mint(trackedAddress, 10000 * 1e18);

        // Whitelist the operator
        trap.addWhitelisted(operator);
    }

    /// @notice Tests that the `collect` function returns the correct data.
    function testCollect() public {
        (address collectedAddress, uint256 balance) = abi.decode(trap.collect(), (address, uint256));
        assertEq(collectedAddress, trackedAddress);
        assertEq(balance, 10000 * 1e18);
    }

    /// @notice Tests that `shouldRespond` returns false when the balance change is below the threshold.
    function testShouldRespond_BelowThreshold() public {
        uint256 initialBalance = 10000 * 1e18;
        uint256 newBalance = initialBalance + (trap.BALANCE_THRESHOLD() / 2);

        bytes memory data0 = abi.encode(trackedAddress, initialBalance);
        bytes memory data1 = abi.encode(trackedAddress, newBalance);
        bytes[] memory data = new bytes[](2);
        data[0] = data0;
        data[1] = data1;

        (bool triggered, ) = trap.shouldRespond(data);
        assertFalse(triggered);
    }

    /// @notice Tests that `shouldRespond` returns true when the balance change is above the threshold.
    function testShouldRespond_AboveThreshold() public {
        uint256 initialBalance = 10000 * 1e18;
        uint256 newBalance = initialBalance + trap.BALANCE_THRESHOLD() + 1;

        bytes memory data0 = abi.encode(trackedAddress, initialBalance);
        bytes memory data1 = abi.encode(trackedAddress, newBalance);
        bytes[] memory data = new bytes[](2);
        data[0] = data0;
        data[1] = data1;

        (bool triggered, bytes memory responseData) = trap.shouldRespond(data);
        assertTrue(triggered);

        (address respTrackedAddress, uint256 respBalance0, uint256 respBalance1) =
            abi.decode(responseData, (address, uint256, uint256));

        assertEq(respTrackedAddress, trackedAddress);
        assertEq(respBalance0, initialBalance);
        assertEq(respBalance1, newBalance);
    }
    
    /// @notice Tests that `shouldRespond` returns true when the balance decreases and is above the threshold.
    function testShouldRespond_AboveThreshold_Decrement() public {
        uint256 initialBalance = 10000 * 1e18;
        uint256 newBalance = initialBalance - (trap.BALANCE_THRESHOLD() + 1);

        bytes memory data0 = abi.encode(trackedAddress, initialBalance);
        bytes memory data1 = abi.encode(trackedAddress, newBalance);
        bytes[] memory data = new bytes[](2);
        data[0] = data0;
        data[1] = data1;

        (bool triggered, bytes memory responseData) = trap.shouldRespond(data);
        assertTrue(triggered);

        (address respTrackedAddress, uint256 respBalance0, uint256 respBalance1) =
            abi.decode(responseData, (address, uint256, uint256));

        assertEq(respTrackedAddress, trackedAddress);
        assertEq(respBalance0, initialBalance);
        assertEq(respBalance1, newBalance);
    }

    /// @notice Tests that `shouldRespond` returns false when there is not enough data.
    function testShouldRespond_NotEnoughData() public {
        bytes[] memory data = new bytes[](1);
        data[0] = abi.encode(trackedAddress, 10000 * 1e18);

        (bool triggered, ) = trap.shouldRespond(data);
        assertFalse(triggered);
    }

    /// @notice Tests that a non-whitelisted address cannot call `collect`.
    function testCollect_NotWhitelisted() public {
        vm.prank(anotherAddress);
        vm.expectRevert("Not whitelisted");
        trap.collect();
    }

    /// @notice Tests that the deployer can add a new whitelisted address.
    function testWhitelist_Add() public {
        trap.addWhitelisted(anotherAddress);
        assertTrue(trap.whitelist(anotherAddress));
    }

    /// @notice Tests that a non-deployer cannot add a new whitelisted address.
    function testWhitelist_Add_NotDeployer() public {
        vm.prank(anotherAddress);
        vm.expectRevert("Only deployer can add");
        trap.addWhitelisted(anotherAddress);
    }

    /// @notice Tests that the deployer can remove a whitelisted address.
    function testWhitelist_Remove() public {
        trap.addWhitelisted(anotherAddress);
        assertTrue(trap.whitelist(anotherAddress));
        trap.removeWhitelisted(anotherAddress);
        assertFalse(trap.whitelist(anotherAddress));
    }

    /// @notice Tests that a non-deployer cannot remove a whitelisted address.
    function testWhitelist_Remove_NotDeployer() public {
        trap.addWhitelisted(anotherAddress);
        vm.prank(anotherAddress);
        vm.expectRevert("Only deployer can remove");
        trap.removeWhitelisted(anotherAddress);
    }
}