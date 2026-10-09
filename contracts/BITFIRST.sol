// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * BITFIRST (¥) — BEP-20 fixed-supply token for BNB Smart Chain.
 *
 * Supply is minted ONCE in the constructor: 369,000,000 BITFIRST (18 decimals).
 * The whole supply is placed into six buckets at deployment.
 * No mint, no owner, no pause, no blacklist, no tax, no proxy, no rescue function.
 *
 *   Community lock  50%  184,500,000  -> CommunityLock contract
 *   Liquidity       10%   36,900,000  -> liquidity wallet (open market)
 *   Team vesting    10%   36,900,000  -> TeamVesting contract
 *   Development     10%   36,900,000  -> development wallet
 *   School          10%   36,900,000  -> school wallet
 *   Charity         10%   36,900,000  -> charity wallet
 *
 * Zero imports: single file, easy BscScan verification.
 */
contract BITFIRST {
    string public constant name = "BITFIRST";
    string public constant symbol = unicode"¥";
    uint8  public constant decimals = 18;

    uint256 public constant TOTAL_SUPPLY     = 369_000_000 * 10 ** 18;
    uint256 public constant COMMUNITY_AMOUNT = 184_500_000 * 10 ** 18;
    uint256 public constant TEN_PERCENT      =  36_900_000 * 10 ** 18;

    address public immutable communityLock;
    address public immutable liquidityWallet;
    address public immutable teamVesting;
    address public immutable developmentWallet;
    address public immutable schoolWallet;
    address public immutable charityWallet;

    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(
        address _communityLock,
        address _liquidityWallet,
        address _teamVesting,
        address _developmentWallet,
        address _schoolWallet,
        address _charityWallet
    ) {
        address[6] memory a = [
            _communityLock,
            _liquidityWallet,
            _teamVesting,
            _developmentWallet,
            _schoolWallet,
            _charityWallet
        ];

        // all six addresses must exist and must be different
        for (uint256 i = 0; i < a.length; i++) {
            require(a[i] != address(0), "BITFIRST: zero address");
            for (uint256 j = i + 1; j < a.length; j++) {
                require(a[i] != a[j], "BITFIRST: duplicate address");
            }
        }

        communityLock = _communityLock;
        liquidityWallet = _liquidityWallet;
        teamVesting = _teamVesting;
        developmentWallet = _developmentWallet;
        schoolWallet = _schoolWallet;
        charityWallet = _charityWallet;

        _mint(_communityLock, COMMUNITY_AMOUNT);   // 50%
        _mint(_liquidityWallet, TEN_PERCENT);      // 10%
        _mint(_teamVesting, TEN_PERCENT);          // 10%
        _mint(_developmentWallet, TEN_PERCENT);    // 10%
        _mint(_schoolWallet, TEN_PERCENT);         // 10%
        _mint(_charityWallet, TEN_PERCENT);        // 10%

        require(totalSupply == TOTAL_SUPPLY, "BITFIRST: mint mismatch");
    }

    function transfer(address to, uint256 value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value) external returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            require(allowed >= value, "BITFIRST: insufficient allowance");
            allowance[from][msg.sender] = allowed - value;
        }
        _transfer(from, to, value);
        return true;
    }

    function _transfer(address from, address to, uint256 value) internal {
        require(to != address(0), "BITFIRST: zero recipient");
        uint256 bal = balanceOf[from];
        require(bal >= value, "BITFIRST: insufficient balance");
        unchecked {
            balanceOf[from] = bal - value;
            balanceOf[to] += value;
        }
        emit Transfer(from, to, value);
    }

    function _approve(address owner_, address spender, uint256 value) internal {
        require(owner_ != address(0), "BITFIRST: zero owner");
        require(spender != address(0), "BITFIRST: zero spender");
        allowance[owner_][spender] = value;
        emit Approval(owner_, spender, value);
    }

    function _mint(address to, uint256 value) internal {
        require(to != address(0), "BITFIRST: mint to zero");
        totalSupply += value;
        unchecked {
            balanceOf[to] += value;
        }
        emit Transfer(address(0), to, value);
    }
}
