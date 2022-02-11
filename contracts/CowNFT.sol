// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;
pragma experimental ABIEncoderV2 ;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Authorizable is Ownable {

    using SafeMath for uint256;

    mapping(address => bool) public authorized;
    address[] public adminList;

    event AddAuthorized(address indexed _address);
    event RemoveAuthorized(address indexed _address, uint index);

    modifier onlyAuthorized() {
        require(authorized[msg.sender] || owner() == msg.sender,"Cow Authorizable: caller is not the SuperAdmin or Admin");
        _;
    }

    function addAuthorized(address _toAdd) onlyOwner() external {
        require(_toAdd != address(0),"Cow Authorizable: _toAdd isn't vaild address");
        require(!authorized[_toAdd],"Cow Authorizable: _toAdd is already added");
        authorized[_toAdd] = true;
        adminList.push(_toAdd);
        emit AddAuthorized(_toAdd);
    }

    function removeAuthorized(address _toRemove,uint _index) onlyOwner() external {
        require(_toRemove != address(0),"Cow Authorizable: _toRemove isn't vaild address");
        require(adminList[_index] == _toRemove,"Cow Authorizable: _index isn't valid index");
        authorized[_toRemove] = false;
        adminList[_index] = adminList[(adminList.length).sub(1)]; 
        adminList.pop();
        emit RemoveAuthorized(_toRemove,_index);
    }

    function getAdminList() public view returns(address[] memory ){
        return adminList;
    }
}

interface IERC2981 is IERC165 {
  
    function royaltyInfo(
        uint256 _tokenId,
        uint256 _salePrice
    ) external view returns (
        address receiver,
        uint256 royaltyAmount
    );
}

abstract contract ERC2981 is IERC2981, ERC165 {
    struct RoyaltyInfo {
        address receiver;
        uint96 royaltyFraction;
    }

    RoyaltyInfo private _defaultRoyaltyInfo;
    mapping(uint256 => RoyaltyInfo) private _tokenRoyaltyInfo;

    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC165) returns (bool) {
        return interfaceId == type(IERC2981).interfaceId || super.supportsInterface(interfaceId);
    }

    function royaltyInfo(uint256 _tokenId, uint256 _salePrice)
        external
        view
        virtual
        override
        returns (address, uint256)
    {
        RoyaltyInfo memory royalty = _tokenRoyaltyInfo[_tokenId];

        if (royalty.receiver == address(0)) {
            royalty = _defaultRoyaltyInfo;
        }

        uint256 royaltyAmount = (_salePrice * royalty.royaltyFraction) / _feeDenominator();

        return (royalty.receiver, royaltyAmount);
    }

    function _feeDenominator() internal pure virtual returns (uint96) {
        return 10000;
    }

    function _setDefaultRoyalty(address receiver, uint96 feeNumerator) internal virtual {
        require(feeNumerator <= _feeDenominator(), "ERC2981: royalty fee will exceed salePrice");
        require(receiver != address(0), "ERC2981: invalid receiver");

        _defaultRoyaltyInfo = RoyaltyInfo(receiver, feeNumerator);
    }

    function _deleteDefaultRoyalty() internal virtual {
        delete _defaultRoyaltyInfo;
    }

    function _setTokenRoyalty(
        uint256 tokenId,
        address receiver,
        uint96 feeNumerator
    ) internal virtual {
        require(feeNumerator <= _feeDenominator(), "ERC2981: royalty fee will exceed salePrice");
        require(receiver != address(0), "ERC2981: Invalid parameters");

        _tokenRoyaltyInfo[tokenId] = RoyaltyInfo(receiver, feeNumerator);
    }

    function _resetTokenRoyalty(uint256 tokenId) internal virtual {
        delete _tokenRoyaltyInfo[tokenId];
    }
}

contract WorldCow is ERC721, ERC2981, Authorizable {

    using Strings for uint256;
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.UintSet;

    uint256 public counter = 0;
    uint256 public totalSupply;
    string public faction;
    string private baseURI_;

    // Mapping from holder address to their (enumerable) set of owned tokens
    mapping(address => EnumerableSet.UintSet) private _holderTokens;
    mapping(uint256 => string) public tokenFaction;

    constructor(string memory _baseTokenURI,string memory _factionName, uint96 _royaltyFeesinBips) ERC721("WorldCow", "COW") {
        _setBaseURI(_baseTokenURI);
        faction = _factionName;
        totalSupply = 10000;
        setRoyaltyInfo(owner(), _royaltyFeesinBips);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function setRoyaltyInfo(address _receiver, uint96 _royaltyFeesinBips) public onlyOwner {
        _setDefaultRoyalty(_receiver, _royaltyFeesinBips);
    }

    function tokenOfOwnerByIndex(address _owner, uint256 _index) public view returns (uint256){
        return _holderTokens[_owner].at(_index);
    }

    function _setBaseURI(string memory _baseTokenURI) internal {
        baseURI_ = _baseTokenURI;
    }

    function changeFaction(string memory _factionName) public onlyOwner(){
        faction = _factionName;
    }

    function changeTotalSupply(uint256 _totalSupply) public onlyOwner(){
        totalSupply = _totalSupply;
    }

    function mint(address _to) public onlyAuthorized() {
        require(_to != address(0),"WorldCow: _to address not a valid");
        require(counter <= totalSupply,"WorldCow: maximum tokens minted");
        counter += 1;
        tokenFaction[counter] = faction;
        _holderTokens[_to].add(counter);
        _safeMint(_to,counter);
    }

    function batchMint(address _to,uint256 _numberOfToken) external onlyAuthorized() {
        for (uint256 i = 0; i < _numberOfToken; i++) {
            mint(_to);
        }
    }

    function burn(uint _tokenId) public {
        require(_isApprovedOrOwner(_msgSender(), _tokenId), "WorldCow: burn caller is not owner nor approved");
        _holderTokens[msg.sender].remove(_tokenId);
        delete tokenFaction[_tokenId];
        _burn(_tokenId);
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI_;
    }


    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "WorldCow: URI query for nonexistent token");

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString(),".json")) : "";
    }

    function transferFrom(address from,address to,uint256 tokenId) public override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "WorldCow: transfer caller is not owner nor approved");
        _holderTokens[from].remove(tokenId);
        _holderTokens[to].add(tokenId);
        _transfer(from, to, tokenId);
    }

    function safeTransferFrom(address from,address to,uint256 tokenId) public override {
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(address from,address to,uint256 tokenId,bytes memory _data) public override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "WorldCow: transfer caller is not owner nor approved");
        _holderTokens[from].remove(tokenId);
        _holderTokens[to].add(tokenId);
        _safeTransfer(from, to, tokenId, _data);
    }

    function getTokens(address _address) public view returns(uint256[] memory){
        return _holderTokens[_address].values();
    }
}
