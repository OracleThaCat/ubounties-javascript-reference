// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

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

contract UbountyCreator is ReentrancyGuard, Pausable, AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    
    string public constant VERSION = "ubounties-v0.9";
    
    IERC20 public immutable devcash;
    address payable public immutable collector;
    
    // Fee configuration
    uint256 public fee;
    uint256 public waiver;
    uint256 public minDeadlinePeriod = 1 hours;
    
    // Multi-evaluator structures
    struct Evaluation {
        bool hasEvaluated;
        bool approved;
        string feedback;
    }
    
    struct EvaluatorConfig {
        uint8 requiredApprovals;
        uint8 numEvaluators;
        mapping(address => bool) isEvaluator;
        address[] evaluatorList;
    }

    struct Submission {
        uint32 submitterIndex;
        string submissionString;
        bool finalApproved;
        uint8 numApprovals;
        uint8 numRejections;
        mapping(address => Evaluation) evaluations;
        mapping(uint256 => string) revisions;
        uint8 numRevisions;
    }
    
    struct Ubounty {
        uint8 available;
        uint8 numSubmissions;
        uint32 hunterIndex;
        uint32 creatorIndex;
        uint32 bountyChestIndex;
        uint48 deadline;
        string name;
        string description;
        mapping(uint256 => Submission) submissions;
        EvaluatorConfig evaluators;
        bool exists;
    }
    
    // Events for evaluation system
    event EvaluatorAdded(uint256 indexed ubountyIndex, address evaluator);
    event EvaluatorRemoved(uint256 indexed ubountyIndex, address evaluator);
    event RequiredApprovalsChanged(uint256 indexed ubountyIndex, uint8 newRequired);
    event SubmissionEvaluated(uint256 indexed ubountyIndex, uint256 submissionIndex, address evaluator, bool approved, string feedback);
    
    // Evaluator management functions
    function addEvaluator(
        uint256 ubountyIndex, 
        address evaluator
    ) external whenNotPaused bountyExists(ubountyIndex) onlyBountyCreator(ubountyIndex) {
        require(evaluator != address(0), "Invalid evaluator address");
        EvaluatorConfig storage config = ubounties[ubountyIndex].evaluators;
        require(!config.isEvaluator[evaluator], "Already an evaluator");
        require(config.numEvaluators < 255, "Max evaluators reached");
        
        config.isEvaluator[evaluator] = true;
        config.evaluatorList.push(evaluator);
        config.numEvaluators++;
        
        // If this is the first evaluator, set required approvals to 1
        if (config.requiredApprovals == 0) {
            config.requiredApprovals = 1;
        }
        
        emit EvaluatorAdded(ubountyIndex, evaluator);
    }
    
    function removeEvaluator(
        uint256 ubountyIndex, 
        address evaluator
    ) external whenNotPaused bountyExists(ubountyIndex) onlyBountyCreator(ubountyIndex) {
        EvaluatorConfig storage config = ubounties[ubountyIndex].evaluators;
        require(config.isEvaluator[evaluator], "Not an evaluator");
        require(config.numEvaluators > config.requiredApprovals, "Cannot have fewer evaluators than required approvals");
        
        config.isEvaluator[evaluator] = false;
        config.numEvaluators--;
        
        // Remove from list
        for (uint i = 0; i < config.evaluatorList.length; i++) {
            if (config.evaluatorList[i] == evaluator) {
                config.evaluatorList[i] = config.evaluatorList[config.evaluatorList.length - 1];
                config.evaluatorList.pop();
                break;
            }
        }
        
        emit EvaluatorRemoved(ubountyIndex, evaluator);
    }
    
    function setRequiredApprovals(
        uint256 ubountyIndex, 
        uint8 required
    ) external whenNotPaused bountyExists(ubountyIndex) onlyBountyCreator(ubountyIndex) {
        EvaluatorConfig storage config = ubounties[ubountyIndex].evaluators;
        require(required > 0, "Must require at least one approval");
        require(required <= config.numEvaluators, "Cannot require more approvals than evaluators");
        
        config.requiredApprovals = required;
        emit RequiredApprovalsChanged(ubountyIndex, required);
    }
    
    // Modified evaluation function
    function evaluate(
        uint256 ubountyIndex,
        uint256 submissionIndex,
        bool approved,
        string calldata feedback
    ) external whenNotPaused nonReentrant bountyExists(ubountyIndex) bountyActive(ubountyIndex) {
        Ubounty storage bounty = ubounties[ubountyIndex];
        require(bounty.evaluators.isEvaluator[msg.sender], "Not an evaluator");
        require(submissionIndex < bounty.numSubmissions, "Invalid submission");
        
        Submission storage submission = bounty.submissions[submissionIndex];
        require(!submission.finalApproved, "Already approved");
        require(!submission.evaluations[msg.sender].hasEvaluated, "Already evaluated");
        
        // Record evaluation
        submission.evaluations[msg.sender] = Evaluation({
            hasEvaluated: true,
            approved: approved,
            feedback: feedback
        });
        
        if (approved) {
            submission.numApprovals++;
            // Check if we've reached required approvals
            if (submission.numApprovals >= bounty.evaluators.requiredApprovals) {
                submission.finalApproved = true;
                // Process reward
                _processReward(ubountyIndex, submissionIndex, userList[submission.submitterIndex]);
            }
        } else {
            submission.numRejections++;
        }
        
        emit SubmissionEvaluated(ubountyIndex, submissionIndex, msg.sender, approved, feedback);
    }
    
    // View functions for evaluation status
    function getEvaluationStatus(
        uint256 ubountyIndex,
        uint256 submissionIndex
    ) external view returns (
        uint8 numApprovals,
        uint8 numRejections,
        uint8 requiredApprovals,
        bool finalApproved
    ) {
        Submission storage submission = ubounties[ubountyIndex].submissions[submissionIndex];
        return (
            submission.numApprovals,
            submission.numRejections,
            ubounties[ubountyIndex].evaluators.requiredApprovals,
            submission.finalApproved
        );
    }
    
    function getEvaluatorFeedback(
        uint256 ubountyIndex,
        uint256 submissionIndex,
        address evaluator
    ) external view returns (
        bool hasEvaluated,
        bool approved,
        string memory feedback
    ) {
        Evaluation storage eval = ubounties[ubountyIndex].submissions[submissionIndex].evaluations[evaluator];
        return (eval.hasEvaluated, eval.approved, eval.feedback);
    }
    
    function getEvaluators(
        uint256 ubountyIndex
    ) external view returns (address[] memory) {
        return ubounties[ubountyIndex].evaluators.evaluatorList;
    }
    
    mapping(uint256 => Ubounty) public ubounties;
    uint256 public numUbounties;
    
    // Bounty chest management
    mapping(address => uint32) public bountyChests;
    address payable[] public bCList;
    uint256[] public freeBC;
    
    // User management
    mapping(address => uint32) public users;
    address payable[] public userList;
    
    // Events
    event BountyCreated(uint256 indexed uBountyIndex, uint256 bountiesAvailable, uint256 tokenAmount, uint256 weiAmount);
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
    
    constructor(address _devcash, address payable _collector) {
        devcash = IERC20(_devcash);
        collector = _collector;
        
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
        
        // Initialize with zero address entries
        userList.push(payable(address(0)));
        bCList.push(payable(address(0)));
    }
    
    modifier bountyExists(uint256 ubountyIndex) {
        require(ubounties[ubountyIndex].exists, "Bounty does not exist");
        _;
    }
    
    modifier onlyBountyCreator(uint256 ubountyIndex) {
        require(users[msg.sender] == ubounties[ubountyIndex].creatorIndex, "Not bounty creator");
        _;
    }
    
    modifier bountyActive(uint256 ubountyIndex) {
        require(ubounties[ubountyIndex].available > 0, "Bounty inactive");
        _;
    }

    // Bounty Creation Functions
    function postOpenBounty(
        string memory name,
        string memory description,
        uint8 available,
        uint256 tokenAmount,
        uint48 deadline
    ) external payable whenNotPaused nonReentrant {
        require(available > 0, "Must have at least one slot");
        require(bytes(name).length > 0, "Name required");
        require(bytes(description).length > 0, "Description required");
        require(msg.value >= fee || satisfiesWaiver(msg.sender), "Fee required");
        require(deadline == 0 || deadline > block.timestamp + minDeadlinePeriod, "Invalid deadline");

        uint256 _fee = getFee(msg.sender);
        uint256 weiAmount = msg.value - _fee;

        // Process user and bounty chest
        addUser(msg.sender);
        address payable bCAddress = getBountyChest();
        
        // Set deadline or max value if not specified
        uint48 finalDeadline = deadline == 0 ? type(uint48).max : deadline;

        // Create bounty
        setUbounty(
            users[msg.sender],
            0,  // No specific hunter for open bounty
            available,
            name,
            description,
            bountyChests[bCAddress],
            finalDeadline
        );

        // Handle payments
        if (_fee > 0) {
            (bool success, ) = collector.call{value: _fee}("");
            require(success, "Fee transfer failed");
        }

        if (tokenAmount > 0) {
            require(devcash.transferFrom(msg.sender, bCAddress, tokenAmount), "Token transfer failed");
        }

        if (weiAmount > 0) {
            (bool success, ) = bCAddress.call{value: weiAmount}("");
            require(success, "ETH transfer failed");
        }

        emit BountyCreated(numUbounties++, available, tokenAmount, weiAmount);
    }

    function postPersonalBounty(
        string memory name,
        string memory description,
        address payable hunter,
        uint8 available,
        uint256 tokenAmount,
        uint48 deadline
    ) external payable whenNotPaused nonReentrant {
        require(hunter != address(0), "Invalid hunter address");
        require(available > 0, "Must have at least one slot");
        require(bytes(name).length > 0, "Name required");
        require(bytes(description).length > 0, "Description required");
        require(msg.value >= fee || satisfiesWaiver(msg.sender), "Fee required");
        require(deadline == 0 || deadline > block.timestamp + minDeadlinePeriod, "Invalid deadline");

        uint256 _fee = getFee(msg.sender);
        uint256 weiAmount = msg.value - _fee;

        // Process users
        addUser(msg.sender);
        addUser(hunter);
        
        // Get bounty chest
        address payable bCAddress = getBountyChest();
        
        // Set deadline or max value if not specified
        uint48 finalDeadline = deadline == 0 ? type(uint48).max : deadline;

        // Create bounty
        setUbounty(
            users[msg.sender],
            users[hunter],
            available,
            name,
            description,
            bountyChests[bCAddress],
            finalDeadline
        );

        // Handle payments
        if (_fee > 0) {
            (bool success, ) = collector.call{value: _fee}("");
            require(success, "Fee transfer failed");
        }

        if (tokenAmount > 0) {
            require(devcash.transferFrom(msg.sender, bCAddress, tokenAmount), "Token transfer failed");
        }

        if (weiAmount > 0) {
            (bool success, ) = bCAddress.call{value: weiAmount}("");
            require(success, "ETH transfer failed");
        }

        emit BountyCreated(numUbounties++, available, tokenAmount, weiAmount);
    }

    // Submission System Functions
    function submit(
        uint256 ubountyIndex,
        string calldata submissionString
    ) external whenNotPaused nonReentrant bountyExists(ubountyIndex) bountyActive(ubountyIndex) {
        Ubounty storage bounty = ubounties[ubountyIndex];
        
        // Validate submission
        require(bytes(submissionString).length > 0, "Empty submission");
        require(block.timestamp <= bounty.deadline, "Deadline passed");
        require(
            bounty.hunterIndex == 0 || msg.sender == userList[bounty.hunterIndex],
            "Not authorized hunter"
        );

        // Register new user if needed
        addUser(payable(msg.sender));

        // Create submission
        uint8 submissionIndex = bounty.numSubmissions;
        require(submissionIndex < 255, "Max submissions reached"); // Prevent overflow

        Submission storage newSubmission = bounty.submissions[submissionIndex];
        newSubmission.submissionString = submissionString;
        newSubmission.submitterIndex = users[msg.sender];
        newSubmission.approved = false;
        newSubmission.numRevisions = 0;

        bounty.numSubmissions++;

        emit SubmissionReceived(ubountyIndex, submissionIndex);
    }

    function revise(
        uint256 ubountyIndex,
        uint256 submissionIndex,
        string calldata revisionString
    ) external whenNotPaused nonReentrant bountyExists(ubountyIndex) bountyActive(ubountyIndex) {
        Ubounty storage bounty = ubounties[ubountyIndex];
        require(submissionIndex < bounty.numSubmissions, "Invalid submission");

        Submission storage submission = bounty.submissions[submissionIndex];
        require(!submission.approved, "Already approved");
        require(
            msg.sender == userList[submission.submitterIndex],
            "Not submission owner"
        );
        require(submission.numRevisions < 255, "Max revisions reached"); // Prevent overflow
        require(bytes(revisionString).length > 0, "Empty revision");

        uint8 revisionIndex = submission.numRevisions;
        submission.revisions[revisionIndex] = revisionString;
        submission.numRevisions++;

        emit RevisionSubmitted(ubountyIndex, submissionIndex, revisionIndex);
    }

    // Helper Functions
    function setUbounty(
        uint32 creatorIndex,
        uint32 hunterIndex,
        uint8 available,
        string memory name,
        string memory description,
        uint32 bountyChestIndex,
        uint48 deadline
    ) private {
        Ubounty storage bounty = ubounties[numUbounties];
        bounty.creatorIndex = creatorIndex;
        bounty.hunterIndex = hunterIndex;
        bounty.available = available;
        bounty.name = name;
        bounty.description = description;
        bounty.bountyChestIndex = bountyChestIndex;
        bounty.deadline = deadline;
        bounty.exists = true;
    }

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

    function addUser(address payable user) private {
        if (users[user] == 0) {
            users[user] = uint32(userList.length);
            userList.push(user);
        }
    }

    // Admin Functions
    function setFee(uint256 newFee) external onlyRole(ADMIN_ROLE) {
        emit FeeChange(fee, newFee);
        fee = newFee;
    }

    function setWaiver(uint256 newWaiver) external onlyRole(ADMIN_ROLE) {
        emit WaiverChange(waiver, newWaiver);
        waiver = newWaiver;
    }

    function setMinDeadlinePeriod(uint256 newPeriod) external onlyRole(ADMIN_ROLE) {
        minDeadlinePeriod = newPeriod;
    }

    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    // Reward Distribution Functions
    function approve(
        uint256 ubountyIndex,
        uint256 submissionIndex,
        string calldata feedback
    ) external whenNotPaused nonReentrant bountyExists(ubountyIndex) bountyActive(ubountyIndex) onlyBountyCreator(ubountyIndex) {
        Ubounty storage bounty = ubounties[ubountyIndex];
        require(submissionIndex < bounty.numSubmissions, "Invalid submission");

        Submission storage submission = bounty.submissions[submissionIndex];
        require(!submission.approved, "Already approved");
        
        // Get hunter address and process reward
        address payable hunter = userList[submission.submitterIndex];
        
        // Mark as approved before external calls
        submission.approved = true;
        
        // Process reward
        _processReward(ubountyIndex, submissionIndex, hunter);

        emit SubmissionApproved(ubountyIndex, submissionIndex, feedback);
    }

    function awardOpenBounty(
        uint256 ubountyIndex,
        address payable hunter
    ) external whenNotPaused nonReentrant bountyExists(ubountyIndex) bountyActive(ubountyIndex) onlyBountyCreator(ubountyIndex) {
        Ubounty storage bounty = ubounties[ubountyIndex];
        require(bounty.hunterIndex == 0, "Not an open bounty");
        require(hunter != address(0), "Invalid hunter address");

        // Process reward directly without submission
        _processReward(ubountyIndex, 0, hunter);

        emit BountyRewarded(ubountyIndex, 0, hunter, getTokenReward(ubountyIndex), getWeiReward(ubountyIndex));
    }

    function awardPersonalBountyDirect(
        string calldata name,
        string calldata description,
        address payable hunter,
        uint256 tokenAmount
    ) external payable whenNotPaused nonReentrant {
        require(hunter != address(0), "Invalid hunter address");
        require(bytes(name).length > 0, "Name required");
        require(bytes(description).length > 0, "Description required");
        require(msg.value >= fee || satisfiesWaiver(msg.sender), "Fee required");

        uint256 _fee = getFee(msg.sender);
        uint256 weiAmount = msg.value - _fee;

        // Process users
        addUser(msg.sender);
        addUser(hunter);

        // Create bounty record with 0 available slots (completed)
        setUbounty(
            users[msg.sender],
            users[hunter],
            0,  // No available slots as it's directly awarded
            name,
            description,
            0,  // No bounty chest needed
            0   // No deadline needed
        );

        // Handle payments
        if (_fee > 0) {
            (bool success, ) = collector.call{value: _fee}("");
            require(success, "Fee transfer failed");
        }

        if (tokenAmount > 0) {
            require(devcash.transferFrom(msg.sender, hunter, tokenAmount), "Token transfer failed");
        }

        if (weiAmount > 0) {
            (bool success, ) = hunter.call{value: weiAmount}("");
            require(success, "ETH transfer failed");
        }

        emit BountyRewarded(numUbounties, 0, hunter, tokenAmount, weiAmount);
        emit BountyCompleted(numUbounties++);
    }

    function contribute(
        uint256 ubountyIndex,
        uint256 tokenAmount
    ) external whenNotPaused nonReentrant bountyExists(ubountyIndex) bountyActive(ubountyIndex) {
        require(tokenAmount > 0, "Amount must be positive");
        address bountyChest = bCList[ubounties[ubountyIndex].bountyChestIndex];
        require(devcash.transferFrom(msg.sender, bountyChest, tokenAmount), "Token transfer failed");
        
        emit BountyContributed(ubountyIndex, msg.sender, tokenAmount, 0);
    }

    function contributeEth(
        uint256 ubountyIndex
    ) external payable whenNotPaused nonReentrant bountyExists(ubountyIndex) bountyActive(ubountyIndex) {
        require(msg.value > 0, "Amount must be positive");
        address payable bountyChest = bCList[ubounties[ubountyIndex].bountyChestIndex];
        (bool success, ) = bountyChest.call{value: msg.value}("");
        require(success, "ETH transfer failed");
        
        emit BountyContributed(ubountyIndex, msg.sender, 0, msg.value);
    }

    // Internal reward handling
    function _processReward(
        uint256 ubountyIndex,
        uint256 submissionIndex,
        address payable hunter
    ) private {
        Ubounty storage bounty = ubounties[ubountyIndex];
        require(bounty.available > 0, "No rewards available");

        // Calculate rewards
        uint256 tokenReward = getTokenReward(ubountyIndex);
        uint256 weiReward = getWeiReward(ubountyIndex);

        // Update state before external calls
        bounty.available--;
        bool isBountyCompleted = bounty.available == 0;

        // Process token reward if any
        if (tokenReward > 0) {
            address bountyChest = bCList[bounty.bountyChestIndex];
            require(
                devcash.transferFrom(bountyChest, hunter, tokenReward),
                "Token reward failed"
            );
        }

        // Process ETH reward if any
        if (weiReward > 0) {
            BountyChest(bCList[bounty.bountyChestIndex]).transfer(hunter, weiReward);
        }

        emit BountyRewarded(ubountyIndex, submissionIndex, hunter, tokenReward, weiReward);

        if (isBountyCompleted) {
            freeBC.push(bounty.bountyChestIndex);
            emit BountyCompleted(ubountyIndex);
        }
    }

    // View Functions
    function getFee(address poster) public view returns (uint256) {
        return satisfiesWaiver(poster) ? 0 : fee;
    }

    function satisfiesWaiver(address poster) public view returns (bool) {
        return devcash.balanceOf(poster) >= waiver;
    }

    function getTokenReward(uint256 ubountyIndex) public view returns (uint256) {
        Ubounty storage bounty = ubounties[ubountyIndex];
        if (bounty.available == 0) return 0;
        return devcash.balanceOf(bCList[bounty.bountyChestIndex]) / bounty.available;
    }

    function getWeiReward(uint256 ubountyIndex) public view returns (uint256) {
        Ubounty storage bounty = ubounties[ubountyIndex];
        if (bounty.available == 0) return 0;
        return bCList[bounty.bountyChestIndex].balance / bounty.available;
    }

    // Reclaim System
    function reclaim(
        uint256 ubountyIndex
    ) external whenNotPaused nonReentrant bountyExists(ubountyIndex) bountyActive(ubountyIndex) onlyBountyCreator(ubountyIndex) {
        Ubounty storage bounty = ubounties[ubountyIndex];
        
        // Validate reclaim conditions
        require(bounty.deadline != type(uint48).max, "Permanent bounty not reclaimable");
        require(block.timestamp > bounty.deadline, "Deadline not reached");
        
        // Calculate refund amounts
        uint256 tokenAmount = getTokenBalance(ubountyIndex);
        uint256 weiAmount = getWeiBalance(ubountyIndex);
        
        // Update state before transfers
        bounty.available = 0;
        uint32 chestIndex = bounty.bountyChestIndex;
        
        // Free up the bounty chest
        freeBC.push(chestIndex);
        
        // Process refunds
        if (tokenAmount > 0) {
            address bountyChest = bCList[chestIndex];
            require(
                devcash.transferFrom(bountyChest, msg.sender, tokenAmount),
                "Token reclaim failed"
            );
        }
        
        if (weiAmount > 0) {
            BountyChest(bCList[chestIndex]).transfer(msg.sender, weiAmount);
        }
        
        // Mark any pending submissions as rejected
        for (uint256 i = 0; i < bounty.numSubmissions && i < 255; i++) {
            if (!bounty.submissions[i].approved) {
                emit SubmissionRejected(ubountyIndex, i, "Bounty reclaimed by creator");
            }
        }
        
        emit BountyReclaimed(ubountyIndex, tokenAmount, weiAmount);
        emit BountyCompleted(ubountyIndex);
    }
    
    // View functions for reclaim checks
    function isReclaimable(uint256 ubountyIndex) public view bountyExists(ubountyIndex) returns (bool) {
        Ubounty storage bounty = ubounties[ubountyIndex];
        return bounty.deadline != type(uint48).max;
    }
    
    function isReclaimableNow(uint256 ubountyIndex) public view bountyExists(ubountyIndex) returns (bool) {
        Ubounty storage bounty = ubounties[ubountyIndex];
        return bounty.deadline != type(uint48).max && 
               block.timestamp > bounty.deadline &&
               bounty.available > 0;
    }
    
    // Helper functions for balance checks
    function getTokenBalance(uint256 ubountyIndex) public view returns (uint256) {
        address bountyChest = bCList[ubounties[ubountyIndex].bountyChestIndex];
        return devcash.balanceOf(bountyChest);
    }
    
    function getWeiBalance(uint256 ubountyIndex) public view returns (uint256) {
        return bCList[ubounties[ubountyIndex].bountyChestIndex].balance;
    }
