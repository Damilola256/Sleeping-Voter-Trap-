# Sleeping Voter Drosera Trap

Hello! I've created this project to demonstrate a "Sleeping Voter" trap using the Drosera Protocol. This trap is designed to monitor the on-chain activity of large token holders in a DAO, specifically those who have been inactive in governance, and to trigger a response when they "wake up."

## What is a Sleeping Voter?

In the context of a DAO, a "sleeping voter" is an address that holds a significant amount of governance tokens but does not actively participate in voting on proposals. These addresses have the potential to heavily influence the outcome of a vote, and their sudden activity can be a significant event for the DAO.

## How the Trap Works

This Drosera trap monitors the balance of a specific ERC20 governance token for a predefined "sleeping voter" address. Here's the logic:

1.  **Monitoring:** The `SleepingVoterTrap` contract continuously monitors the token balance of the tracked address.
2.  **Threshold:** I've set a `BALANCE_THRESHOLD` in the contract. This is the minimum amount by which the token balance must change to be considered a significant event.
3.  **Trigger:** If the balance of the tracked address changes by an amount greater than the `BALANCE_THRESHOLD` (either an increase or a decrease), the trap's `shouldRespond` function returns `true`.
4.  **Response:** When the trap is triggered, the Drosera network calls the `respond` function in the `SleepingVoterResponse` contract. This response contract then emits a `VoterWokeUp` event, logging the voter's address, their previous balance, and their new balance. This event can be monitored by off-chain services, bots, or community members to alert them of the activity.

This trap is built to be reactive, in line with the Drosera philosophy. It doesn't predict future actions but rather reacts to on-chain events as they happen.

## Contracts

*   `src/SleepingVoterTrap.sol`: The main trap contract that monitors the token balance.
*   `src/SleepingVoterResponse.sol`: The response contract that is called when the trap is triggered.
*   `src/ResponseProtocol.sol`: A base contract for the response contract.

## Getting Started

### Prerequisites

*   [Foundry](https://getfoundry.sh/)
*   [Drosera Prover](https://dev.drosera.io/)

### Installation

1.  Clone the repository:
    ```bash
    git clone <repository-url>
    cd sleeping-voter-trap
    ```
2.  Install dependencies:
    ```bash
    forge install
    ```

### Deployment

This project requires deploying two contracts: the `SleepingVoterResponse` and the `SleepingVoterTrap`.

1.  **Deploy the Response Contract:**

    The response contract needs to be deployed first to get its address. I've included a Foundry script to make this easy.

    ```bash
    forge script scripts/Deploy.s.sol --rpc-url <your-rpc-url> --private-key <your-private-key> --broadcast
    ```

    This will deploy the `SleepingVoterResponse` contract and log its address to the console.

2.  **Update `drosera.toml`:**

    Open the `drosera.toml` file and replace the placeholder addresses with the address of the deployed `SleepingVoterResponse` contract.

    ```toml
    trap_name = "SleepingVoterTrap"
    trap_address = "0x..." # This will be deployed by the Drosera CLI
    response_contract = "0x<deployed-response-contract-address>"
    handler_address = "0x<deployed-response-contract-address>"
    ```

3.  **Deploy the Trap Contract:**

    The `SleepingVoterTrap` is deployed using the Drosera CLI. Before deploying, you'll need to replace the placeholder addresses in `src/SleepingVoterTrap.sol` with the actual addresses you want to monitor.

    ```solidity
    // src/SleepingVoterTrap.sol
    address public constant trackedAddress = 0x...; // Address of the sleeping voter
    IERC20 public constant token = IERC20(0x...); // Address of the governance token
    ```

    Once you've updated the addresses, you can deploy the trap using the Drosera documentation.

### Testing

I've included a test suite for the `SleepingVoterTrap` contract. You can run the tests using Foundry:

```bash
forge test
```

This will run the tests in `test/SleepingVoterTrap.t.sol` and ensure that the trap's logic is working as expected.

## A Note on Hardcoded Addresses

As per the requirements, all addresses and configuration values in the contracts are hardcoded. This is a constraint of the current Drosera implementation, which does not support constructor arguments or initializers for traps. While this makes the contracts less flexible, it ensures they are secure and easy to deploy within the Drosera ecosystem. For testing purposes, this means that some tests have to work around the hardcoded addresses, but the core logic is fully tested.

I hope this project is a clear and useful example of how to build a Drosera trap. Let me know if you have any questions!