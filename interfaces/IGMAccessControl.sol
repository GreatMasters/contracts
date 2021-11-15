// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

/**
    @title GreatMasters access control
    @notice Admins - members of GreatMasters staff or automated services
    @notice grant and revoke trader, creator, and agent roles to users
    @author Gene A. Tsvigun
  */
interface IGMAccessControl {
    function isTrader(address user) external view returns (bool);

    function isCreator(address user) external view returns (bool);

    function userPermissions(address user) external view returns (bool userIsTrader, bool userIsCreator);

    function isAgent(address user) external view returns (bool);

    function isAgentOf(address agent, address user) external view returns (bool);

    function agentOf(address user) external view returns (address);
}
