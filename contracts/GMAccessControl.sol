// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../interfaces/IGMAccessControl.sol";

/**
    @title GreatMasters access control
    @notice Admins - members of GreatMasters staff or automated services
    @notice grant and revoke trader, creator, and agent roles to users
    @dev admin role is the default admin role from OZ AccessControlUpgradeable
    @author Gene A. Tsvigun
  */
contract GMAccessControl is IGMAccessControl, AccessControlUpgradeable, UUPSUpgradeable {
    bytes32 public constant TRADER = keccak256("TRADER");
    bytes32 public constant CREATOR = keccak256("CREATOR");
    bytes32 public constant AGENT = keccak256("AGENT");

    mapping(address => address) agents;

    /**
        @param admin address to which default admin role is assigned
      */
    function initialize(
        address admin
    ) public initializer {
        __UUPSUpgradeable_init();
        __AccessControl_init();
        _setupRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    function isAgent(address user) external view override returns (bool) {
        return hasRole(AGENT, user);
    }

    function isAgentOf(address agent, address user) external view override returns (bool) {
        return hasRole(AGENT, agent) && agents[user] == agent;
    }

    /**
        @notice checks if a particular user is the assigned agent of an registered creator
        @param agent address to which default admin role is assigned
      */
    function setAgentOf(address agent, address creator) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _checkRole(AGENT, agent);
        _checkRole(CREATOR, creator);
        require(!_isAgentOf(agent, creator), "AccessControl: the user has already this exact agent assigned");
        agents[creator] = agent;
    }

    function isTrader(address user) external view override returns (bool) {
        return hasRole(TRADER, user);
    }

    function isCreator(address user) external view override returns (bool) {
        return hasRole(CREATOR, user);
    }

    function userPermissions(address user) external view override returns (bool userIsTrader, bool userIsCreator) {
        userIsTrader = hasRole(TRADER, user);
        userIsCreator = hasRole(CREATOR, user);
    }

    function grantAgent(address user) external {
        return grantRole(AGENT, user);
    }

    function grantTrader(address user) external {
        return grantRole(TRADER, user);
    }

    function grantCreator(address user) external {
        return grantRole(CREATOR, user);
    }

    function revokeTrader(address user) external {
        return revokeRole(TRADER, user);
    }

    function revokeCreator(address creator) external {
        delete agents[creator];
        return revokeRole(CREATOR, creator);
    }

    function _isAgentOf(address agent, address user) private view returns (bool) {
        return agents[user] == agent;
    }

    function agentOf(address user) external view override returns (address) {
        return agents[user];
    }
}
