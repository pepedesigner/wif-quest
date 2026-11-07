// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/// @notice Minimal creator-reviewed bounty escrow. Metadata and submissions are public.
contract QuestEscrow {
    enum Status { Open, Submitted, Paid, Refunded }
    struct Quest { address creator; address contributor; uint256 reward; uint64 deadline; Status status; string title; string description; string deliverable; }
    IERC20 public immutable token;
    Quest[] private quests;
    uint256 private entered = 1;
    event Created(uint256 indexed id, address indexed creator, uint256 reward);
    event Submitted(uint256 indexed id, address indexed contributor, string deliverable);
    event Paid(uint256 indexed id, address indexed contributor, uint256 reward);
    event Refunded(uint256 indexed id, address indexed creator, uint256 reward);
    modifier nonReentrant() { require(entered == 1, "reentrant"); entered = 2; _; entered = 1; }
    constructor(address token_) { require(token_ != address(0), "zero token"); token = IERC20(token_); }
    function count() external view returns (uint256) { return quests.length; }
    function getQuest(uint256 id) external view returns (Quest memory) { return quests[id]; }
    function create(string calldata title, string calldata description, uint256 reward, uint64 deadline) external nonReentrant {
        require(bytes(title).length > 0 && bytes(title).length <= 100, "title");
        require(bytes(description).length > 0 && bytes(description).length <= 2000, "description");
        require(reward > 0 && deadline > block.timestamp, "reward or deadline");
        uint256 id = quests.length;
        quests.push(Quest(msg.sender, address(0), reward, deadline, Status.Open, title, description, ""));
        require(token.transferFrom(msg.sender, address(this), reward), "deposit failed");
        emit Created(id, msg.sender, reward);
    }
    function submit(uint256 id, string calldata deliverable) external {
        Quest storage q = quests[id];
        require(q.status == Status.Open && block.timestamp < q.deadline, "not open");
        require(msg.sender != q.creator && bytes(deliverable).length > 0 && bytes(deliverable).length <= 500, "invalid submission");
        q.contributor = msg.sender; q.deliverable = deliverable; q.status = Status.Submitted;
        emit Submitted(id, msg.sender, deliverable);
    }
    function approve(uint256 id) external nonReentrant {
        Quest storage q = quests[id];
        require(msg.sender == q.creator && q.status == Status.Submitted, "not allowed");
        q.status = Status.Paid;
        require(token.transfer(q.contributor, q.reward), "payout failed");
        emit Paid(id, q.contributor, q.reward);
    }
    function refund(uint256 id) external nonReentrant {
        Quest storage q = quests[id];
        require(msg.sender == q.creator && (q.status == Status.Open || q.status == Status.Submitted) && block.timestamp >= q.deadline, "not refundable");
        q.status = Status.Refunded;
        require(token.transfer(q.creator, q.reward), "refund failed");
        emit Refunded(id, q.creator, q.reward);
    }
    /// @dev A contributor can withdraw a submission after the deadline.
    function withdrawSubmission(uint256 id) external {
        Quest storage q = quests[id];
        require(q.status == Status.Submitted && msg.sender == q.contributor && block.timestamp >= q.deadline, "not allowed");
        q.status = Status.Open; q.contributor = address(0); q.deliverable = "";
    }
}
