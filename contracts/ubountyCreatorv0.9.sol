// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/// @title BountyChest Contract for holding funds
contract BountyChest is ReentrancyGuard {
    address public immutable creator;
    IERC20 public immutable devcash;
    
    constructor(address _devcash) {
        creator = msg.sender;
        devcash = IERC20(_devcash);
        devcash.approve(msg.sender, type(uint256).max);
    }
    
    receive() external payable {}
    
    function transfer(address payable to, uint256 amount) external nonReentrant {
        require(msg.sender == creator, "Not authorized");
        require(address(this).balance >= amount, "Insufficient balance");
        (bool success, ) = to.call{value: amount}("");
        require(success, "ETH transfer failed");
    }
}

/// @title UbountyCreator - Main contract for managing bounties
contract UbountyCreator is ReentrancyGuard, Pausable, AccessControl {
    // Constants
    string public constant VERSION = "ubounties-v0.9";
    uint256 public constant DISPUTE_WINDOW = 3 days;
    uint256 public constant ARBITRATION_WINDOW = 7 days;
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    
    // Core state variables
    IERC20 public immutable devcash;
    address public admin;
    address payable public collector;
    uint256 public fee;
    uint256 public waiver;
    uint256 public numUbounties;
    uint256 public minDeadlinePeriod = 1 hours;

    // Reward tier structure
    struct RewardTier {
        uint256 tokenAmount;
        uint256 weiAmount;
        uint8 available;
        string description;
    }

    // Evaluation structure
    struct Evaluation {
        bool hasEvaluated;
        bool approved;
        string feedback;
        uint256 timestamp;
    }

    // Dispute structure
    struct Dispute {
        uint256 timestamp;
        string reason;
        bool resolved;
        bool upheld;
        string resolution;
        mapping(address => bool) arbitratorVotes;
        uint8 numArbitratorsApproved;
        uint8 numArbitratorsRejected;
    }

    // Submission structure
    struct Submission {
        uint32 submitterIndex;
        string submissionString;
        bool finalApproved;
        uint8 numApprovals;
        uint8 numRejections;
        uint8 assignedTier;
        bool tierAssigned;
        mapping(address => Evaluation) evaluations;
        mapping(uint256 => string) revisions;
        uint8 numRevisions;
        uint256 submissionTime;
        bool hasDispute;
        Dispute dispute;
    }

    // Evaluator configuration
    struct EvaluatorConfig {
        uint8 requiredApprovals;
        uint8 numEvaluators;
        mapping(address => bool) isEvaluator;
        address[] evaluatorList;
    }

    // Arbitrator configuration
    struct ArbitratorConfig {
        uint8 requiredVotes;
        uint8 numArbitrators;
        mapping(address => bool) isArbitrator;
        address[] arbitratorList;
    }

    // Main bounty structure
    struct Ubounty {
        uint8 numSubmissions;
        uint32 hunterIndex;
        uint32 creatorIndex;
        uint32 bountyChestIndex;
        uint48 deadline;
        string name;
        string description;
        mapping(uint8 => RewardTier) rewardTiers;
        uint8 numTiers;
        mapping(uint256 => Submission) submissions;
        EvaluatorConfig evaluators;
        ArbitratorConfig arbitrators;
        bool exists;
    }

    // Mappings
    mapping(uint256 => Ubounty) public ubounties;
    mapping(address => uint32) public bountyChests;
    mapping(address => uint32) public users;
    
    // Arrays
    address payable[] public bCList;
    uint256[] public freeBC;
    address payable[] public userList;

    // Events
    event BountyCreated(uint256 indexed uBountyIndex, uint256[] bountiesAvailable, uint256[] tokenAmounts, uint256[] weiAmounts);
    event SubmissionReceived(uint256 indexed uBountyIndex, uint256 submissionIndex);
    event RevisionSubmitted(uint256 indexed uBountyIndex, uint256 submissionIndex, uint256 revisionIndex);
    event SubmissionApproved(uint256 indexed uBountyIndex, uint256 submissionIndex, string feedback);
    event SubmissionRejected(uint256 indexed uBountyIndex, uint256 submissionIndex, string feedback);
    event RevisionRequested(uint256 indexed uBountyIndex, uint256 submissionIndex, string feedback);
    event BountyRewarded(uint256 indexed uBountyIndex, uint256 submissionIndex, address hunter, uint256 tokenAmount, uint256 weiAmount);
    event BountyReclaimed(uint256 indexed uBountyIndex, uint256 tokenAmount, uint256 weiAmount);
    event BountyCompleted(uint256 indexed uBountyIndex);
    event FeeChange(uint256 oldFee, uint256 newFee);
    event WaiverChange(uint256 oldWaiver, uint256 newWaiver);
    event EvaluatorAdded(uint256 indexed uBountyIndex, address evaluator);
    event EvaluatorRemoved(uint256 indexed uBountyIndex, address evaluator);
    event ArbitratorAdded(uint256 indexed uBountyIndex, address arbitrator);
    event ArbitratorRemoved(uint256 indexed uBountyIndex, address arbitrator);
    event DisputeCreated(uint256 indexed uBountyIndex, uint256 submissionIndex, string reason);
    event DisputeResolved(uint256 indexed uBountyIndex, uint256 submissionIndex, bool upheld, string resolution);
    event RewardTierCreated(uint256 indexed uBountyIndex, uint8 tierId, uint256 tokenAmount, uint256 weiAmount, uint8 available, string description);
    event SubmissionTierAssigned(uint256 indexed uBountyIndex, uint256 submissionIndex, uint8 tierId);

    // Constructor
    constructor(address _devcash, address payable _collector) {
        devcash = IERC20(_devcash);
        collector = _collector;
        admin = msg.sender;
        
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
        
        userList.push(payable(address(0)));
        bCList.push(payable(address(0)));
    }

    // Modifiers
    modifier bountyExists(uint256 ubountyIndex) {
        require(ubounties[ubountyIndex].exists, "Bounty does not exist");
        _;
    }
    
    modifier onlyBountyCreator(uint256 ubountyIndex) {
        require(users[msg.sender] == ubounties[ubountyIndex].creatorIndex, "Not bounty creator");
        _;
    }

    // Core bounty creation functions
    function postOpenBountyWithTiers(
        string calldata name,
        string calldata description,
        RewardTier[] calldata tiers,
        uint48 deadline
    ) external payable whenNotPaused nonReentrant {
        require(tiers.length > 0 && tiers.length <= 5, "Invalid tier count");
        require(bytes(name).length > 0, "Name required");
        require(bytes(description).length > 0, "Description required");
        require(deadline == 0 || deadline > block.timestamp + minDeadlinePeriod, "Invalid deadline");
        
        uint256 totalTokenAmount;
        uint256 totalWeiAmount;
        
        // Calculate total rewards needed
        for (uint8 i = 0; i < tiers.length; i++) {
            totalTokenAmount += tiers[i].tokenAmount * tiers[i].available;
            totalWeiAmount += tiers[i].weiAmount * tiers[i].available;
        }
        
        require(msg.value >= totalWeiAmount + fee || satisfiesWaiver(msg.sender), "Insufficient ETH");

        // Process user and bounty chest
        addUser(msg.sender);
        address payable bCAddress = getBountyChest();
        
        // Set deadline or max value if not specified
        uint48 finalDeadline = deadline == 0 ? type(uint48).max : deadline;
        
        // Create bounty
        uint256 bountyIndex = numUbounties++;
        Ubounty storage bounty = ubounties[bountyIndex];
        bounty.name = name;
        bounty.description = description;
        bounty.creatorIndex = users[msg.sender];
        bounty.bountyChestIndex = bountyChests[bCAddress];
        bounty.deadline = finalDeadline;
        bounty.exists = true;
        
        // Set up reward tiers
        uint256[] memory bountiesAvailable = new uint256[](tiers.length);
        uint256[] memory tokenAmounts = new uint256[](tiers.length);
        uint256[] memory weiAmounts = new uint256[](tiers.length);
        
        for (uint8 i = 0; i < tiers.length; i++) {
            bounty.rewardTiers[i] = RewardTier({
                tokenAmount: tiers[i].tokenAmount,
                weiAmount: tiers[i].weiAmount,
                available: tiers[i].available,
                description: tiers[i].description
            });
            
            bountiesAvailable[i] = tiers[i].available;
            tokenAmounts[i] = tiers[i].tokenAmount;
            weiAmounts[i] = tiers[i].weiAmount;
            
            emit RewardTierCreated(
                bountyIndex,
                i,
                tiers[i].tokenAmount,
                tiers[i].weiAmount,
                tiers[i].available,
                tiers[i].description
            );
        }
        bounty.numTiers = uint8(tiers.length);

        // Handle payments
        uint256 _fee = getFee(msg.sender);
        if (_fee > 0) {
            (bool success, ) = collector.call{value: _fee}("");
            require(success, "Fee transfer failed");
        }

        if (totalTokenAmount > 0) {
            require(devcash.transferFrom(msg.sender, bCAddress, totalTokenAmount), "Token transfer failed");
        }

        if (totalWeiAmount > 0) {
            (bool success, ) = bCAddress.call{value: msg.value - _fee}("");
            require(success, "ETH transfer failed");
        }

        emit BountyCreated(bountyIndex, bountiesAvailable, tokenAmounts, weiAmounts);
    }

    function postPersonalBountyWithTiers(
        string calldata name,
        string calldata description,
        address payable hunter,
        RewardTier[] calldata tiers,
        uint48 deadline
    ) external payable whenNotPaused nonReentrant {
        require(hunter != address(0), "Invalid hunter");
        require(tiers.length > 0 && tiers.length <= 5, "Invalid tier count");
        require(bytes(name).length > 0, "Name required");
        require(bytes(description).length > 0, "Description required");
        require(deadline == 0 || deadline > block.timestamp + minDeadlinePeriod, "Invalid deadline");
        
        uint256 totalTokenAmount;
        uint256 totalWeiAmount;
        
        for (uint8 i = 0; i < tiers.length; i++) {
            totalTokenAmount += tiers[i].tokenAmount * tiers[i].available;
            totalWeiAmount += tiers[i].weiAmount * tiers[i].available;
        }
        
        require(msg.value >= totalWeiAmount + fee || satisfiesWaiver(msg.sender), "Insufficient ETH");

        addUser(msg.sender);
        addUser(hunter);
        address payable bCAddress = getBountyChest();
        
        uint48 finalDeadline = deadline == 0 ? type(uint48).max : deadline;
        
        uint256 bountyIndex = numUbounties++;
        Ubounty storage bounty = ubounties[bountyIndex];
        bounty.name = name;
        bounty.description = description;
        bounty.creatorIndex = users[msg.sender];
        bounty.hunterIndex = users[hunter];
        bounty.bountyChestIndex = bountyChests[bCAddress];
        bounty.deadline = finalDeadline;
        bounty.exists = true;
        
        uint256[] memory bountiesAvailable = new uint256[](tiers.length);
        uint256[] memory tokenAmounts = new uint256[](tiers.length);
        uint256[] memory weiAmounts = new uint256[](tiers.length);
        
        for (uint8 i = 0; i < tiers.length; i++) {
            bounty.rewardTiers[i] = RewardTier({
                tokenAmount: tiers[i].tokenAmount,
                weiAmount: tiers[i].weiAmount,
                available: tiers[i].available,
                description: tiers[i].description
            });
            
            bountiesAvailable[i] = tiers[i].available;
            tokenAmounts[i] = tiers[i].tokenAmount;
            weiAmounts[i] = tiers[i].weiAmount;
            
            emit RewardTierCreated(
                bountyIndex,
                i,
                tiers[i].tokenAmount,
                tiers[i].weiAmount,
                tiers[i].available,
                tiers[i].description
            );
        }
        bounty.numTiers = uint8(tiers.length);

        uint256 _fee = getFee(msg.sender);
        if (_fee > 0) {
            (bool success, ) = collector.call{value: _fee}("");
            require(success, "Fee transfer failed");
        }

        if (totalTokenAmount > 0) {
            require(devcash.transferFrom(msg.sender, bCAddress, totalTokenAmount), "Token transfer failed");
        }

        if (totalWeiAmount > 0) {
            (bool success, ) = bCAddress.call{value: msg.value - _fee}("");
            require(success, "ETH transfer failed");
        }

        emit BountyCreated(bountyIndex, bountiesAvailable, tokenAmounts, weiAmounts);
    }

    function contribute(
        uint256 ubountyIndex,
        uint8 tierId,
        uint256 tokenAmount
    ) external whenNotPaused nonReentrant bountyExists(ubountyIndex) {
        Ubounty storage bounty = ubounties[ubountyIndex];
        require(tierId < bounty.numTiers, "Invalid tier");
        require(tokenAmount > 0, "Amount must be positive");
        
        address bountyChest = bCList[bounty.bountyChestIndex];
        require(devcash.transferFrom(msg.sender, bountyChest, tokenAmount), "Token transfer failed");
        
        emit BountyContributed(ubountyIndex, msg.sender, tierId, tokenAmount, 0);
    }

    function contributeEth(
        uint256 ubountyIndex,
        uint8 tierId
    ) external payable whenNotPaused nonReentrant bountyExists(ubountyIndex) {
        Ubounty storage bounty = ubounties[ubountyIndex];
        require(tierId < bounty.numTiers, "Invalid tier");
        require(msg.value > 0, "Amount must be positive");
        
        address payable bountyChest = bCList[bounty.bountyChestIndex];
        (bool success, ) = bountyChest.call{value: msg.value}("");
        require(success, "ETH transfer failed");
        
        emit BountyContributed(ubountyIndex, msg.sender, tierId, 0, msg.value);
    }

    // Helper function to get a bounty chest
    function getBountyChest() private returns (address payable bCAddress) {
        if (freeBC.length > 0) {
            uint256 index = freeBC[freeBC.length - 1];
            bCAddress = bCList[index];
            freeBC.pop();
        } else {
            BountyChest newChest = new BountyChest(address(devcash));
            bCAddress = payable(address(newChest));
            bountyChests[bCAddress] = uint32(bCList.length);
            bCList.push(bCAddress);
        }
        return bCAddress;
    }

    // Event for contributions
    event BountyContributed(uint256 indexed ubountyIndex, address indexed contributor, uint8 tierId, uint256 tokenAmount, uint256 weiAmount);

    // Submission and Evaluation System
    function submit(
        uint256 ubountyIndex,
        string calldata submissionString
    ) external whenNotPaused nonReentrant bountyExists(ubountyIndex) {
        Ubounty storage bounty = ubounties[ubountyIndex];
        
        require(bytes(submissionString).length > 0, "Empty submission");
        require(block.timestamp <= bounty.deadline, "Deadline passed");
        require(
            bounty.hunterIndex == 0 || msg.sender == userList[bounty.hunterIndex],
            "Not authorized hunter"
        );
        require(bounty.evaluators.numEvaluators > 0, "No evaluators set");
        
        // Check if any tier slots are available
        bool hasAvailableSlots = false;
        for (uint8 i = 0; i < bounty.numTiers; i++) {
            if (bounty.rewardTiers[i].available > 0) {
                hasAvailableSlots = true;
                break;
            }
        }
        require(hasAvailableSlots, "No reward slots available");

        addUser(msg.sender);
        
        uint8 submissionIndex = bounty.numSubmissions;
        require(submissionIndex < 255, "Max submissions reached");

        Submission storage newSubmission = bounty.submissions[submissionIndex];
        newSubmission.submissionString = submissionString;
        newSubmission.submitterIndex = users[msg.sender];
        newSubmission.submissionTime = block.timestamp;
        newSubmission.finalApproved = false;
        newSubmission.numApprovals = 0;
        newSubmission.numRejections = 0;
        newSubmission.tierAssigned = false;

        bounty.numSubmissions++;

        emit SubmissionReceived(ubountyIndex, submissionIndex);
    }

    function revise(
        uint256 ubountyIndex,
        uint256 submissionIndex,
        string calldata revisionString
    ) external whenNotPaused nonReentrant bountyExists(ubountyIndex) {
        Ubounty storage bounty = ubounties[ubountyIndex];
        require(submissionIndex < bounty.numSubmissions, "Invalid submission");

        Submission storage submission = bounty.submissions[submissionIndex];
        require(!submission.finalApproved, "Already approved");
        require(msg.sender == userList[submission.submitterIndex], "Not submission owner");
        require(submission.numRevisions < 255, "Max revisions reached");
        require(bytes(revisionString).length > 0, "Empty revision");

        uint8 revisionIndex = submission.numRevisions;
        submission.revisions[revisionIndex] = revisionString;
        submission.numRevisions++;

        emit RevisionSubmitted(ubountyIndex, submissionIndex, revisionIndex);
    }

    function evaluate(
        uint256 ubountyIndex,
        uint256 submissionIndex,
        bool approved,
        uint8 tierId,
        string calldata feedback
    ) external whenNotPaused nonReentrant bountyExists(ubountyIndex) {
        Ubounty storage bounty = ubounties[ubountyIndex];
        require(bounty.evaluators.isEvaluator[msg.sender], "Not an evaluator");
        require(submissionIndex < bounty.numSubmissions, "Invalid submission");
        
        Submission storage submission = bounty.submissions[submissionIndex];
        require(!submission.finalApproved, "Already approved");
        require(!submission.evaluations[msg.sender].hasEvaluated, "Already evaluated");
        
        if (approved) {
            require(tierId < bounty.numTiers, "Invalid tier");
            require(bounty.rewardTiers[tierId].available > 0, "Tier full");
        }
        
        // Record evaluation
        submission.evaluations[msg.sender] = Evaluation({
            hasEvaluated: true,
            approved: approved,
            feedback: feedback,
            timestamp: block.timestamp
        });
        
        if (approved) {
            submission.numApprovals++;
            if (submission.numApprovals >= bounty.evaluators.requiredApprovals) {
                _finalizeApproval(ubountyIndex, submissionIndex, tierId);
            }
        } else {
            submission.numRejections++;
            emit SubmissionRejected(ubountyIndex, submissionIndex, feedback);
        }
    }

    function _finalizeApproval(
        uint256 ubountyIndex,
        uint256 submissionIndex,
        uint8 tierId
    ) private {
        Ubounty storage bounty = ubounties[ubountyIndex];
        Submission storage submission = bounty.submissions[submissionIndex];
        
        submission.finalApproved = true;
        submission.assignedTier = tierId;
        submission.tierAssigned = true;
        bounty.rewardTiers[tierId].available--;
        
        // Process reward
        address payable hunter = userList[submission.submitterIndex];
        _processRewardTier(ubountyIndex, submissionIndex, hunter, tierId);
        
        emit SubmissionTierAssigned(ubountyIndex, submissionIndex, tierId);
        emit SubmissionApproved(ubountyIndex, submissionIndex, "Approved by required evaluators");
    }

    function _processRewardTier(
        uint256 ubountyIndex,
        uint256 submissionIndex,
        address payable hunter,
        uint8 tierId
    ) private {
        Ubounty storage bounty = ubounties[ubountyIndex];
        RewardTier storage tier = bounty.rewardTiers[tierId];
        
        // Process token reward
        if (tier.tokenAmount > 0) {
            address bountyChest = bCList[bounty.bountyChestIndex];
            require(
                devcash.transferFrom(bountyChest, hunter, tier.tokenAmount),
                "Token reward failed"
            );
        }

        // Process ETH reward
        if (tier.weiAmount > 0) {
            BountyChest(bCList[bounty.bountyChestIndex]).transfer(hunter, tier.weiAmount);
        }

        emit BountyRewarded(ubountyIndex, submissionIndex, hunter, tier.tokenAmount, tier.weiAmount);

        // Check if all tiers are exhausted
        bool allTiersExhausted = true;
        for (uint8 i = 0; i < bounty.numTiers; i++) {
            if (bounty.rewardTiers[i].available > 0) {
                allTiersExhausted = false;
                break;
            }
        }

        if (allTiersExhausted) {
            freeBC.push(bounty.bountyChestIndex);
            emit BountyCompleted(ubountyIndex);
        }
    }

    // Dispute Resolution System
    function createDispute(
        uint256 ubountyIndex,
        uint256 submissionIndex,
        string calldata reason
    ) external whenNotPaused nonReentrant bountyExists(ubountyIndex) {
        Ubounty storage bounty = ubounties[ubountyIndex];
        require(submissionIndex < bounty.numSubmissions, "Invalid submission");
        
        Submission storage submission = bounty.submissions[submissionIndex];
        require(msg.sender == userList[submission.submitterIndex], "Not submission owner");
        require(!submission.finalApproved, "Already approved");
        require(!submission.hasDispute, "Dispute exists");
        require(
            submission.numRejections > 0 && 
            block.timestamp <= submission.submissionTime + DISPUTE_WINDOW,
            "Cannot dispute"
        );
        require(bounty.arbitrators.numArbitrators >= 3, "Insufficient arbitrators");

        submission.hasDispute = true;
        submission.dispute.timestamp = block.timestamp;
        submission.dispute.reason = reason;
        
        emit DisputeCreated(ubountyIndex, submissionIndex, reason);
    }

    function voteOnDispute(
        uint256 ubountyIndex,
        uint256 submissionIndex,
        bool upholdDispute,
        uint8 proposedTier,
        string calldata resolution
    ) external whenNotPaused nonReentrant bountyExists(ubountyIndex) {
        Ubounty storage bounty = ubounties[ubountyIndex];
        require(bounty.arbitrators.isArbitrator[msg.sender], "Not arbitrator");
        
        Submission storage submission = bounty.submissions[submissionIndex];
        require(submission.hasDispute, "No dispute exists");
        require(!submission.dispute.resolved, "Already resolved");
        require(!submission.dispute.arbitratorVotes[msg.sender], "Already voted");
        require(
            block.timestamp <= submission.dispute.timestamp + ARBITRATION_WINDOW,
            "Arbitration window closed"
        );

        if (upholdDispute) {
            require(proposedTier < bounty.numTiers, "Invalid tier");
            require(bounty.rewardTiers[proposedTier].available > 0, "Tier full");
        }

        Dispute storage dispute = submission.dispute;
        dispute.arbitratorVotes[msg.sender] = true;

        if (upholdDispute) {
            dispute.numArbitratorsApproved++;
            if (dispute.numArbitratorsApproved >= bounty.arbitrators.requiredVotes) {
                _resolveDispute(ubountyIndex, submissionIndex, true, proposedTier, resolution);
            }
        } else {
            dispute.numArbitratorsRejected++;
            if (dispute.numArbitratorsRejected > 
                bounty.arbitrators.numArbitrators - bounty.arbitrators.requiredVotes) {
                _resolveDispute(ubountyIndex, submissionIndex, false, 0, resolution);
            }
        }

        emit ArbitratorVoted(ubountyIndex, submissionIndex, msg.sender, upholdDispute);
    }

    function _resolveDispute(
        uint256 ubountyIndex,
        uint256 submissionIndex,
        bool upheld,
        uint8 proposedTier,
        string memory resolution
    ) private {
        Submission storage submission = ubounties[ubountyIndex].submissions[submissionIndex];
        submission.dispute.resolved = true;
        submission.dispute.upheld = upheld;
        submission.dispute.resolution = resolution;

        // If dispute is upheld, approve the submission with proposed tier
        if (upheld) {
            _finalizeApproval(ubountyIndex, submissionIndex, proposedTier);
        }

        emit DisputeResolved(ubountyIndex, submissionIndex, upheld, resolution);
    }

    // Reclaim functionality
    function reclaim(uint256 ubountyIndex) external whenNotPaused nonReentrant bountyExists(ubountyIndex) {
        Ubounty storage bounty = ubounties[ubountyIndex];
        require(users[msg.sender] == bounty.creatorIndex, "Not bounty creator");
        require(bounty.deadline != type(uint48).max, "Permanent bounty");
        require(block.timestamp > bounty.deadline, "Deadline not reached");
        
        // Calculate refund amounts for each tier
        uint256 totalTokenAmount;
        uint256 totalWeiAmount;
        
        for (uint8 i = 0; i < bounty.numTiers; i++) {
            RewardTier storage tier = bounty.rewardTiers[i];
            totalTokenAmount += tier.tokenAmount * tier.available;
            totalWeiAmount += tier.weiAmount * tier.available;
            tier.available = 0;  // Clear available slots
        }
        
        // Process refunds
        if (totalTokenAmount > 0) {
            address bountyChest = bCList[bounty.bountyChestIndex];
            require(
                devcash.transferFrom(bountyChest, msg.sender, totalTokenAmount),
                "Token reclaim failed"
            );
        }
        
        if (totalWeiAmount > 0) {
            BountyChest(bCList[bounty.bountyChestIndex]).transfer(msg.sender, totalWeiAmount);
        }
        
        // Free up the bounty chest
        freeBC.push(bounty.bountyChestIndex);
        
        // Reject all pending submissions
        for (uint256 i = 0; i < bounty.numSubmissions && i < 255; i++) {
            Submission storage submission = bounty.submissions[i];
            if (!submission.finalApproved && !submission.hasDispute) {
                emit SubmissionRejected(ubountyIndex, i, "Bounty reclaimed by creator");
            }
        }
        
        emit BountyReclaimed(ubountyIndex, totalTokenAmount, totalWeiAmount);
        emit BountyCompleted(ubountyIndex);
    }

    // User management
    function addUser(address payable user) private {
        if (users[user] == 0) {
            users[user] = uint32(userList.length);
            userList.push(user);
        }
    }

    // View Functions
    function getSubmission(
        uint256 ubountyIndex,
        uint256 submissionIndex
    ) external view bountyExists(ubountyIndex) returns (
        string memory submissionString,
        address submitter,
        bool finalApproved,
        uint8 numApprovals,
        uint8 numRejections,
        uint8 assignedTier,
        bool tierAssigned,
        uint256 submissionTime,
        uint8 numRevisions
    ) {
        Submission storage submission = ubounties[ubountyIndex].submissions[submissionIndex];
        return (
            submission.submissionString,
            userList[submission.submitterIndex],
            submission.finalApproved,
            submission.numApprovals,
            submission.numRejections,
            submission.assignedTier,
            submission.tierAssigned,
            submission.submissionTime,
            submission.numRevisions
        );
    }

    function getRevision(
        uint256 ubountyIndex,
        uint256 submissionIndex,
        uint256 revisionIndex
    ) external view bountyExists(ubountyIndex) returns (string memory) {
        return ubounties[ubountyIndex].submissions[submissionIndex].revisions[revisionIndex];
    }

    function getBountyDetails(
        uint256 ubountyIndex
    ) external view bountyExists(ubountyIndex) returns (
        string memory name,
        string memory description,
        address creator,
        address hunter,
        uint48 deadline,
        uint8 numTiers,
        uint8 numSubmissions
    ) {
        Ubounty storage bounty = ubounties[ubountyIndex];
        return (
            bounty.name,
            bounty.description,
            userList[bounty.creatorIndex],
            bounty.hunterIndex == 0 ? address(0) : userList[bounty.hunterIndex],
            bounty.deadline,
            bounty.numTiers,
            bounty.numSubmissions
        );
    }

    function getTierDetails(
        uint256 ubountyIndex,
        uint8 tierId
    ) external view bountyExists(ubountyIndex) returns (
        uint256 tokenAmount,
        uint256 weiAmount,
        uint8 available,
        string memory description
    ) {
        RewardTier storage tier = ubounties[ubountyIndex].rewardTiers[tierId];
        return (
            tier.tokenAmount,
            tier.weiAmount,
            tier.available,
            tier.description
        );
    }

    function getEvaluationStatus(
        uint256 ubountyIndex,
        uint256 submissionIndex,
        address evaluator
    ) external view bountyExists(ubountyIndex) returns (
        bool hasEvaluated,
        bool approved,
        string memory feedback,
        uint256 timestamp
    ) {
        Evaluation storage eval = ubounties[ubountyIndex].submissions[submissionIndex].evaluations[evaluator];
        return (
            eval.hasEvaluated,
            eval.approved,
            eval.feedback,
            eval.timestamp
        );
    }

    function getDisputeDetails(
        uint256 ubountyIndex,
        uint256 submissionIndex
    ) external view bountyExists(ubountyIndex) returns (
        bool exists,
        bool resolved,
        bool upheld,
        string memory reason,
        string memory resolution,
        uint256 timestamp,
        uint8 approvingVotes,
        uint8 rejectingVotes
    ) {
        Submission storage submission = ubounties[ubountyIndex].submissions[submissionIndex];
        Dispute storage dispute = submission.dispute;
        return (
            submission.hasDispute,
            dispute.resolved,
            dispute.upheld,
            dispute.reason,
            dispute.resolution,
            dispute.timestamp,
            dispute.numArbitratorsApproved,
            dispute.numArbitratorsRejected
        );
    }

    // Administrative Functions
    function setMinDeadlinePeriod(uint256 newPeriod) external {
        require(msg.sender == admin, "Not admin");
        minDeadlinePeriod = newPeriod;
    }

    function setFee(uint256 newFee) external {
        require(msg.sender == admin, "Not admin");
        emit FeeChange(fee, newFee);
        fee = newFee;
    }

    function setWaiver(uint256 newWaiver) external {
        require(msg.sender == admin, "Not admin");
        emit WaiverChange(waiver, newWaiver);
        waiver = newWaiver;
    }

    function setCollector(address payable newCollector) external {
        require(msg.sender == admin, "Not admin");
        require(newCollector != address(0), "Invalid collector");
        collector = newCollector;
    }

    function setAdmin(address newAdmin) external {
        require(msg.sender == admin, "Not admin");
        require(newAdmin != address(0), "Invalid admin");
        admin = newAdmin;
    }

    function emergencyPause() external {
        require(msg.sender == admin, "Not admin");
        _pause();
    }

    function emergencyUnpause() external {
        require(msg.sender == admin, "Not admin");
        _unpause();
    }

    // Helper Functions
    function numBC() public view returns(uint256) {
        return bCList.length;
    }

    function numUsers() public view returns(uint256) {
        return userList.length;
    }

    function getFee(address poster) public view returns(uint256) {
        return satisfiesWaiver(poster) ? 0 : fee;
    }

    function satisfiesWaiver(address poster) public view returns(bool) {
        return devcash.balanceOf(poster) >= waiver;
    }

    function isReclaimable(uint256 ubountyIndex) public view bountyExists(ubountyIndex) returns(bool) {
        return ubounties[ubountyIndex].deadline != type(uint48).max;
    }

    function isReclaimableNow(uint256 ubountyIndex) public view bountyExists(ubountyIndex) returns(bool) {
        Ubounty storage bounty = ubounties[ubountyIndex];
        return bounty.deadline != type(uint48).max && block.timestamp > bounty.deadline;
    }
    
    // The End
}
