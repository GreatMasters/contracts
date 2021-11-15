// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./IGMAuction.sol";

/**
    @title GreatMasters minter
    @notice Checks messages with content details signed by content creators before minting tokens
    @author Gene A. Tsvigun
  */
interface IGMMinter {
    function verify(string calldata artwork, string calldata document, string calldata details, address signer, bytes calldata signature) external view returns (bool);

    function mintToAuction(
        string calldata artwork,
        string calldata document,
        string calldata details,
        address signer,
        bytes calldata signature,
        uint256 startPrice_,
        bool mintReserveTokenToCreator
    ) external returns (uint256 artId);

    function setUser(address user_) external;

    function setAuction(IGMAuction auction_) external;
}
