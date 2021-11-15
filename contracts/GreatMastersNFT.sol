// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "./GMMetadata.sol";
import "../interfaces/IGMMintable.sol";
import "../interfaces/IGMNFTConfig.sol";

/**
    @title GreatMasters NFT
    @notice Manages token ownership and provides content details
    @author Gene A. Tsvigun
  */
contract GreatMastersNFT is IGMMintable, IGMNFTConfig, ERC721Upgradeable, OwnableUpgradeable, UUPSUpgradeable {

    IGMMetadata public metadata;
    address public minter;

    function initialize(
        string memory name_,
        string memory symbol_,
        IGMMetadata metadata_
    ) public initializer {
        __UUPSUpgradeable_init();
        __ERC721_init(name_, symbol_);
        __Ownable_init();
        metadata = metadata_;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view virtual override returns (string memory) {
        return metadata.name();
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public view virtual override returns (string memory) {
        return metadata.symbol();
    }

    function mint(address to, string calldata ipfsHash) external override onlyMinter returns (uint256 tokenId) {
        tokenId = metadata.add(ipfsHash);
        _safeMint(to, tokenId);
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        return metadata.tokenURI(tokenId);
    }

    function setMetadata(IGMMetadata metadata_) external override onlyOwner {
        metadata = metadata_;
    }

    function setMinter(address minter_) external override onlyOwner {
        require(minter_ != minter);
        minter = minter_;
    }

    modifier onlyMinter {
        require(msg.sender == minter, "GreatMastersNFT: action is allowed only to the minter");
        _;
    }

}
