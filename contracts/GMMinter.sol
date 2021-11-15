// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin-upgradeable/utils/cryptography/SignatureCheckerUpgradeable.sol";
import "@openzeppelin-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./GreatMastersNFT.sol";
import "../interfaces/IGMAuction.sol";
import "../interfaces/IGMMinter.sol";

/**
    @title GreatMasters minter
    @notice Checks messages with content details signed by content creators before minting tokens
    @author Gene A. Tsvigun
  */
contract GMMinter is IGMMinter, OwnableUpgradeable, UUPSUpgradeable {
    bytes32 public constant MINTER_ROLE = 0x00; //same as DEFAULT_ADMIN_ROLE in AccessControl(IAccessControlUpgradeable)
    string constant prefix = "\x19Ethereum Signed Message:\n140";
    string constant delimiter = "\n";

    IGMMintable public nft;
    IGMAuction public auction;
    IAccessControlUpgradeable user;

    /**
       @notice Verifying artwork and metadata signatures, minting NFTs and scheduling initial auctions
       @param auction_ auction contract address
       @param nft_ nft contract defining items traded
       @param user_ `GMAccessControl` instance used to check user permissions
     */
    function initialize(
        GreatMastersNFT nft_,
        IGMAuction auction_,
        IAccessControlUpgradeable user_
    ) public initializer {
        __UUPSUpgradeable_init();
        __Ownable_init();
        nft = nft_;
        auction = auction_;
        user = user_;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function verify(string calldata artwork, string calldata document, string calldata details, address signer, bytes calldata signature) external view override returns (bool) {
        return _verify(artwork, document, details, signer, signature);
    }

    /**
       @notice mint a token and immediately schedule its first auction
       @param artwork the artwork's IPFS hash
       @param document IPFS hash of the artwork's certificate of authenticity
       @param details IPFS hash of the ERC721 token details file
       @param signer address of the item's creator
       @param signature signature normally provided by the creator's MetaMask
       @param startPrice_ start price of the item's first auction
       @param mintReserveTokenToCreator whether a second copy should be minted and reserved for the creator
     */
    function mintToAuction(
        string calldata artwork,
        string calldata document,
        string calldata details,
        address signer,
        bytes calldata signature,
        uint256 startPrice_,
        bool mintReserveTokenToCreator
    ) external override onlyMinter returns (uint256 artId){
        require(_verify(artwork, document, details, signer, signature), "GMMinter: only verified signatures can result in minting artwork tokens");
        artId = nft.mint(address(auction), details);
        if (mintReserveTokenToCreator)
            nft.mint(signer, details);
        auction.scheduleInitialAuction(
            signer,
            artId,
            startPrice_);
    }

    function setUser(address user_) external override onlyOwner {
        require(user_ != address(user));
        user = IAccessControlUpgradeable(user_);
    }

    function setAuction(IGMAuction auction_) external override onlyOwner {
        auction = auction_;
    }

    modifier onlyMinter {
        require(user.hasRole(MINTER_ROLE, msg.sender), "GMMinter: action is allowed only addresses with DEFAULT_ADMIN_ROLE in AccessControl");
        _;
    }

    function _verify(string calldata artwork, string calldata document, string calldata details, address signer, bytes calldata signature) internal view returns (bool) {
        return SignatureCheckerUpgradeable.isValidSignatureNow(
            signer,
            keccak256(abi.encodePacked(prefix, artwork, delimiter, document, delimiter, details)),
            signature);
    }
}
