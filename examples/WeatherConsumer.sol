// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TaaSConsumer} from "../src/TaaSConsumer.sol";
import {ITaaSServiceManager} from "../src/ITaaSServiceManager.sol";

/**
 * @title WeatherConsumer
 * @dev A production-ready example of integrating with the TaaS AVS.
 * This contract requests weather data and securely fulfills it using the TaaSConsumer base.
 */
contract WeatherConsumer is TaaSConsumer {
    
    struct WeatherReport {
        string city;
        uint256 temperature; // scaled by 100
        uint256 timestamp;
    }

    // Tracks the latest verified data for each city
    mapping(string => WeatherReport) public cityWeather;
    
    // Maps TaaS Task IDs to the city requested
    mapping(bytes32 => string) public pendingRequests;

    event WeatherRequested(bytes32 indexed taskId, string city);
    event WeatherUpdated(string indexed city, uint256 temperature);

    constructor(address _serviceManager) TaaSConsumer(_serviceManager) {}

    /**
     * @notice Initiates a verifiable weather fetch request.
     * @param city The city to fetch weather for.
     */
    function requestWeather(string calldata city) external {
        // 1. Request the task from TaaS
        // We use the 'weather.temperature' capability which returns a uint256
        bytes32 taskId = _requestTask(
            "weather.temperature",
            abi.encode(city),
            ITaaSServiceManager.AggregationStrategy.MEDIAN,
            3,      // Wait for at least 3 sources
            67,     // 67% stake threshold
            uint64(block.timestamp + 3600) // 1 hour deadline
        );

        pendingRequests[taskId] = city;
        emit WeatherRequested(taskId, city);
    }

    /**
     * @notice Securely fulfills the weather request.
     * @dev The onlyTaaSSettled modifier ensures that:
     *      1. The task is marked as completed on the TaaS Service Manager.
     *      2. The hash of the provided 'temperature' matches the hash signed by the AVS.
     */
    function fulfillWeather(bytes32 taskId, uint256 temperature) 
        external 
        onlyTaaSSettled(taskId, abi.encode(temperature)) 
    {
        string memory city = pendingRequests[taskId];
        require(bytes(city).length > 0, "Unknown or already fulfilled task");

        // Update local state with verified data
        cityWeather[city] = WeatherReport({
            city: city,
            temperature: temperature,
            timestamp: block.timestamp
        });

        // Cleanup
        delete pendingRequests[taskId];

        emit WeatherUpdated(city, temperature);
    }

    /**
     * @notice Helper to get the latest weather for a city.
     */
    function getLatestTemperature(string calldata city) external view returns (uint256) {
        return cityWeather[city].temperature;
    }
}
