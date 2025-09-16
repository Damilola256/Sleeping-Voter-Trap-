// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


import {IResponse} from "./interfaces/IResponse.sol";
import {ResponseProtocol} from "./ResponseProtocol.sol";

/// @title SleepingVoterResponse
/// @notice This contract is the response component for the SleepingVoterTrap.
/// @dev It is called by the Drosera network when the `shouldRespond` function of the trap returns true.
/// Its purpose is to log the detected balance change by emitting an event.
/// Only the guardian address (the Drosera executor) can call the respond function.
contract SleepingVoterResponse is IResponse, ResponseProtocol {
    /// @notice Emitted when a sleeping voter's token balance changes significantly.
    /// @param trackedAddress The address of the voter whose balance changed.
    /// @param previousBalance The token balance before the change.
    /// @param newBalance The token balance after the change.
    event VoterWokeUp(
        address indexed trackedAddress,
        uint256 previousBalance,
        uint256 newBalance
    );

    /// @dev The address authorized to call the `respond` function.
    address public immutable guardian;

    /// @notice Sets the guardian address upon deployment.
    /// @param _guardian The address of the Drosera executor.
    constructor(address _guardian) {
        guardian = _guardian;
    }

    /// @notice The entry point for the response.
    /// @dev This function is called by the Drosera network. It decodes the data from the trap
    /// and emits an event to log the incident. It can only be called by the guardian.
    /// @param data The bytes-encoded data from the `SleepingVoterTrap`, containing (trackedAddress, previousBalance, currentBalance).
    function respond(bytes calldata data) external override {
        require(msg.sender == guardian, "unauthorized");
        (address trackedAddress, uint256 previousBalance, uint256 newBalance) = 
            abi.decode(data, (address, uint256, uint256));

        emit VoterWokeUp(trackedAddress, previousBalance, newBalance);
    }
}
