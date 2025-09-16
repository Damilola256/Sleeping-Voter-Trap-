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
    address public anotherAddress;

    function setUp() public {
        trap = new SleepingVoterTrap();
        mockToken = new MockERC20("Mock UNI", "mUNI", 18);
        trackedAddress = trap.trackedAddress();
        anotherAddress = address(0x2);

        // Deploy the mock token's code at the hardcoded token address
        vm.etch(address(trap.token()), address(mockToken).code);

        // Mint some tokens to the tracked address
        MockERC20(address(trap.token())).mint(trackedAddress, 10000 * 1e18);
    }

    /// @notice Tests that the `collect` function returns the correct data.
    function testCollect() public {
        (address collectedAddress, uint256 balance) = abi.decode(trap.collect(), (address, uint256));
        assertEq(collectedAddress, trackedAddress);
        assertEq(balance, 10000 * 1e18);
    }

    /// @notice Tests that `collect` returns a balance of 0 if the token contract does not exist.
    function testCollect_NoTokenContract() public {
        // Overwrite the token contract with an empty address
        vm.etch(address(trap.token()), bytes(""));
        (address collectedAddress, uint256 balance) = abi.decode(trap.collect(), (address, uint256));
        assertEq(collectedAddress, trackedAddress);
        assertEq(balance, 0);
    }

    /// @notice Tests that `shouldRespond` returns false when the balance change is below all thresholds.
    function testShouldRespond_BelowThreshold() public {
        uint256 previousBalance = 10000 * 1e18;
        uint256 currentBalance = previousBalance + 1;

        bytes memory data0 = abi.encode(trackedAddress, currentBalance); // Current
        bytes memory data1 = abi.encode(trackedAddress, previousBalance); // Previous
        bytes[] memory data = new bytes[](2);
        data[0] = data0;
        data[1] = data1;

        (bool triggered, ) = trap.shouldRespond(data);
        assertFalse(triggered);
    }

    /// @notice Tests that `shouldRespond` returns true when the balance change is above the absolute threshold.
    function testShouldRespond_AboveAbsoluteThreshold() public {
        uint256 previousBalance = 10000 * 1e18;
        uint256 currentBalance = previousBalance + trap.BALANCE_THRESHOLD_ABSOLUTE() + 1;

        bytes memory data0 = abi.encode(trackedAddress, currentBalance);
        bytes memory data1 = abi.encode(trackedAddress, previousBalance);
        bytes[] memory data = new bytes[](2);
        data[0] = data0;
        data[1] = data1;

        (bool triggered, bytes memory responseData) = trap.shouldRespond(data);
        assertTrue(triggered);

        (address respTrackedAddress, uint256 respPreviousBalance, uint256 respCurrentBalance) =
            abi.decode(responseData, (address, uint256, uint256));

        assertEq(respTrackedAddress, trackedAddress);
        assertEq(respPreviousBalance, previousBalance);
        assertEq(respCurrentBalance, currentBalance);
    }

    /// @notice Tests that `shouldRespond` returns true when the balance decreases and is above the absolute threshold.
    function testShouldRespond_AboveAbsoluteThreshold_Decrement() public {
        uint256 previousBalance = 10000 * 1e18;
        uint256 currentBalance = previousBalance - (trap.BALANCE_THRESHOLD_ABSOLUTE() + 1);

        bytes memory data0 = abi.encode(trackedAddress, currentBalance);
        bytes memory data1 = abi.encode(trackedAddress, previousBalance);
        bytes[] memory data = new bytes[](2);
        data[0] = data0;
        data[1] = data1;

        (bool triggered, bytes memory responseData) = trap.shouldRespond(data);
        assertTrue(triggered);

        (address respTrackedAddress, uint256 respPreviousBalance, uint256 respCurrentBalance) =
            abi.decode(responseData, (address, uint256, uint256));

        assertEq(respTrackedAddress, trackedAddress);
        assertEq(respPreviousBalance, previousBalance);
        assertEq(respCurrentBalance, currentBalance);
    }

    /// @notice Tests that `shouldRespond` returns true when the relative threshold is crossed.
    function testShouldRespond_AboveRelativeThreshold() public {
        uint256 previousBalance = 10000 * 1e18;
        // A change that is less than absolute threshold but more than 1% (100 BPS)
        uint256 currentBalance = previousBalance + (previousBalance * (trap.BALANCE_THRESHOLD_BPS() + 1)) / 10000;

        bytes memory data0 = abi.encode(trackedAddress, currentBalance);
        bytes memory data1 = abi.encode(trackedAddress, previousBalance);
        bytes[] memory data = new bytes[](2);
        data[0] = data0;
        data[1] = data1;

        (bool triggered, ) = trap.shouldRespond(data);
        assertTrue(triggered);
    }

    /// @notice Tests that `shouldRespond` returns false when there is not enough data.
    function testShouldRespond_NotEnoughData() public {
        bytes[] memory data = new bytes[](1);
        data[0] = abi.encode(trackedAddress, 10000 * 1e18);

        (bool triggered, ) = trap.shouldRespond(data);
        assertFalse(triggered);
    }

    /// @notice Tests that `shouldRespond` returns false if the tracked addresses in the data are different.
    function testShouldRespond_AddressDrift() public {
        uint256 previousBalance = 10000 * 1e18;
        uint256 currentBalance = previousBalance + trap.BALANCE_THRESHOLD_ABSOLUTE() + 1;

        bytes memory data0 = abi.encode(anotherAddress, currentBalance);
        bytes memory data1 = abi.encode(trackedAddress, previousBalance);
        bytes[] memory data = new bytes[](2);
        data[0] = data0;
        data[1] = data1;

        (bool triggered, ) = trap.shouldRespond(data);
        assertFalse(triggered);
    }
}
