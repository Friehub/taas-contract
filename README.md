# TaaS Solidity SDK

Smart contract interfaces and base contracts for the [TaaS Protocol](https://www.friehub.cloud).

## Installation

### Foundry
```bash
forge install Friehub/taas-contract
```

## Usage

### Inherit from TaaSConsumer
Inheriting from `TaaSConsumer` provides your contract with secure helpers to request facts and verify results.

```solidity
import "taas-contract/TaaSConsumer.sol";

contract MyWeatherApp is TaaSConsumer {
    constructor(address _serviceManager) TaaSConsumer(_serviceManager) {}

    function fetchWeather(string calldata city) external {
        _requestTask(
            "weather.temperature",
            abi.encode(city),
            ITaaSServiceManager.AggregationStrategy.MEDIAN,
            3,
            67,
            uint64(block.timestamp + 1 hours)
        );
    }

    function fulfill(bytes32 taskId, string calldata result) 
        external 
        onlyTaaSSettled(taskId, bytes(result)) 
    {
        // Result is now verified!
    }
}
```


