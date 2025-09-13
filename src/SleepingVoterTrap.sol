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
contract SleepingVoterTrap is ITrap {
    // @dev The address of the "sleeping voter" to monitor.
    // TODO: Replace with the actual address of the voter.
    address public constant trackedAddress = 0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B; // Placeholder: Vitalik Buterin's address

    // @dev The ERC20 governance token to monitor.
    // TODO: Replace with the actual address of the governance token.
    IERC20 public constant token = IERC20(0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984); // Placeholder: UNI token

    // @dev The minimum absolute change in balance required to trigger a response.
    uint256 public constant BALANCE_THRESHOLD_ABSOLUTE = 1000 * 1e18; // 1000 tokens with 18 decimals

    // @dev The minimum relative change in balance in basis points (BPS) required to trigger a response. 100 BPS = 1%.
    uint256 public constant BALANCE_THRESHOLD_BPS = 100; // 1%

    /// @notice Collects the current balance of the tracked token for the sleeping voter.
    /// @dev This function is called by the Drosera network to gather data for `shouldRespond`.
    /// It includes a try-catch block to handle cases where the token contract might not exist on the network, returning a balance of 0 in such cases.
    /// @return A bytes-encoded tuple containing the tracked address and its token balance.
    function collect() external view override returns (bytes memory) {
        uint256 tokenBalance = 0;
        if (address(token).code.length > 0) {
            try token.balanceOf(trackedAddress) returns (uint256 balance) {
                tokenBalance = balance;
            } catch {
                // The contract exists but the call reverted.
                tokenBalance = 0;
            }
        }
        return abi.encode(trackedAddress, tokenBalance);
    }

    /// @notice Determines if a response should be triggered based on a change in the voter's token balance.
    /// @dev This function is called by the Drosera network. It compares two consecutive data points from `collect`.
    /// A response is triggered if the change in balance exceeds either the absolute or relative threshold.
    /// It also ensures that the tracked address in both data points is the same.
    /// @param data An array of bytes-encoded data points from previous `collect` calls. `data[0]` is the current, `data[1]` is the previous.
    /// @return A boolean indicating whether to respond and bytes-encoded data for the response contract.
    function shouldRespond(bytes[] calldata data) external pure override returns (bool, bytes memory) {
        if (data.length < 2) {
            return (false, bytes(""));
        }

        (address trackedAddrCurrent, uint256 balanceCurrent) = abi.decode(data[0], (address, uint256));
        (address trackedAddrPrevious, uint256 balancePrevious) = abi.decode(data[1], (address, uint256));

        // Sanity check for address drift
        if (trackedAddrCurrent != trackedAddrPrevious || trackedAddrCurrent != trackedAddress) {
            return (false, bytes(""));
        }

        uint256 balanceDiff = balancePrevious > balanceCurrent ? balancePrevious - balanceCurrent : balanceCurrent - balancePrevious;

        // Check absolute threshold
        bool triggered = balanceDiff > BALANCE_THRESHOLD_ABSOLUTE;

        // Check relative threshold if absolute not met and previous balance was not zero
        if (!triggered && balancePrevious > 0) {
            uint256 bpsChange = (balanceDiff * 10000) / balancePrevious;
            if (bpsChange > BALANCE_THRESHOLD_BPS) {
                triggered = true;
            }
        }

        if (triggered) {
            // Encode as (trackedAddress, previousBalance, currentBalance)
            bytes memory responseData = abi.encode(trackedAddress, balancePrevious, balanceCurrent);
            return (true, responseData);
        }

        return (false, bytes(""));
    }
}