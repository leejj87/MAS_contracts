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


contract bank is Ownable,ReentrancyGuard,Pausable{
    using SafeMath for uint256;
    MAS private nftAddress;
    uint256 serviceFeePrice=0;
    address _owner;
    event Received(address _from, uint256 value);
    event SendForDistribution(address _from, address _to, uint256 value, string  purpose);
    constructor(address _nftAddress) public {
        nftAddress = MAS(_nftAddress);
        _owner=msg.sender;
    }

    function() external payable {
        emit Received(msg.sender, msg.value);
    }
    function getBalance() public onlyOwner view returns(uint256){
        return address(this).balance;
    }
    function withdrawServiceFee() public nonReentrant onlyOwner whenNotPaused returns(bool) {
        address payable owner = address(uint160(_owner));
        (bool success, )=owner.call.value(serviceFeePrice)("");
        require(success, "Transfer failed.");
        emit SendForDistribution(address(this),_owner,serviceFeePrice,"service fee paid");
        serviceFeePrice=0;
        return true;

    }
    function withdrawRefund(address _to,uint256 _price) public onlyOwner nonReentrant whenNotPaused returns(bool){
        address payable to = address(uint160(_to));
        (bool success, )=to.call.value(_price)("");
        require(success, "Transfer failed.");
        emit SendForDistribution(address(this),_to,_price,"Refund");
        return true;
        }



    function withdraw(address _seller, uint256 _tokenId, uint256 soldPrice) public nonReentrant onlyOwner whenNotPaused returns(bool) {
        //로얄티 정보
        uint256 serviceFee=(soldPrice.mul(1)).div(20);
        serviceFeePrice=serviceFeePrice.add(serviceFee);
        uint256 royalty_price=0;
        address creator=nftAddress.getCreators(_tokenId);
        if(creator != address(0) && creator != _seller){
            royalty_price=nftAddress.royalty_calculation(_tokenId,soldPrice);
            if (royalty_price >0){
            address payable _creator = address(uint160(creator));
            (bool success1, )=_creator.call.value(royalty_price)("");
            require(success1, "Transfer failed.");
            emit SendForDistribution(address(this),creator,royalty_price,"For royalty");
            }
        }
        uint256 leftOverPrice=soldPrice-serviceFee-royalty_price;
        address payable seller = address(uint160(_seller));
        (bool success, )=seller.call.value(leftOverPrice)(""); 
        require(success, "Transfer failed.");
        emit SendForDistribution(address(this),_seller,leftOverPrice,"To Seller");
        
        return true;
    }

}
