// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Astracor
 * @notice Simple ERC20 with owner-mint.
 * @dev For a launch, you can mint supply to treasury and then fund the sale contract.
 */
contract Astracor is ERC20, Ownable {
    uint8 private immutable _decimals;

    constructor(
        address initialOwner,
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) ERC20(name_, symbol_) Ownable(initialOwner) {
        _decimals = decimals_;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}
