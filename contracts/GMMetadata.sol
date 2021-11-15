// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "../interfaces/IGMMetadata.sol";

/**
    @title GreatMasters NFT metadata
    @author Gene A. Tsvigun
  */
contract GMMetadata is IGMMetadata, OwnableUpgradeable, UUPSUpgradeable {

    address private upgrader;

    string private _name;

    string private _symbol;

    uint256 private nextTokenId;

    mapping(uint256 => string) public ipfsHashes;

    function initialize(
        string memory name_,
        string memory symbol_
    ) public initializer {
        __UUPSUpgradeable_init();
        __Ownable_init();
        _name = name_;
        _symbol = symbol_;
        upgrader = msg.sender;
    }

    function _authorizeUpgrade(address) internal override onlyUpgrader {}

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view virtual returns (string memory) {
        return _name;
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    function add(string calldata ipfsHash) external onlyOwner returns (uint256 tokenId){
        tokenId = nextTokenId;
        ipfsHashes[nextTokenId] = ipfsHash;
        nextTokenId++;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual returns (string memory) {
        return string(abi.encodePacked("ipfs://", ipfsHashes[tokenId]));
    }

    modifier onlyUpgrader() {
        require(msg.sender == upgrader);
        _;
    }

    function setUpgrader(address upgrader_) external onlyUpgrader {
        upgrader = upgrader_;
    }
}
