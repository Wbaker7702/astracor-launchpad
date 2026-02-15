// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";

contract LaunchpadFactory is Ownable {
    address public usdc;
    uint8 public usdcDecimals;

    address public treasury;
    uint16 public feeBps; // 200 = 2.00%

    event ParamsUpdated(address indexed usdc, uint8 usdcDecimals, address indexed treasury, uint16 feeBps);

    event SaleCreated(
        address indexed creator,
        address indexed sale,
        address indexed token,
        uint256 priceUSDCPerToken,
        uint256 capTokensHuman,
        uint256 startTime,
        uint256 endTime
    );

    error BadUSDC();
    error BadTreasury();
    error BadFee();
    error BadWindow();

    constructor(address initialOwner, address usdc_, uint8 usdcDecimals_, address treasury_, uint16 feeBps_)
        Ownable(initialOwner)
    {
        if (usdc_ == address(0)) revert BadUSDC();
        if (treasury_ == address(0)) revert BadTreasury();
        if (feeBps_ > 10000) revert BadFee();

        usdc = usdc_;
        usdcDecimals = usdcDecimals_;
        treasury = treasury_;
        feeBps = feeBps_;

        emit ParamsUpdated(usdc, usdcDecimals, treasury, feeBps);
    }

    function setParams(address usdc_, uint8 usdcDecimals_, address treasury_, uint16 feeBps_) external onlyOwner {
        if (usdc_ == address(0)) revert BadUSDC();
        if (treasury_ == address(0)) revert BadTreasury();
        if (feeBps_ > 10000) revert BadFee();

        usdc = usdc_;
        usdcDecimals = usdcDecimals_;
        treasury = treasury_;
        feeBps = feeBps_;

        emit ParamsUpdated(usdc, usdcDecimals, treasury, feeBps);
    }

    function createSale(bytes calldata initCode) external returns (address sale) {
        // initCode is the full constructor initcode for LaunchpadSale
        bytes memory code = initCode;

        assembly {
            sale := create(0, add(code, 0x20), mload(code))
        }
        require(sale != address(0), "deploy failed");
    }
}
