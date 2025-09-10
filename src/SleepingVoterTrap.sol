// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ITrap} from "drosera-contracts/interfaces/ITrap.sol";
import {IERC20} from "./interfaces/IERC20.sol";

/// @title SleepingVoterTrap
/// @notice This trap monitors the balance of a specified ERC20 token for a "sleeping voter".
/// A sleeping voter is an address that holds a significant amount of governance tokens but is inactive.
/// The trap triggers if the token balance of this address changes by a defined threshold,
/// potentially indicating that the voter is "waking up" to sell tokens or engage in governance.
///
/// @dev This contract is designed for the Drosera Protocol and follows its constraints:
/// - No constructor arguments: All addresses and thresholds are hardcoded.
/// - No initializers: State is configured at deployment.
/// - Whitelisted operator: Only authorized addresses can call `collect`.
contract SleepingVoterTrap is ITrap {
    // @dev The address of the "sleeping voter" to monitor.
    // TODO: Replace with the actual address of the voter.
    address public constant trackedAddress = 0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B; // Placeholder: Vitalik Buterin's address

    // @dev The ERC20 governance token to monitor.
    // TODO: Replace with the actual address of the governance token.
    IERC20 public constant token = IERC20(0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984); // Placeholder: UNI token

    // @dev The minimum change in balance required to trigger a response.
    uint256 public constant BALANCE_THRESHOLD = 1000 * 1e18; // 1000 tokens with 18 decimals

    // @dev A mapping to store whitelisted operators who can call the `collect` function.
    mapping(address => bool) public whitelist;

    /// @dev The address of the contract deployer, who is automatically whitelisted.
    address public immutable deployer;

    /// @notice Sets the deployer of the contract and adds them to the whitelist.
    constructor() {
        deployer = msg.sender;
        whitelist[msg.sender] = true;
    }

    /// @dev A modifier to ensure that only whitelisted addresses can execute a function.
    modifier onlyWhitelisted() {
        require(whitelist[msg.sender], "Not whitelisted");
        _;
    }

    /// @notice Adds a new address to the whitelist.
    /// @param _operator The address to whitelist.
    function addWhitelisted(address _operator) external {
        require(msg.sender == deployer, "Only deployer can add");
        whitelist[_operator] = true;
    }

    /// @notice Removes an address from the whitelist.
    /// @param _operator The address to remove from the whitelist.
    function removeWhitelisted(address _operator) external {
        require(msg.sender == deployer, "Only deployer can remove");
        whitelist[_operator] = false;
    }

    /// @notice Collects the current balance of the tracked token for the sleeping voter.
    /// @dev This function is called by the Drosera network to gather data for `shouldRespond`.
    /// It can only be called by a whitelisted operator.
    /// @return A bytes-encoded tuple containing the tracked address and its token balance.
    function collect() external view override onlyWhitelisted returns (bytes memory) {
        uint256 tokenBalance = token.balanceOf(trackedAddress);
        return abi.encode(trackedAddress, tokenBalance);
    }

    /// @notice Determines if a response should be triggered based on a change in the voter's token balance.
    /// @dev This function is called by the Drosera network. It compares two consecutive data points from `collect`.
    /// A response is triggered if the absolute difference in balance exceeds `BALANCE_THRESHOLD`.
    /// @param data An array of bytes-encoded data points from previous `collect` calls.
    /// @return A boolean indicating whether to respond and bytes-encoded data for the response contract.
    function shouldRespond(bytes[] calldata data) external pure override returns (bool, bytes memory) {
        if (data.length < 2) {
            return (false, "");
        }

        (address trackedAddr0, uint256 balance0) = abi.decode(data[0], (address, uint256));
        (address trackedAddr1, uint256 balance1) = abi.decode(data[1], (address, uint256));

        uint256 balanceDiff = balance1 > balance0 ? balance1 - balance0 : balance0 - balance1;

        bool triggered = balanceDiff > BALANCE_THRESHOLD;

        if (triggered) {
            bytes memory responseData = abi.encode(trackedAddr1, balance0, balance1);
            return (true, responseData);
        }

        return (false, "");
    }
}