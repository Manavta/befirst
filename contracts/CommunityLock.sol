// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * CommunityLock — holds the 50% community share (184,500,000 BITFIRST).
 *
 * Rules built into the code:
 *  1. Every member is a NUMBER (id). The wallet is linked later, so you can
 *     prepare the whole list first and add wallets as people send them.
 *  2. Nobody can claim anything before `lockDays` (180 days) have passed.
 *  3. After the lock ends, a member can claim ONLY IF the owner has approved
 *     that member (`approveRelease`) or the owner has switched on
 *     `approveAll()`. Approval is ONE-WAY: there is no un-approve function,
 *     so a member who has been approved can never be locked again.
 *  4. The owner grants permission member-by-member or in batches, so the
 *     release flows out gradually, not all at once.
 *  5. There is no rescue function: only tokens that were never allocated to a
 *     member can be moved out.
 */
contract CommunityLock is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public token;              // set once after the token is deployed
    uint256 public immutable lockDays;
    uint256 public immutable unlockTime;

    bool public allApproved;          // one-way global permission switch
    uint256 public memberCount;
    uint256 public totalAllocated;
    uint256 public totalClaimed;

    struct Member {
        address wallet;               // address(0) = wallet not linked yet
        uint256 allocation;
        uint256 claimed;
        bool approved;
        bool exists;
    }

    mapping(uint256 => Member) public members;   // member id  => record
    mapping(address => uint256) public memberIdOf; // wallet   => member id
    uint256[] public idList;                      // all member ids, in order

    event TokenSet(address indexed token);
    event MemberAdded(uint256 indexed id, uint256 allocation);
    event WalletLinked(uint256 indexed id, address indexed wallet);
    event ReleaseApproved(uint256 indexed id);
    event AllApproved();
    event Claimed(uint256 indexed id, address indexed wallet, uint256 amount);
    event UnallocatedWithdrawn(address indexed to, uint256 amount);

    constructor(uint256 _lockDays) Ownable(msg.sender) {
        require(_lockDays > 0, "lockDays must be > 0");
        lockDays = _lockDays;
        unlockTime = block.timestamp + (_lockDays * 1 days);
    }

    /* ------------------------------------------------------------------ */
    /*  one-time setup                                                     */
    /* ------------------------------------------------------------------ */

    function setToken(address tokenAddress) external onlyOwner {
        require(address(token) == address(0), "token already set");
        require(tokenAddress != address(0), "zero address");
        token = IERC20(tokenAddress);
        emit TokenSet(tokenAddress);
    }

    /* ------------------------------------------------------------------ */
    /*  member list (numbers first, wallets later)                         */
    /* ------------------------------------------------------------------ */

    function addMember(uint256 id, uint256 amount) external onlyOwner {
        _addMember(id, amount);
    }

    function addMembers(uint256[] calldata ids, uint256[] calldata amounts) external onlyOwner {
        require(ids.length == amounts.length && ids.length > 0, "bad input");
        for (uint256 i = 0; i < ids.length; i++) {
            _addMember(ids[i], amounts[i]);
        }
    }

    function _addMember(uint256 id, uint256 amount) internal {
        require(address(token) != address(0), "token not set");
        require(id > 0, "id must be > 0");
        require(!members[id].exists, "id already exists");
        require(amount > 0, "amount must be > 0");
        require(totalAllocated + amount <= token.balanceOf(address(this)), "not enough tokens in vault");

        members[id] = Member({
            wallet: address(0),
            allocation: amount,
            claimed: 0,
            approved: false,
            exists: true
        });
        idList.push(id);
        memberCount += 1;
        totalAllocated += amount;
        emit MemberAdded(id, amount);
    }

    function linkWallet(uint256 id, address wallet) external onlyOwner {
        _linkWallet(id, wallet);
    }

    function linkWallets(uint256[] calldata ids, address[] calldata wallets) external onlyOwner {
        require(ids.length == wallets.length && ids.length > 0, "bad input");
        for (uint256 i = 0; i < ids.length; i++) {
            _linkWallet(ids[i], wallets[i]);
        }
    }

    function _linkWallet(uint256 id, address wallet) internal {
        require(members[id].exists, "member id not found");
        require(wallet != address(0), "zero address");
        require(members[id].wallet == address(0), "wallet already linked");
        require(memberIdOf[wallet] == 0, "wallet already used");
        members[id].wallet = wallet;
        memberIdOf[wallet] = id;
        emit WalletLinked(id, wallet);
    }

    /* ------------------------------------------------------------------ */
    /*  owner permission (one-way)                                         */
    /* ------------------------------------------------------------------ */

    function approveRelease(uint256 id) external onlyOwner {
        require(members[id].exists, "member id not found");
        require(!members[id].approved, "already approved");
        members[id].approved = true;
        emit ReleaseApproved(id);
    }

    function approveReleases(uint256[] calldata ids) external onlyOwner {
        require(ids.length > 0, "bad input");
        for (uint256 i = 0; i < ids.length; i++) {
            require(members[ids[i]].exists, "member id not found");
            require(!members[ids[i]].approved, "already approved");
            members[ids[i]].approved = true;
            emit ReleaseApproved(ids[i]);
        }
    }

    /// Switch on permission for EVERY member at once. One-way, cannot be undone.
    function approveAll() external onlyOwner {
        require(!allApproved, "all already approved");
        allApproved = true;
        emit AllApproved();
    }

    /* ------------------------------------------------------------------ */
    /*  member claim                                                       */
    /* ------------------------------------------------------------------ */

    function claim() external nonReentrant {
        uint256 id = memberIdOf[msg.sender];
        require(id != 0, "not a member");

        Member storage m = members[id];
        require(block.timestamp >= unlockTime, "Vault: still locked (180 days)");
        require(m.approved || allApproved, "Owner approval pending");

        uint256 amount = m.allocation - m.claimed;
        require(amount > 0, "Nothing to claim");

        m.claimed += amount;
        totalClaimed += amount;
        token.safeTransfer(msg.sender, amount);
        emit Claimed(id, msg.sender, amount);
    }

    /* ------------------------------------------------------------------ */
    /*  views                                                             */
    /* ------------------------------------------------------------------ */

    function claimable(uint256 id) public view returns (uint256) {
        Member storage m = members[id];
        if (!m.exists) return 0;
        if (m.wallet == address(0)) return 0;
        if (block.timestamp < unlockTime) return 0;
        if (!(m.approved || allApproved)) return 0;
        return m.allocation - m.claimed;
    }

    function tokensInVault() public view returns (uint256) {
        if (address(token) == address(0)) return 0;
        return token.balanceOf(address(this));
    }

    function unallocatedTokens() public view returns (uint256) {
        if (address(token) == address(0)) return 0;
        uint256 stillOwedToMembers = totalAllocated - totalClaimed;
        uint256 bal = token.balanceOf(address(this));
        return bal > stillOwedToMembers ? bal - stillOwedToMembers : 0;
    }

    /// Move out ONLY tokens that were never allocated to any member.
    function withdrawUnallocated(address to, uint256 amount) external onlyOwner nonReentrant {
        require(to != address(0), "zero address");
        require(amount <= unallocatedTokens(), "only unallocated tokens");
        token.safeTransfer(to, amount);
        emit UnallocatedWithdrawn(to, amount);
    }

    /// Paginated read of the member list: memberPage(0, 100), memberPage(100, 100) ...
    function memberPage(uint256 start, uint256 count)
        external
        view
        returns (
            uint256[] memory ids,
            address[] memory wallets,
            uint256[] memory allocations,
            uint256[] memory claimeds,
            bool[] memory approveds
        )
    {
        uint256 n = idList.length;
        if (start >= n) {
            return (new uint256[](0), new address[](0), new uint256[](0), new uint256[](0), new bool[](0));
        }
        uint256 end = start + count;
        if (end > n) end = n;
        uint256 len = end - start;

        ids = new uint256[](len);
        wallets = new address[](len);
        allocations = new uint256[](len);
        claimeds = new uint256[](len);
        approveds = new bool[](len);

        for (uint256 i = 0; i < len; i++) {
            uint256 id = idList[start + i];
            Member storage m = members[id];
            ids[i] = id;
            wallets[i] = m.wallet;
            allocations[i] = m.allocation;
            claimeds[i] = m.claimed;
            approveds[i] = m.approved;
        }
    }
}
