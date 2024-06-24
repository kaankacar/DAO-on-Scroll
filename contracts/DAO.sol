// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract AutonomousDAO {
    struct Member {
        bool isMember;
        uint256 joinedAt;
    }

    struct Proposal {
        address proposer;
        string description;
        uint256 value;
        address payable recipient;
        uint256 votingDeadline;
        bool executed;
        uint256 votesFor;
        uint256 votesAgainst;
    }

    address public owner;
    uint256 public memberCount;
    uint256 public proposalCount;
    uint256 public minimumQuorum;
    uint256 public votingDuration;
    uint256 public proposalExecutionDelay;

    mapping(address => Member) public members;
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public votes;

    event NewMember(address member);
    event RemovedMember(address member);
    event NewProposal(uint256 proposalId, address proposer, string description, uint256 value, address recipient);
    event VoteCasted(uint256 proposalId, address voter, bool vote);
    event ProposalExecuted(uint256 proposalId);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    modifier onlyMember() {
        require(members[msg.sender].isMember, "Only members");
        _;
    }

    constructor(uint256 _minimumQuorum, uint256 _votingDuration, uint256 _proposalExecutionDelay) {
        owner = msg.sender;
        minimumQuorum = _minimumQuorum;
        votingDuration = _votingDuration;
        proposalExecutionDelay = _proposalExecutionDelay;
        addMember(msg.sender);
    }

    function addMember(address _member) public onlyOwner {
        require(!members[_member].isMember, "Already a member");
        members[_member] = Member(true, block.timestamp);
        memberCount++;
        emit NewMember(_member);
    }

    function removeMember(address _member) public onlyOwner {
        require(members[_member].isMember, "Not a member");
        delete members[_member];
        memberCount--;
        emit RemovedMember(_member);
    }

    function createProposal(string memory _description, uint256 _value, address payable _recipient) public onlyMember {
        proposals[proposalCount] = Proposal(
            msg.sender,
            _description,
            _value,
            _recipient,
            block.timestamp + votingDuration,
            false,
            0,
            0
        );
        emit NewProposal(proposalCount, msg.sender, _description, _value, _recipient);
        proposalCount++;
    }

    function vote(uint256 _proposalId, bool _vote) public onlyMember {
        Proposal storage proposal = proposals[_proposalId];
        require(block.timestamp < proposal.votingDeadline, "Voting period over");
        require(!votes[_proposalId][msg.sender], "Already voted");

        votes[_proposalId][msg.sender] = true;
        if (_vote) {
            proposal.votesFor++;
        } else {
            proposal.votesAgainst++;
        }
        emit VoteCasted(_proposalId, msg.sender, _vote);
    }

    function executeProposal(uint256 _proposalId) public {
        Proposal storage proposal = proposals[_proposalId];
        require(block.timestamp > proposal.votingDeadline, "Voting period not over");
        require(block.timestamp > proposal.votingDeadline + proposalExecutionDelay, "Execution delay not met");
        require(!proposal.executed, "Already executed");
        require(proposal.votesFor + proposal.votesAgainst >= minimumQuorum, "Quorum not met");
        require(proposal.votesFor > proposal.votesAgainst, "Proposal not approved");

        proposal.executed = true;
        (bool success, ) = proposal.recipient.call{value: proposal.value}("");
        require(success, "Transfer failed");
        emit ProposalExecuted(_proposalId);
    }

    receive() external payable {}

    function withdraw(uint256 _amount) public onlyOwner {
        require(address(this).balance >= _amount, "Insufficient balance");
        (bool success, ) = owner.call{value: _amount}("");
        require(success, "Withdraw failed");
    }

    function getProposalDetails(uint256 _proposalId) public view returns (
        address proposer,
        string memory description,
        uint256 value,
        address recipient,
        uint256 votingDeadline,
        bool executed,
        uint256 votesFor,
        uint256 votesAgainst
    ) {
        Proposal memory proposal = proposals[_proposalId];
        return (
            proposal.proposer,
            proposal.description,
            proposal.value,
            proposal.recipient,
            proposal.votingDeadline,
            proposal.executed,
            proposal.votesFor,
            proposal.votesAgainst
        );
    }

    function isMember(address _member) public view returns (bool) {
        return members[_member].isMember;
    }
}
