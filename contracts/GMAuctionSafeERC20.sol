// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./GMAuction.sol";
import "@openzeppelin-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

/**
    @title GreatMasters auction for GreatMasters NFTs
    @notice this contract services every auction happening on the platform,
    @notice processes both initial and secondary sales, service and agent fees
    @author Gene A. Tsvigun
  */
contract GMAuctionSafeERC20 is GMAuction {

    /**
        @notice Bid on the auction, stablecoin contract approval required, bid values refunded on overbid
        @param artId ID of the item sold
        @param amount bid amount - has to be higher than the current highest bid plus bid step
      */
    function bid(uint256 artId, uint256 amount) external onlyTrader whenScheduled(artId) whenNotFinished(artId) virtual override {
        _startAuction(artId);
        Auction storage a = auctions[artId];
        require(amount >= minimumBid(artId), "GMAuction: bid amount must >= 110% of the current hightest bid");
        require(a.highestBidder != msg.sender, "GMAuction: you're the highest bidder already");

        safeTransferFrom(msg.sender, address(this), amount);
        refundBid(artId);
        a.highestBidder = msg.sender;
        a.highestBid = amount;
        _adjustAuctionEndTime(artId);
        emit Bid(artId, a.highestBid, msg.sender, minimumBid(artId));
    }

    /**
        @notice split the final sale price between the auсtion beneficiary, the creator's agent, and the service itself
        @param amount the amount to be split
        @param beneficiary auction beneficiary
        @param isSubjectToAgentFee whether an agent is to be paid on this sale
      */
    function processPayment(uint256 amount, address beneficiary, bool isSubjectToAgentFee) internal virtual override {
        uint256 serviceCommission = amount * serviceCommissionPercent / 100;
        uint256 paidToBeneficiary = amount - serviceCommission;
        uint256 sentToTreasury = serviceCommission;

        safeTransfer(beneficiary, paidToBeneficiary);
        if (isSubjectToAgentFee) {
            address agent = user.agentOf(beneficiary);
            if (agent != address(0)) {
                uint256 agentCommission = serviceCommission * agentCommissionPercent / 100;
                sentToTreasury -= agentCommission;
                safeTransfer(agent, agentCommission);
            }
        }
        safeTransfer(treasury, sentToTreasury);
    }

    /**
        @notice refund the previous highest bid when it is overbid
        @param artId ID of the item sold
      */
    function refundBid(uint256 artId) internal virtual {
        address highestBidder = auctions[artId].highestBidder;
        if (highestBidder != address(0))
            safeTransfer(highestBidder, auctions[artId].highestBid);
    }

    function safeTransferFrom(address from, address to, uint256 amount) internal virtual {
        SafeERC20Upgradeable.safeTransferFrom(stablecoin, from, to, amount);
    }

    function safeTransfer(address to, uint256 amount) internal virtual {
        SafeERC20Upgradeable.safeTransfer(stablecoin, to, amount);
    }
}
