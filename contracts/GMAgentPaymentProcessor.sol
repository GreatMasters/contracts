// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin-upgradeable/access/OwnableUpgradeable.sol";
import "../interfaces/IGMAccessControl.sol";

/**
    @title GreatMasters agent payment processor
    @notice service commission is taken from the final sale price according to `serviceCommissionPercent`
    @notice (100 - `serviceCommissionPercent`)% of the sale price amount is sent to the beneficiary
    @notice in case the sale is subject to agent fee
    @notice then service fee is split between the service and the agent according to `agentCommissionPercent`
    @author Gene A. Tsvigun
  */
abstract contract GMAgentPaymentProcessor is OwnableUpgradeable {
    IERC20Upgradeable internal stablecoin;
    IGMAccessControl user;
    address internal treasury;
    uint8 serviceCommissionPercent;
    uint8 agentCommissionPercent;


    function __GMAgentPaymentProcessor_init(
        IERC20Upgradeable stablecoin_,
        IGMAccessControl user_,
        address treasury_,
        uint8 serviceCommissionPercent_,
        uint8 agentCommissionPercent_
    ) internal initializer {
        __Ownable_init();
        stablecoin = stablecoin_;
        user = user_;
        treasury = treasury_;
        serviceCommissionPercent = serviceCommissionPercent_;
        agentCommissionPercent = agentCommissionPercent_;
    }

    /**
        @notice split the final sale price between the auсtion beneficiary, the creator's agent, and the service itself
        @param amount the amount to be split
        @param beneficiary auction beneficiary
        @param isSubjectToAgentFee whether an agent is to be paid on this sale
      */
    function processPayment(uint256 amount, address beneficiary, bool isSubjectToAgentFee) internal virtual {
        uint256 serviceCommission = amount * serviceCommissionPercent / 100;
        uint256 paidToBeneficiary = amount - serviceCommission;
        uint256 sentToTreasury = serviceCommission;

        stablecoin.transfer(beneficiary, paidToBeneficiary);
        if (isSubjectToAgentFee) {
            address agent = user.agentOf(beneficiary);
            if (agent != address(0)) {
                uint256 agentCommission = serviceCommission * agentCommissionPercent / 100;
                sentToTreasury -= agentCommission;
                stablecoin.transfer(agent, agentCommission);
            }
        }
        stablecoin.transfer(treasury, sentToTreasury);
    }

    function setTreasury(address treasury_) public onlyOwner {
        treasury = treasury_;
    }

    function setServiceCommissionPercent(uint8 percent_) external onlyOwner {
        require(percent_ < 100, "GMPaymentProcessor: don't be that greedy");
        serviceCommissionPercent = percent_;
    }

    function setAgentCommissionPercent(uint8 percent_) external onlyOwner {
        require(percent_ <= 100, "GMPaymentProcessor: percent, you know, up to 100");
        agentCommissionPercent = percent_;
    }
}
