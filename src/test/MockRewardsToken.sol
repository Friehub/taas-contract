// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MockRewardsToken
 * @dev Simple ERC20 for testing TaaS AVS rewards on Sepolia.
 */
contract MockRewardsToken is ERC20, Ownable {
    constructor() ERC20("TaaS Rewards Token", "TAAS") Ownable() {
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}
