// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * LaunchpadSale
 * - Buyers pay USDC, receive allocation of TOKEN
 * - Fee in USDC is taken per purchase and sent to TREASURY
 * - After endTime, buyers claim tokens (sale must be funded with TOKEN)
 */
contract LaunchpadSale is Ownable {
    using SafeERC20 for IERC20;

    IERC20 public immutable TOKEN;
    IERC20 public immutable USDC;

    address public immutable TREASURY;
    uint16  public immutable FEE_BPS;       // e.g. 200 = 2.00%
    uint8   public immutable TOKEN_DECIMALS; // ex 18
    uint8   public immutable USDC_DECIMALS;  // ex 6

    uint256 public immutable PRICE_USDC_PER_TOKEN; // in USDC base units per 1 TOKEN (human)
    uint256 public immutable CAP_TOKENS_HUMAN;      // cap in human units (ex 10_000_000)
    uint256 public immutable START_TIME;
    uint256 public immutable END_TIME;

    uint256 public totalSoldBase; // sold in token base units (10**TOKEN_DECIMALS)
    mapping(address => uint256) public purchasedBase; // token base units owed to buyer
    mapping(address => bool) public claimed;

    event Bought(address indexed buyer, uint256 usdcIn, uint256 feeUsdc, uint256 tokensOutBase);
    event Claimed(address indexed buyer, uint256 tokensOutBase);
    event WithdrawUSDC(address indexed to, uint256 amount);
    event WithdrawUnsold(address indexed to, uint256 amountBase);

    error SaleNotActive();
    error SaleNotEnded();
    error SaleEnded();
    error ZeroAmount();
    error CapExceeded();
    error NotFunded();
    error AlreadyClaimed();

    constructor(
        address initialOwner,
        address token,
        address usdc,
        uint8 tokenDecimals,
        uint8 usdcDecimals,
        address treasury,
        uint16 feeBps,
        uint256 priceUsdcPerToken,
        uint256 capTokensHuman,
        uint256 startTime,
        uint256 endTime
    ) Ownable(initialOwner) {
        require(token != address(0) && usdc != address(0), "bad token/usdc");
        require(treasury != address(0), "bad treasury");
        require(endTime > startTime, "bad window");
        require(feeBps <= 10000, "fee too high");
        require(priceUsdcPerToken > 0, "price=0");
        require(capTokensHuman > 0, "cap=0");

        TOKEN = IERC20(token);
        USDC = IERC20(usdc);

        TOKEN_DECIMALS = tokenDecimals;
        USDC_DECIMALS = usdcDecimals;

        TREASURY = treasury;
        FEE_BPS = feeBps;

        PRICE_USDC_PER_TOKEN = priceUsdcPerToken;
        CAP_TOKENS_HUMAN = capTokensHuman;
        START_TIME = startTime;
        END_TIME = endTime;
    }

    function capBase() public view returns (uint256) {
        return CAP_TOKENS_HUMAN * (10 ** uint256(TOKEN_DECIMALS));
    }

    function isActive() public view returns (bool) {
        return block.timestamp >= START_TIME && block.timestamp < END_TIME;
    }

    function tokensFromUSDC(uint256 usdcAmount) public view returns (uint256 tokensOutBase) {
        // Convert usdcAmount (USDC base units) -> token base units
        //
        // PRICE_USDC_PER_TOKEN is defined as:
        //   USDC base units required to buy 1 TOKEN (human)
        //
        // tokensHuman = usdcAmount / PRICE
        // tokensBase  = tokensHuman * 10**TOKEN_DECIMALS
        //
        // To keep precision, do:
        // tokensBase = usdcAmount * 10**TOKEN_DECIMALS / PRICE_USDC_PER_TOKEN
        tokensOutBase = (usdcAmount * (10 ** uint256(TOKEN_DECIMALS))) / PRICE_USDC_PER_TOKEN;
    }

    function buy(uint256 usdcAmount) external {
        if (!isActive()) revert SaleNotActive();
        if (usdcAmount == 0) revert ZeroAmount();

        uint256 tokensOutBase = tokensFromUSDC(usdcAmount);
        if (tokensOutBase == 0) revert ZeroAmount();

        uint256 newTotal = totalSoldBase + tokensOutBase;
        if (newTotal > capBase()) revert CapExceeded();

        totalSoldBase = newTotal;
        purchasedBase[msg.sender] += tokensOutBase;

        // Pull USDC in
        USDC.safeTransferFrom(msg.sender, address(this), usdcAmount);

        // Compute fee and send it immediately to TREASURY
        uint256 feeUsdc = (usdcAmount * uint256(FEE_BPS)) / 10000;
        if (feeUsdc > 0) {
            USDC.safeTransfer(TREASURY, feeUsdc);
        }

        emit Bought(msg.sender, usdcAmount, feeUsdc, tokensOutBase);
    }

    function claim() external {
        if (block.timestamp < END_TIME) revert SaleNotEnded();
        if (claimed[msg.sender]) revert AlreadyClaimed();

        uint256 owed = purchasedBase[msg.sender];
        if (owed == 0) revert ZeroAmount();

        // Ensure contract is funded with enough tokens
        if (TOKEN.balanceOf(address(this)) < owed) revert NotFunded();

        claimed[msg.sender] = true;
        TOKEN.safeTransfer(msg.sender, owed);

        emit Claimed(msg.sender, owed);
    }

    // After sale ends, owner can withdraw remaining USDC (net proceeds)
    function withdrawUSDC(address to) external onlyOwner {
        if (block.timestamp < END_TIME) revert SaleNotEnded();
        uint256 bal = USDC.balanceOf(address(this));
        if (bal == 0) revert ZeroAmount();
        USDC.safeTransfer(to, bal);
        emit WithdrawUSDC(to, bal);
    }

    // After sale ends, owner can withdraw unsold tokens
    function withdrawUnsold(address to) external onlyOwner {
        if (block.timestamp < END_TIME) revert SaleNotEnded();

        uint256 sold = totalSoldBase;
        uint256 bal = TOKEN.balanceOf(address(this));

        // If everyone claimed already, bal might be unsold only.
        // If not everyone claimed, we must protect buyers:
        uint256 totalOwedUnclaimed = 0;
        // NOTE: we can’t iterate buyers on-chain. So we use a safe rule:
        // Do NOT allow withdrawing tokens unless the owner has already funded
        // enough for ALL sold tokens (buyers will claim from that pool).
        //
        // For simplicity: require token balance >= sold (so claims are safe),
        // then allow withdrawing excess above sold.
        if (bal < sold) revert NotFunded();

        uint256 withdrawable = bal - sold;
        if (withdrawable == 0) revert ZeroAmount();

        TOKEN.safeTransfer(to, withdrawable);
        emit WithdrawUnsold(to, withdrawable);
    }
}
