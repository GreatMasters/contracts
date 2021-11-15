// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

/**
    @title GreatMasters NFT metadata
    @author Gene A. Tsvigun
  */
interface IGMMetadata {
    /**
     * @dev Returns the token collection name.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the token collection symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
     */
    function tokenURI(uint256 tokenId) external view returns (string memory);

    function add(string calldata ipfsHash) external returns (uint256 tokenId);

    function setUpgrader(address upgrader_) external;
}
