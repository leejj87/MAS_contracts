pragma solidity ^0.5.0;
import "./factory.sol";
import "./bank.sol";
import "./whiteLists.sol";
contract MAS_Sales is Ownable,ReentrancyGuard,Pausable{
    using SafeMath for uint256;
    MAS private nftAddress;
    address private bankAddress;
    bank private bankProxy;
    WhiteLists private whiteListsAddress;
    mapping(uint256 => uint256) SalesPrice;
    mapping(uint256 => address) RegisteredSeller;
    event logPurchase(uint256 indexed _tokenId,
                    address indexed _buyer,
                    uint256 indexed _buy_price
                    );
    constructor(address _nftAddress,
                address payable _bankAddress,
                address _whiteLIstsAddress) public {
        nftAddress = MAS(_nftAddress);
        bankAddress = _bankAddress;
        bankProxy = bank(_bankAddress);
        whiteListsAddress = WhiteLists(_whiteLIstsAddress);
    }
    modifier whiteUsersOnly(){
        require(whiteListsAddress.getWhiteLists(3,_msgSender())==true,"operators in the whitelist only");
        _;
    }
    function setSales(address _to,uint256 _tokenId, uint256 _price) public whiteUsersOnly whenNotPaused{
        require(nftAddress.ownerOf(_tokenId)==_to,"not a token owner nor contract owner");
        //nftAddress.setApprovalForAll(address(this),true);
        require(nftAddress.isApprovedForAll(_to,address(this)),"need permission to the address");
        SalesPrice[_tokenId]=_price;
        RegisteredSeller[_tokenId]=_to;
    }
    function removeSales(address _to, uint256 _tokenId) public whiteUsersOnly{
        require(_to != address(0),"address never be 0");
        require(nftAddress.ownerOf(_tokenId)==_to,"not a token owner nor contract owner");
        SalesPrice[_tokenId]=0;
        RegisteredSeller[_tokenId]=address(0);
    }
    //1000000000000000000
    function purchased(uint256 _tokenId) public payable nonReentrant whenNotPaused returns(uint256){
        require(SalesPrice[_tokenId]>0,"the price should be more than 0");
        //uint256 royalty = _royaltyCalculation(_tokenId,SalesPrice[_tokenId]);
        //uint256 totalPrice=SalesPrice[_tokenId];
        require(msg.value>=SalesPrice[_tokenId],"the value should be more or equal than salesPrice");
        require(nftAddress.ownerOf(_tokenId) == RegisteredSeller[_tokenId],"token owner does not have token");
        require(msg.sender != nftAddress.ownerOf(_tokenId) && msg.sender != address(0),"owner cannot purchase the own token");
        address _seller = nftAddress.ownerOf(_tokenId);
        address payable bank = address(uint160(bankAddress));
        (bool success, )=bank.call.value(msg.value)("");
        require(success, "Transfer failed.");
        nftAddress.safeTransferFrom(RegisteredSeller[_tokenId],msg.sender,_tokenId);
        SalesPrice[_tokenId]=0;
        RegisteredSeller[_tokenId]=address(0);
        emit logPurchase(_tokenId,msg.sender,msg.value);
        return bankProxy.deposit(_tokenId,msg.sender,_seller,msg.value);
    }
    function pause() public whiteUsersOnly {
        pause();
    }
    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function unpause() public whiteUsersOnly{
        unpause();
    }
}
