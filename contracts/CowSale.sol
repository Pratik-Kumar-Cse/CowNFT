// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;
pragma experimental ABIEncoderV2 ;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

interface x22IERC721 {
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function tokenOfOwnerByIndex(address _address , uint256 _index) external returns(uint256);
    function balanceOf(address _address) external returns(uint256);
    function ownerOf(uint256 _tokenId) external returns(address);
    function mint(address) external;
    function batchMint(address,uint256) external; 
    function faction() external returns(string memory);
}

interface SwapPair {
    function getReserves() external view
        returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        );
}

contract Purchase is Ownable,Pausable,ReentrancyGuard {
    
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    
    SwapPair public x22_bnb_Pair;
    
    x22IERC721 public nft;
    IERC20 public x22;
    
    address payable public treasurerAddress;
    
    uint256 public constant DENOMINATOR = 10000;
    
    uint256 public maxTokenForOneSaleTransaction;
    uint256 public discount;
    uint256 public priceInBNB;
    uint256 public priceInX22;

    bool public isDiscount;

    event BuyNFTforBNB(address _buyer,uint256 _amount,uint256 _numberOfToken);
    event BuyNFTforX22(address _buyer,uint256 _amount,uint256 _numberOfToken);
    event UpdateWhitelist(bool _isWhitelist);
    event UpdateIsDiscount(bool _isDiscount);
    event SetPrices(uint256 _priceInBNB);
    event SetPricesX22(uint256 _priceInX22);
    event SetDiscount(uint256 _discount);
    event SetTokensLimit(uint256 _normalSale);
    
    modifier validTokensAmount(uint256 _numberOfToken){
        require(_numberOfToken <= maxTokenForOneSaleTransaction,"Purchase: enter valid token amount for normal sale");
        _;
    }

    constructor(address _nft,address _x22,address _pair)  {
        require(_nft != address(0));
        require(_x22 != address(0));
        nft = x22IERC721(_nft);
        x22 = IERC20(_x22);
        x22_bnb_Pair = SwapPair(_pair);
        priceInBNB = 60000000000000000;
        priceInX22 = 100000000000000000000;
        discount = 5000;
        maxTokenForOneSaleTransaction = 20;
        _pause();
    }
    
    function setTokensLimit(uint256 _normalSale) public onlyOwner(){
        maxTokenForOneSaleTransaction = _normalSale;
        emit SetTokensLimit(maxTokenForOneSaleTransaction);
    }

    function updateIsDiscount(bool _isDiscount) public onlyOwner(){
        isDiscount = _isDiscount;
        emit UpdateIsDiscount(isDiscount);
    }
    
    function setPrices(uint256 _priceInBNB) public onlyOwner() {
        require(_priceInBNB > 0 ,"Purchase: Price must be greater than zero");
        priceInBNB = _priceInBNB;
        emit SetPrices(_priceInBNB);
    }

    function setPricesX22(uint256 _priceInX22) public onlyOwner() {
        require(_priceInX22 > 0 ,"Purchase: Price must be greater than zero");
        priceInX22 = _priceInX22;
        emit SetPricesX22(_priceInX22);
    }
    
    function setDiscount(uint _discount) public onlyOwner(){
        require(_discount > 0 && _discount <= DENOMINATOR,"Purchase: Discount in not valid ");
        discount = _discount;
        emit SetDiscount(discount);
    }
    
    function setTreasurerAddress(address payable _treasurerAddress) public onlyOwner(){
        require(_treasurerAddress != address(0),"Purchase: _treasurerAddress not be zero address");
        treasurerAddress = _treasurerAddress ;
    }

    function batchNFTCreate(address[] memory _addresses) public onlyOwner(){
        require(_addresses.length != 0,"Purchase: use Valid addresses array ");
        for (uint256 i = 0; i < _addresses.length; i++) {
            nft.mint(_addresses[i]);
        }
    }

    function pause() public onlyOwner(){
        _pause();
    }
    
    function unpause() public onlyOwner(){
        _unpause();
    }
    
    
    function buyWithBNB(uint256 _numberOfToken) public payable nonReentrant() validTokensAmount(_numberOfToken) whenNotPaused(){
        require (_numberOfToken > 0 ,"Purchase: _numberOfToken must be greater than zero");
        require(msg.value >= priceInBNB.mul(_numberOfToken),"Purchase: amount of BNB must be equal to token price" ); 
        uint256 extraAmount = msg.value.sub(priceInBNB.mul(_numberOfToken));
        if(_safeTransferBNB(treasurerAddress,priceInBNB.mul(_numberOfToken))){
            nft.batchMint(msg.sender,_numberOfToken);    
        }
        _safeTransferBNB(msg.sender,extraAmount);
        emit BuyNFTforBNB(msg.sender,priceInBNB.mul(_numberOfToken),_numberOfToken);
    }
    
    function buyWithX22(uint256 amount,uint256 _numberOfToken) public nonReentrant() validTokensAmount(_numberOfToken) whenNotPaused(){
        require (_numberOfToken > 0 ,"Purchase: _numberOfToken must be greater than zero");
        uint256 _amount;
        if(isDiscount){
            _amount = amountToPay().mul(_numberOfToken);
            require(amount >= _amount.mul(9500).div(DENOMINATOR), "Purchase: amount of x22 must be equal to token price");
        }
        else{
            _amount = priceInX22.mul(_numberOfToken);
            require(amount >= _amount, "Purchase: amount of x22 must be equal to token price");
        }
        x22.transferFrom(msg.sender, treasurerAddress, _amount);
        nft.batchMint(msg.sender,_numberOfToken);
        emit BuyNFTforX22(msg.sender,_amount,_numberOfToken);
    }
    
    function amountToPay() public view returns(uint256) {
        uint256 temp = priceInBNB.mul(DENOMINATOR.sub(discount)).div(DENOMINATOR);
        return getPriceInx22(temp);
    }
    
    function getPriceInx22(uint256 _amount) public view returns(uint256){
        (uint256 reserve0,uint256 reserve1,) = x22_bnb_Pair.getReserves();
        uint256 temp = reserve0.mul(10**18).div(reserve1);
        return temp.mul(_amount).div(10**18);
    }
    
    function _safeTransferBNB(address to, uint256 value) internal returns (bool) {
        (bool success, ) = to.call{value: value}(new bytes(0));
        return success;
    }
}