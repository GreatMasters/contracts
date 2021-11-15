// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./IGMMetadata.sol";

/**
    @title GreatMasters NFT configuration interface
    @notice Manages token ownership and provides content details
    @author Gene A. Tsvigun
  */
interface IGMNFTConfig {
    function setMetadata(IGMMetadata metadata_) external;

    function setMinter(address minter_) external;
}
