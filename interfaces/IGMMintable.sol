// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

/**
    @title GreatMasters NFT minting interface
    @author Gene A. Tsvigun
  */
interface IGMMintable {
    function mint(address to, string calldata ipfsHash) external returns (uint256 tokenId);
}
