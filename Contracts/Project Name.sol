// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Basic Voting System - Simple yes/no voting with vote counting
 * @dev A simple democratic voting system where users can create proposals
 * and cast yes/no votes with transparent vote counting
 */
contract Project {
    
    // Voting proposal structure
    struct Proposal {
        uint256 id;
        string title;
        string description;
        uint256 yesVotes;
        uint256 noVotes;
        uint256 endTime;
        bool active;
        address creator;
    }
    
    // Vote record structure
    struct Vote {
        address voter;
        uint256 proposalId;
        bool vote; // true for yes, false for no
        uint256 timestamp;
    }
    
    // State variables
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    mapping(uint256 => Vote[]) public proposalVotes;
    mapping(address => uint256[]) public voterHistory;
    
    uint256 public proposalCount;
    address public admin;
    uint256 public defaultVotingPeriod = 7 days;
    
    // Events
    event ProposalCreated(
        uint256 indexed proposalId,
        string title,
        address indexed creator,
        uint256 endTime
    );
    
    event VoteCast(
        uint256 indexed proposalId,
        address indexed voter,
        bool vote,
        uint256 yesVotes,
        uint256 noVotes
    );
    
    event ProposalEnded(
        uint256 indexed proposalId,
        bool passed,
        uint256 yesVotes,
        uint256 noVotes
    );
    
    // Modifiers
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }
    
    modifier proposalExists(uint256 proposalId) {
        require(proposalId < proposalCount, "Proposal does not exist");
        _;
    }
    
    modifier proposalActive(uint256 proposalId) {
        require(proposals[proposalId].active, "Proposal is not active");
        require(block.timestamp <= proposals[proposalId].endTime, "Voting period has ended");
        _;
    }
    
    modifier hasNotVoted(uint256 proposalId) {
        require(!hasVoted[proposalId][msg.sender], "You have already voted on this proposal");
        _;
    }
    
    constructor() {
        admin = msg.sender;
    }
    
    /**
     * @dev Core Function 1: Create a new voting proposal
     * @param _title The title of the proposal
     * @param _description Detailed description of what is being voted on
     * @param _votingDuration Duration of voting period in seconds (0 for default)
     * @return proposalId The ID of the created proposal
     */
    function createProposal(
        string memory _title,
        string memory _description,
        uint256 _votingDuration
    ) external returns (uint256) {
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_description).length > 0, "Description cannot be empty");
        
        uint256 votingPeriod = (_votingDuration > 0) ? _votingDuration : defaultVotingPeriod;
        uint256 proposalId = proposalCount++;
        uint256 endTime = block.timestamp + votingPeriod;
        
        proposals[proposalId] = Proposal({
            id: proposalId,
            title: _title,
            description: _description,
            yesVotes: 0,
            noVotes: 0,
            endTime: endTime,
            active: true,
            creator: msg.sender
        });
        
        emit ProposalCreated(proposalId, _title, msg.sender, endTime);
        return proposalId;
    }
    
    /**
     * @dev Core Function 2: Cast a vote on a proposal
     * @param proposalId The ID of the proposal to vote on
     * @param vote True for YES, False for NO
     */
    function castVote(uint256 proposalId, bool vote) 
        external 
        proposalExists(proposalId)
        proposalActive(proposalId)
        hasNotVoted(proposalId)
    {
        Proposal storage proposal = proposals[proposalId];
        
        // Record the vote
        hasVoted[proposalId][msg.sender] = true;
        
        // Update vote counts
        if (vote) {
            proposal.yesVotes++;
        } else {
            proposal.noVotes++;
        }
        
        // Store vote details
        Vote memory newVote = Vote({
            voter: msg.sender,
            proposalId: proposalId,
            vote: vote,
            timestamp: block.timestamp
        });
        
        proposalVotes[proposalId].push(newVote);
        voterHistory[msg.sender].push(proposalId);
        
        emit VoteCast(proposalId, msg.sender, vote, proposal.yesVotes, proposal.noVotes);
        
        // Auto-end proposal if voting period is over
        if (block.timestamp > proposal.endTime) {
            _endProposal(proposalId);
        }
    }
    
    /**
     * @dev Core Function 3: End a proposal and determine the result
     * @param proposalId The ID of the proposal to end
     */
    function endProposal(uint256 proposalId) 
        external 
        proposalExists(proposalId)
    {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.active, "Proposal already ended");
        require(
            block.timestamp > proposal.endTime || msg.sender == proposal.creator || msg.sender == admin,
            "Cannot end proposal yet"
        );
        
        _endProposal(proposalId);
    }
    
    /**
     * @dev Internal function to end a proposal
     */
    function _endProposal(uint256 proposalId) internal {
        Proposal storage proposal = proposals[proposalId];
        proposal.active = false;
        
        bool passed = proposal.yesVotes > proposal.noVotes;
        emit ProposalEnded(proposalId, passed, proposal.yesVotes, proposal.noVotes);
    }
    
    // View functions
    
    /**
     * @dev Get proposal details
     */
    function getProposal(uint256 proposalId) 
        external 
        view 
        proposalExists(proposalId)
        returns (
            string memory title,
            string memory description,
            uint256 yesVotes,
            uint256 noVotes,
            uint256 endTime,
            bool active,
            address creator
        ) 
    {
        Proposal memory proposal = proposals[proposalId];
        return (
            proposal.title,
            proposal.description,
            proposal.yesVotes,
            proposal.noVotes,
            proposal.endTime,
            proposal.active,
            proposal.creator
        );
    }
    
    /**
     * @dev Get proposal results
     */
    function getProposalResults(uint256 proposalId) 
        external 
        view 
        proposalExists(proposalId)
        returns (
            uint256 yesVotes,
            uint256 noVotes,
            uint256 totalVotes,
            bool passed,
            bool isActive
        ) 
    {
        Proposal memory proposal = proposals[proposalId];
        uint256 total = proposal.yesVotes + proposal.noVotes;
        bool hasPassed = proposal.yesVotes > proposal.noVotes && !proposal.active;
        
        return (
            proposal.yesVotes,
            proposal.noVotes,
            total,
            hasPassed,
            proposal.active
        );
    }
    
    /**
     * @dev Check if an address has voted on a proposal
     */
    function checkVoteStatus(uint256 proposalId, address voter) 
        external 
        view 
        proposalExists(proposalId)
        returns (bool hasVotedOnProposal) 
    {
        return hasVoted[proposalId][voter];
    }
    
    /**
     * @dev Get all active proposals
     */
    function getActiveProposals() external view returns (uint256[] memory activeIds) {
        uint256 activeCount = 0;
        
        // Count active proposals
        for (uint256 i = 0; i < proposalCount; i++) {
            if (proposals[i].active && block.timestamp <= proposals[i].endTime) {
                activeCount++;
            }
        }
        
        // Create array of active proposal IDs
        activeIds = new uint256[](activeCount);
        uint256 index = 0;
        
        for (uint256 i = 0; i < proposalCount; i++) {
            if (proposals[i].active && block.timestamp <= proposals[i].endTime) {
                activeIds[index] = i;
                index++;
            }
        }
    }
    
    /**
     * @dev Get voter's voting history
     */
    function getVoterHistory(address voter) external view returns (uint256[] memory) {
        return voterHistory[voter];
    }
    
    /**
     * @dev Get total vote count for a proposal
     */
    function getTotalVotes(uint256 proposalId) 
        external 
        view 
        proposalExists(proposalId)
        returns (uint256) 
    {
        return proposals[proposalId].yesVotes + proposals[proposalId].noVotes;
    }
    
    /**
     * @dev Get vote percentage for a proposal
     */
    function getVotePercentages(uint256 proposalId) 
        external 
        view 
        proposalExists(proposalId)
        returns (uint256 yesPercentage, uint256 noPercentage) 
    {
        Proposal memory proposal = proposals[proposalId];
        uint256 total = proposal.yesVotes + proposal.noVotes;
        
        if (total == 0) {
            return (0, 0);
        }
        
        yesPercentage = (proposal.yesVotes * 100) / total;
        noPercentage = (proposal.noVotes * 100) / total;
    }
    
    // Admin functions
    
    /**
     * @dev Set default voting period
     */
    function setDefaultVotingPeriod(uint256 _period) external onlyAdmin {
        require(_period > 0, "Voting period must be greater than 0");
        defaultVotingPeriod = _period;
    }
    
    /**
     * @dev Transfer admin role
     */
    function transferAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "Invalid admin address");
        admin = newAdmin;
    }
    
    /**
     * @dev Emergency end proposal (admin only)
     */
    function emergencyEndProposal(uint256 proposalId) external onlyAdmin proposalExists(proposalId) {
        require(proposals[proposalId].active, "Proposal already ended");
        _endProposal(proposalId);
    }
}
