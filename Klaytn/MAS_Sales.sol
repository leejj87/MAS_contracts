pragma solidity ^0.5.0;
import "./factory.sol";
contract ReentrancyGuard {
    bool private _notEntered;
    constructor () internal {
        // Storing an initial non-zero value makes deployment a bit more
        // expensive, but in exchange the refund on every call to nonReentrant
        // will be lower in amount. Since refunds are capped to a percetange of
        // the total transaction's gas, it is best to keep them low in cases
        // like this one, to increase the likelihood of the full refund coming
        // into effect.
        _notEntered = true;
    }
    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and make it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_notEntered, "ReentrancyGuard: reentrant call");
        // Any calls to nonReentrant after this point will fail
        _notEntered = false;
        _;
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _notEntered = true;
    }
}
contract MAS_Sales is Ownable,ReentrancyGuard,Pausable{
    using SafeMath for uint256;
    MAS private nftAddress;
    mapping(uint256 => uint256) SalesPrice;
    mapping(uint256 => address) RegisteredSeller;
    event logPurchase(uint256 indexed _tokenId,
                    address indexed _buyer,
                    uint256 indexed _buy_price
                    );
    constructor(address _nftAddress) public {
        nftAddress = MAS(_nftAddress);
    }
    function setSales(uint256 _tokenId, uint256 _price) public whenNotPaused{
        require(nftAddress.ownerOf(_tokenId)==msg.sender || msg.sender==owner(),"not a token owner nor contract owner");
        //nftAddress.setApprovalForAll(address(this),true);
        require(nftAddress.isApprovedForAll(msg.sender,address(this)) || nftAddress.getApproved(_tokenId)==address(this),"need permission to the address");
        SalesPrice[_tokenId]=_price;
        RegisteredSeller[_tokenId]=msg.sender;
    }
    function removeSales(uint256 _tokenId) public {
        require(msg.sender != address(0),"address never be 0");
        require(nftAddress.ownerOf(_tokenId)==msg.sender || msg.sender==owner(),"not a token owner nor contract owner");
        SalesPrice[_tokenId]=0;
        RegisteredSeller[_tokenId]=address(0);
    }
    function _royaltyCalculation(uint256 _tokenId,uint256 value) public view returns(uint256){
        uint256 royalty_rate=nftAddress.getRoyalty(_tokenId);
        return (value.mul(royalty_rate)).div(10000);
    }
    function purchased(uint256 _tokenId) public payable nonReentrant whenNotPaused {
        require(SalesPrice[_tokenId]>0,"the price should be more than 0");
        //uint256 royalty = _royaltyCalculation(_tokenId,SalesPrice[_tokenId]);
        //uint256 totalPrice=SalesPrice[_tokenId];
        require(msg.value>=SalesPrice[_tokenId],"the value should be more or equal than salesPrice");
        require(nftAddress.ownerOf(_tokenId) == RegisteredSeller[_tokenId],"token owner does not have token");
        require(msg.sender != nftAddress.ownerOf(_tokenId) && msg.sender != address(0),"owner cannot purchase the own token");
        address payable _owner = address(uint160(owner()));
        _owner.transfer(msg.value);
        nftAddress.safeTransferFrom(RegisteredSeller[_tokenId],msg.sender,_tokenId);
        SalesPrice[_tokenId]=0;
        RegisteredSeller[_tokenId]=address(0);
        emit logPurchase(_tokenId,msg.sender,msg.value);
    }
}
