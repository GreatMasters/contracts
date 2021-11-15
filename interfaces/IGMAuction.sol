// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "../interfaces/IGMAccessControl.sol";

/**
    @title GreatMasters auction for GreatMasters NFTs
    @notice this contract services every auction happening on the platform,
    @notice processes both initial and secondary sales, service and agent fees
    @author Gene A. Tsvigun
  */
interface IGMAuction {
    function scheduleAuction(uint256 artId_, uint256 startPrice_) external;

    function scheduleInitialAuction(address beneficiary_, uint256 artId_, uint256 startPrice_) external;

    function setDuration(uint256 duration_) external;

    function setMaxStartPrice(uint256 maxStartPrice_) external;

    function bid(uint256 artId, uint256 amount) external;

    function completeAuction(uint256 artId) external;

    function setMinter(address minter_) external;

    function setUser(IGMAccessControl user_) external;

    function isActive(uint256 artId) external view returns (bool);
}
