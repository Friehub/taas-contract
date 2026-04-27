# TaaS Solidity SDK 🛡️

Secure, verifiable infrastructure for consuming off-chain truth via the **TaaS (Truth-as-a-Service)** AVS on EigenLayer.

## Features
- **Deterministic Verification**: Securely verify off-chain results against the BFT consensus reached by the TaaS network.
- **AVS Security**: Leverages restaked ETH security and EigenLayer slashability.
- **Easy Integration**: Inherit from `TaaSConsumer` to automate all security checks.

---

##  Quick Start

### 1. Installation

In your Foundry project:
```bash
forge install Friehub/taas-contract
```

Update your `remappings.txt`:
```text
taas-contract/=lib/taas-contract/src/
```

### 2. Basic Usage

Inherit from `TaaSConsumer` and use the `onlyTaaSSettled` modifier for security.

```solidity
import "taas-contract/TaaSConsumer.sol";

contract MyApp is TaaSConsumer {
    constructor(address _sm) TaaSConsumer(_sm) {}

    // 1. Request Data
    function startFetch() external {
        _requestTask(
            "crypto.eth.price",
            "", 
            ITaaSServiceManager.AggregationStrategy.MEDIAN,
            3,  // min sources
            67, // quorum %
            uint64(block.timestamp + 1 hours)
        );
    }

    // 2. Fulfill securely
    function fulfill(bytes32 taskId, uint256 price) 
        external 
        onlyTaaSSettled(taskId, abi.encode(price)) 
    {
        // 'price' is now verified by the TaaS network!
    }
}
```

---

##  Advanced Integration

### Aggregation Strategies
TaaS supports multiple on-chain aggregation strategies to fit your trust model:
- `MEDIAN`: Best for price feeds (requires `uint256`).
- `MAJORITY`: Best for string or boolean data.
- `UNION`: Returns the collection of all unique historical values.
- `FIRST`: Returns the first verified TEE proof (lowest latency).
- `BLS_QUORUM`: Full stake-weighted signature aggregation.

### Capability Registry
Check our [Documentation Portal](https://docs.friehub.cloud) for a full list of supported capabilities (e.g., `weather.temperature`, `sports.football.score`, `crypto.btc.price`).

---

##  Network Addresses

| Network | ServiceManager Proxy | Registry Proxy | TruthPaymaster |
| :--- | :--- | :--- | :--- |
| **Ethereum Sepolia** | `0x886bbbb92e1c167e59ed63d6befbcb8f6da6f90c` | `0x219a1bd8c73893cf634ef00492b37eb1b2c65a68` | `0x41c02ac0fc69de0277c8b0b3c12847974d63bd19` |
| **Hoodi (Holesky)** | `0x6942881Bbf662549cBA6AeC14b885fA27d0eBBd6` | `0x46a6d51d031e7a7cb8ba613978188542eb2b1209` | `TBD (Deploying)` |

---

##  Repository Contents
- **`/src`**: Core interfaces and the `TaaSConsumer` base.
- **`/examples`**: Full integration examples (see `WeatherConsumer.sol`).
- **`/script`**: Protocol maintenance and deployment scripts.

## License
MIT - Friehub
