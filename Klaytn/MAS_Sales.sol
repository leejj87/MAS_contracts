pragma solidity ^0.5.0;
import "./factory.sol";
import "./bank.sol";
contract MAS_Sales is Ownable,ReentrancyGuard,Pausable{
    using SafeMath for uint256;
    MAS private nftAddress;
    address private bankAddress;
    mapping(uint256 => uint256) SalesPrice;
    mapping(uint256 => address) RegisteredSeller;
    event logPurchase(uint256 indexed _tokenId,
                    address indexed _buyer,
                    uint256 indexed _buy_price
                    );
    constructor(address _nftAddress,
                address _bankAddress) public {
        nftAddress = MAS(_nftAddress);
        bankAddress = _bankAddress;
    }
    function setSales(address _to,uint256 _tokenId, uint256 _price) public onlyOwner whenNotPaused{
        require(nftAddress.ownerOf(_tokenId)==_to,"not a token owner nor contract owner");
        //nftAddress.setApprovalForAll(address(this),true);
        require(nftAddress.isApprovedForAll(_to,address(this)),"need permission to the address");
        SalesPrice[_tokenId]=_price;
        RegisteredSeller[_tokenId]=_to;
    }
    function removeSales(address _to, uint256 _tokenId) public onlyOwner{
        require(_to != address(0),"address never be 0");
        require(nftAddress.ownerOf(_tokenId)==_to,"not a token owner nor contract owner");
        SalesPrice[_tokenId]=0;
        RegisteredSeller[_tokenId]=address(0);
    }
    //1000000000000000000
    function purchased(uint256 _tokenId) public payable nonReentrant whenNotPaused {
        require(SalesPrice[_tokenId]>0,"the price should be more than 0");
        //uint256 royalty = _royaltyCalculation(_tokenId,SalesPrice[_tokenId]);
        //uint256 totalPrice=SalesPrice[_tokenId];
        require(msg.value>=SalesPrice[_tokenId],"the value should be more or equal than salesPrice");
        require(nftAddress.ownerOf(_tokenId) == RegisteredSeller[_tokenId],"token owner does not have token");
        require(msg.sender != nftAddress.ownerOf(_tokenId) && msg.sender != address(0),"owner cannot purchase the own token");
        address payable bank = address(uint160(bankAddress));
        (bool success, )=bank.call.value(msg.value)("");
        require(success, "Transfer failed.");
        nftAddress.safeTransferFrom(RegisteredSeller[_tokenId],msg.sender,_tokenId);
        SalesPrice[_tokenId]=0;
        RegisteredSeller[_tokenId]=address(0);
        emit logPurchase(_tokenId,msg.sender,msg.value);
    }
}
