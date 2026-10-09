// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * TeamVesting — holds the 10% team share (36,900,000 BITFIRST).
 *
 * Schedule (values set at deployment):
 *   - 365 day cliff: nothing can move before that.
 *   - after the cliff, one release every 10 days of 369,000 tokens
 *     (369,000 = 1% of the team share) -> 100 releases -> fully released
 *     on day 365 + 990 = day 1355.
 *
 * The schedule lives in the contract, not in a switch: `release()` is public,
 * so ANYONE (not just the owner) can push a due release to the beneficiary.
 * The owner only has one job: setting the token address once.
 */
contract TeamVesting is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public token;                       // set once after token deploy
    address public immutable beneficiary;      // team wallet
    uint256 public immutable cliffDays;
    uint256 public immutable intervalDays;
    uint256 public immutable releaseAmount;

    uint256 public immutable deployedAt;
    uint256 public immutable firstReleaseAt;

    uint256 public totalReleased;

    event TokenSet(address indexed token);
    event Released(uint256 amount, uint256 totalReleased);

    constructor(
        address _beneficiary,
        uint256 _cliffDays,
        uint256 _intervalDays,
        uint256 _releaseAmount
    ) Ownable(msg.sender) {
        require(_beneficiary != address(0), "zero beneficiary");
        require(_intervalDays > 0, "interval must be > 0");
        require(_releaseAmount > 0, "releaseAmount must be > 0");

        beneficiary = _beneficiary;
        cliffDays = _cliffDays;
        intervalDays = _intervalDays;
        releaseAmount = _releaseAmount;

        deployedAt = block.timestamp;
        firstReleaseAt = block.timestamp + (_cliffDays * 1 days);
    }

    function setToken(address tokenAddress) external onlyOwner {
        require(address(token) == address(0), "token already set");
        require(tokenAddress != address(0), "zero address");
        token = IERC20(tokenAddress);
        emit TokenSet(tokenAddress);
    }

    /// How many 10-day steps have been unlocked so far (0 before the cliff).
    function releasedSteps() public view returns (uint256) {
        if (address(token) == address(0)) return 0;
        if (block.timestamp < firstReleaseAt) return 0;
        return ((block.timestamp - firstReleaseAt) / (intervalDays * 1 days)) + 1;
    }

    function vestedTotal() public view returns (uint256) {
        return releasedSteps() * releaseAmount;
    }

    function balanceInVault() public view returns (uint256) {
        if (address(token) == address(0)) return 0;
        return token.balanceOf(address(this));
    }

    /// Tokens that are unlocked and can be pushed out right now.
    function available() public view returns (uint256) {
        uint256 vested = vestedTotal();
        if (vested <= totalReleased) return 0;
        uint256 owed = vested - totalReleased;
        uint256 bal = balanceInVault();
        return owed > bal ? bal : owed;
    }

    function nextReleaseAt() public view returns (uint256) {
        if (block.timestamp < firstReleaseAt) return firstReleaseAt;
        return firstReleaseAt + (releasedSteps() * intervalDays * 1 days);
    }

    /// Permissionless: anyone can call it once a release is due.
    function release() external nonReentrant returns (uint256) {
        uint256 amount = available();
        require(amount > 0, "nothing to release yet");
        totalReleased += amount;
        token.safeTransfer(beneficiary, amount);
        emit Released(amount, totalReleased);
        return amount;
    }
}
