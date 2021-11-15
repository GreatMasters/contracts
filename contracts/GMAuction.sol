// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";
import "@openzeppelin-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "./GMMetadata.sol";
import "../interfaces/IGMAuction.sol";
import "../interfaces/IGMAccessControl.sol";
import "./GMAgentPaymentProcessor.sol";

/**
    @title GreatMasters auction for GreatMasters NFTs
    @notice this contract services every auction happening on the platform,
    @notice processes both initial and secondary sales, service and agent fees
    @author Gene A. Tsvigun
  */
contract GMAuction is IGMAuction, IERC721ReceiverUpgradeable, GMAgentPaymentProcessor, PausableUpgradeable, UUPSUpgradeable {
    event Bid(uint256 artId, uint256 price, address bidder, uint256 minNextBid);
    event AuctionScheduled(uint256 artId, address beneficiary, uint256 startPrice);
    event AuctionStart(uint256 artId, uint256 startPrice, uint256 startTime, uint256 endTime);
    event AuctionEndTimeChanged(uint256 artId, uint256 endTime);
    event AuctionComplete(uint256 artId, uint256 price, address winner, uint256 endTime);
    event AuctionAcquiredToken(uint256 tokenId);


    uint256 public duration;
    uint256 public maxStartPrice; //USDT has 6 decimals
    uint256 constant MIN_DURATION = 1 hours;
    uint256 constant MAX_DURATION = 30 days;
    uint256 constant DEFAULT_DURATION = 2 days;
    uint256 constant AUCTION_PROLONGATION = 15 minutes;
    uint256 constant BID_STEP_PERCENT_MULTIPLIER = 110;

    IERC721Upgradeable public nft;
    address public minter;

    struct Auction {
        address beneficiary;
        uint256 startTime;
        uint256 endTime;
        uint256 startPrice;
        address highestBidder;
        uint256 highestBid;
    }

    mapping(uint256 => Auction) public auctions;
    mapping(uint256 => bool) public isSubjectToAgentFee;

    /**
        @notice Same instance for multiple auctions within the same NFT contract using the same stablecoin
        @param nft_ nft contract defining items traded
        @param stablecoin_ address of a mostly ERC20-compliant stablecoin to be used in the auction, BUSD, USDT etc.
        @param user_ the instance of `GMAccessControl` used to check which addresses are permitted to participate
        @param treasury_ service fee storage
        @param serviceCommissionPercent_ percentage of final sale prices taken as service commission
        @param agentCommissionPercent_ percentage of service commission taken as agent fee
      */
    function initialize(
        IERC721Upgradeable nft_,
        IERC20Upgradeable stablecoin_,
        IGMAccessControl user_,
        address treasury_,
        uint8 serviceCommissionPercent_,
        uint8 agentCommissionPercent_
    ) public initializer {
        __UUPSUpgradeable_init();
        __Pausable_init();
        __GMAgentPaymentProcessor_init(
            stablecoin_,
            user_,
            treasury_,
            serviceCommissionPercent_,
            agentCommissionPercent_);
        nft = nft_;
        duration = 7 days;
        maxStartPrice = 1000 * 10 ** 6;
    }

    function _authorizeUpgrade(address) internal override onlyOwner whenPaused {}

    /**
        @notice schedule an auction, place the NFT in the custody of the auction contract
        @param artId_ ID of the item sold
        @param startPrice_ starting/reserve price, must be greater than zero
        @dev zero start price is a special value
    */
    function scheduleAuction(
        uint256 artId_,
        uint256 startPrice_
    ) external whenNotScheduled(artId_) whenNotPaused onlyHolder(artId_) onlyTrader virtual {
        _checkAuctionParams(
            artId_,
            startPrice_
        );
        address beneficiary = nft.ownerOf(artId_);
        auctions[artId_] = Auction(
            nft.ownerOf(artId_),
            0,
            0,
            startPrice_,
            address(0),
            0
        );
        nft.transferFrom(beneficiary, address(this), artId_);
        _logAuctionScheduled(artId_, auctions[artId_]);
    }

    /**
        @notice schedule the first auction of a freshly minted item
        @notice place the NFT in the custody of the auction contract
        @param beneficiary_ the address to receive the auction's winning bid for the item sold
        @param artId_ ID of the item sold
        @param startPrice_ starting/reserve price, must be greater than zero
        @dev zero start price is special value
    */
    function scheduleInitialAuction(
        address beneficiary_,
        uint256 artId_,
        uint256 startPrice_
    ) external whenNotScheduled(artId_) whenNotPaused onlyMinter virtual {
        _checkAuctionParams(
            artId_,
            startPrice_
        );
        auctions[artId_] = Auction(
            beneficiary_,
            0,
            0,
            startPrice_,
            address(0),
            0
        );
        isSubjectToAgentFee[artId_] = true;
        require(nft.ownerOf(artId_) == address(this));
        _logAuctionScheduled(artId_, auctions[artId_]);
    }

    /**
        @notice Bid on the auction, stablecoin contract approval required, bid values refunded on overbid
        @param artId ID of the item sold
        @param amount bid amount - has to be higher than the current highest bid plus bid step
      */
    function bid(uint256 artId, uint256 amount) external onlyTrader whenScheduled(artId) whenNotFinished(artId) virtual {
        _startAuction(artId);
        Auction storage a = auctions[artId];
        require(amount >= minimumBid(artId), "GMAuction: bid amount must >= 110% of the current hightest bid");
        require(a.highestBidder != msg.sender, "GMAuction: you're the highest bidder already");

        stablecoin.transferFrom(msg.sender, address(this), amount);
        _refundBid(artId);
        a.highestBidder = msg.sender;
        a.highestBid = amount;
        _adjustAuctionEndTime(artId);
        emit Bid(artId, a.highestBid, msg.sender, minimumBid(artId));
    }

    /**
        @notice duration of all auctions
        @param duration_ must be greater or equal than MIN_DURATION and less or equal than MAX_DURATION
    */
    function setDuration(uint256 duration_) external onlyOwner virtual {
        require(duration_ >= MIN_DURATION && duration_ <= MAX_DURATION, "GMAuction: Wrong auction duration length");
        duration = duration_;
    }

    /**
        @notice max start price for all auctions
        @param maxStartPrice_ must be greater than zero. Zero is special value
    */
    function setMaxStartPrice(uint256 maxStartPrice_) external onlyOwner virtual {
        require(maxStartPrice_ > 0, "GMAuction: start price could not be zero");
        maxStartPrice = maxStartPrice_;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    /**
        @notice End the auction, send the highest bid to the beneficiary, send NFT to the highest bidder.
        @dev Process auction completion by sending NFT to the highest bidder and stablecoin to its beneficiary
        @param artId ID of the item sold
      */
    function completeAuction(uint256 artId) external whenFinished(artId) override {
        Auction storage a = auctions[artId];

        address highestBidder = auctions[artId].highestBidder;
        uint256 highestBid = auctions[artId].highestBid;

        nft.transferFrom(address(this), highestBidder, artId);

        processPayment(highestBid, auctions[artId].beneficiary, isSubjectToAgentFee[artId]);

        emit AuctionComplete(artId, highestBid, highestBidder, auctions[artId].endTime);

        _markNotScheduled(artId);
    }

    /**
        @notice Set minter address that is allowed to start initial auctions for freshly minted tokens
        @param minter_ the address to set as new minter
      */
    function setMinter(address minter_) public onlyOwner override {
        minter = minter_;
    }


    /**
        @notice Set the instance of `GMAccessControl` used to check which addresses are permitted to participate
        @param user_ the address of the new access control
      */
    function setUser(IGMAccessControl user_) external onlyOwner override {
        user = user_;
    }

    modifier onlyTrader {
        require(user.isTrader(msg.sender), "GMAuction: only traders are allowed to participate in auctions");
        _;
    }

    modifier onlyMinter {
        require(msg.sender == minter, "GMAuction: action is allowed only to the minter");
        _;
    }

    modifier onlyHolder(uint256 artId) {
        require(msg.sender == nft.ownerOf(artId), "GMAuction: you can't sell what you don't own");
        _;
    }

    modifier whenFinished(uint256 artId) {
        require(started(artId), "GMAuction: action is allowed only for auction that actually happened");
        require(_isFinished(artId), "GMAuction: action is only allowed after the auction end time");
        _;
    }

    modifier whenNotFinished(uint256 artId) {
        require(!_isFinished(artId), "GMAuction: action is only allowed before the auction end time");
        _;
    }

    modifier whenActive(uint256 artId) {
        require(_isActive(artId), "GMAuction: action is allowed when the auction for the item is active");
        _;
    }

    modifier whenNotActive(uint256 artId) {
        require(!_isActive(artId), "GMAuction: action is allowed when there is no active auction for the item");
        _;
    }

    modifier whenScheduled(uint256 artId) {
        require(isScheduled(artId), "GMAuction: action is allowed when an auction is scheduled for the item");
        _;
    }

    modifier whenNotScheduled(uint256 artId) {
        require(!isScheduled(artId), "GMAuction: action is allowed when there is no scheduled auction for the item");
        _;
    }

    function isActive(uint256 artId) external view override returns (bool){
        return _isActive(artId);
    }

    function isScheduled(uint256 artId) public view returns (bool){
        return auctions[artId].startPrice != 0;
    }

    function started(uint256 artId) public view returns (bool) {
        return auctions[artId].highestBid != 0;
    }

    function isFinished(uint256 artId) external view returns (bool) {
        return _isFinished(artId);
    }

    function minimumBid(uint256 artId) public view returns (uint256 minBid){
        if (auctions[artId].highestBid != 0) {
            minBid = auctions[artId].highestBid * BID_STEP_PERCENT_MULTIPLIER / 100;
        } else {
            minBid = auctions[artId].startPrice;
        }
    }

    function _checkAuctionParams(
        uint256 artId_,
        uint256 startPrice_
    ) internal virtual {
        require(nft.ownerOf(artId_) != address(0), "GMAuction constructor: the token must exist");
        require(startPrice_ <= maxStartPrice, "GMAuction constructor: start price too high");
    }

    function _logAuctionScheduled(uint256 artId, Auction storage a) internal virtual {
        emit AuctionScheduled(artId, a.beneficiary, a.startPrice);
    }

    function _refundBid(uint256 artId) private {
        address highestBidder = auctions[artId].highestBidder;
        if (highestBidder != address(0))
            stablecoin.transfer(highestBidder, auctions[artId].highestBid);
    }

    function _adjustAuctionEndTime(uint256 artId) internal virtual {
        uint256 adjustedTime = AUCTION_PROLONGATION + block.timestamp;
        if (auctions[artId].endTime < adjustedTime) {
            auctions[artId].endTime = adjustedTime;
            emit AuctionEndTimeChanged(artId, adjustedTime);
        }
    }

    function _startAuction(uint256 artId) internal virtual {
        if (!started(artId)) {
            auctions[artId].startTime = block.timestamp;
            auctions[artId].endTime = block.timestamp + duration;
            emit AuctionStart(artId, auctions[artId].startPrice, auctions[artId].startTime, auctions[artId].endTime);
        }
    }

    function _markNotScheduled(uint256 artId) internal virtual {
        delete auctions[artId];
        delete isSubjectToAgentFee[artId];
    }

    function _isActive(uint256 artId) internal virtual view returns (bool){
        uint256 startTime = auctions[artId].startTime;
        return startTime > 0 && startTime <= block.timestamp && auctions[artId].endTime > block.timestamp;
    }

    function _isFinished(uint256 artId) internal virtual view returns (bool){
        uint256 startTime = auctions[artId].startTime;
        return startTime > 0 && auctions[artId].endTime < block.timestamp;
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4){
        emit AuctionAcquiredToken(tokenId);
        return IERC721ReceiverUpgradeable.onERC721Received.selector;
    }
}
