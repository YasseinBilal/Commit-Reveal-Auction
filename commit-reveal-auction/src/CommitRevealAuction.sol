// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

contract CommitRevealAuction {
    // ---------------------
    // State Varailabes
    // ---------------------
    struct Item {
        uint256 id;
        string name;
        uint256 initialPrice;
        address owner;
        uint256 biddingEnd;
        uint256 revealEnd;
        bool isSold;
        address winner;
        uint256 winningBid;
    }

    struct Bid {
        bytes32 commitHash;
        uint256 deposit;
        bool revealed;
    }

    address public contractOwner;

    uint256 itemCount;

    mapping(uint256 itemId => Item item) public items;

    mapping(uint256 itemId => mapping(address bidder => Bid bid)) bids;

    mapping(uint256 itemId => address[] bidders) bidders;

    // ---------------------
    // Events
    // ---------------------

    event AuctionCreated(
        uint256 itemId,
        string name,
        uint256 initialPrice,
        uint256 biddingEnd,
        uint256 revealEnd
    );

    event BidSubmitted(uint256 itemId, address bidder);
    event BidRevealed(uint256 itemId, address bidder, uint256 amount);
    event WinnerRevealed(uint256 itemId, address winner, uint256 winningBid);
    event DepositClaimed(uint256 itemId, address bidder, uint256 refundAmount);

    // -------------------
    // Access Modifiers
    // -------------------

    modifier onlyOwner() {
        require(
            msg.sender == contractOwner,
            "Only contract owner can call this function."
        );
        _;
    }

    modifier withenBiddenPeriod(uint256 itemId) {
        require(
            block.timestamp < items[itemId].biddingEnd,
            "Bidding period has ended"
        );
        _;
    }

    modifier withinRevealPeriod(uint256 itemId) {
        require(
            block.timestamp > items[itemId].biddingEnd &&
                block.timestamp < items[itemId].revealEnd,
            "Not within reveal period"
        );
        _;
    }

    modifier afterRevealPeriod(uint256 itemId) {
        require(
            block.timestamp > items[itemId].revealEnd,
            "Reveal period has not ended"
        );
        _;
    }

    modifier afterWinnerRevealed(uint256 itemId) {
        require(items[itemId].isSold, "Winner is not revealed yet");
        _;
    }

    constructor() {
        contractOwner = msg.sender;
    }

    // -----------------------
    // contract functions
    // -----------------------

    function createAuction(
        string memory _name,
        uint256 _initialPrice,
        uint256 _biddingDuration,
        uint256 _revealDuration
    ) public onlyOwner {
        itemCount++;
        uint _itemId = itemCount;
        uint256 biddingEnd = block.timestamp + _biddingDuration;
        uint256 revealEnd = biddingEnd + _revealDuration;

        items[_itemId] = Item({
            id: _itemId,
            name: _name,
            initialPrice: _initialPrice,
            owner: contractOwner,
            biddingEnd: biddingEnd,
            revealEnd: revealEnd,
            isSold: false,
            winner: address(0),
            winningBid: 0
        });

        emit AuctionCreated(
            _itemId,
            _name,
            _initialPrice,
            biddingEnd,
            revealEnd
        );
    }

    function submitBid(
        uint256 _itemId,
        bytes32 _commitHash
    ) public payable withenBiddenPeriod(_itemId) {
        require(
            msg.value >= items[_itemId].initialPrice,
            "Deposit must be greater than zero."
        );
        require(_commitHash != 0, "Commit hash is invalid");
        require(
            bids[_itemId][msg.sender].commitHash == 0,
            "Bid already submitted"
        );
        bids[_itemId][msg.sender] = Bid({
            commitHash: _commitHash,
            deposit: msg.value,
            revealed: false
        });

        bidders[_itemId].push(msg.sender);

        emit BidSubmitted(_itemId, msg.sender);
    }

    function revealBid(
        uint256 _itemId,
        uint256 _amount,
        string memory _secret
    ) external withinRevealPeriod(_itemId) {
        Bid storage bid = bids[_itemId][msg.sender];

        require(!bid.revealed, "Bid already revealed");

        require(
            keccak256(abi.encodePacked(_amount, _secret)) == bid.commitHash,
            "Commitment mismatch."
        );

        if (_amount > items[_itemId].winningBid) {
            items[_itemId].winningBid = _amount;
            items[_itemId].winner = msg.sender;
        }

        bid.revealed = true;

        emit BidRevealed(_itemId, msg.sender, _amount);
    }

    function revealWinnder(
        uint256 _itemId
    ) external afterRevealPeriod(_itemId) {
        Item storage item = items[_itemId];

        require(!item.isSold, "Winner already revealed");
        require(item.winner != address(0), "Winner is not assigned");

        item.isSold = true;

        (bool success, ) = payable(contractOwner).call{value: item.winningBid}(
            ""
        );
        require(success, "tranfer failed");

        emit WinnerRevealed(_itemId, item.winner, item.winningBid);
    }

    function claimDeposit(
        uint256 _itemId
    ) external afterWinnerRevealed(_itemId) {
        Bid storage bid = bids[_itemId][msg.sender];
        Item storage item = items[_itemId];

        require(msg.sender != item.winner, "winner can't claim deposit");
        require(bid.commitHash != 0, "No bid committed");

        // Checks Effects Interactions (CEI)
        require(bid.deposit > 0, "No deposit to claim.");

        uint256 refundAmount = bid.deposit;

        if (!bid.revealed) {
            refundAmount = (refundAmount * 90) / 100; // Apply 10% penalty for not revealing
        }

        bid.deposit = 0;
        (bool success, ) = payable(msg.sender).call{value: refundAmount}("");
        require(success, "tranfer failed");
        emit DepositClaimed(_itemId, msg.sender, refundAmount);
    }
}
