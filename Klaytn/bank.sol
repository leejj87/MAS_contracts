pragma solidity ^0.5.0;
import "./factory.sol";
import "./whiteLists.sol";
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
    using Counters for Counters.Counter;
    Counters.Counter private _accountIDX;
    MAS private nftAddress;
    WhiteLists private whiteListsAddress;
    uint256 serviceFeePrice;
    address _owner;
    address _salesAddress;
    event Received(address _from, uint256 value);
    event SendForDistribution(address _from, address _to, uint256 value, string  purpose);
    struct accountDetail{
        uint256 _tokenId;
        address _buyer;
        address _seller;
        uint256 _sentPrice;
        bool _distributed;
        bool _reported;
    }
    mapping (uint256 => accountDetail) account;
    constructor(address _nftAddress,address _whiteLIstsAddress) public {
        nftAddress = MAS(_nftAddress);
        _owner=msg.sender;
        serviceFeePrice=0;
        whiteListsAddress = WhiteLists(_whiteLIstsAddress);
    }
    modifier whiteUsersOnly(){
        require(whiteListsAddress.getWhiteLists(2,_msgSender())==true,"operators in the whitelist only");
        _;
    }
    function setSalesContract(address salesContract) public whiteUsersOnly{
        _salesAddress = salesContract;
    }


    function deposit(uint256 _tokenId,address _buyer,address _seller,uint256 _priceSent) public nonReentrant whenNotPaused returns(uint256){
        require(_salesAddress==msg.sender,"sender is not matched");
        _accountIDX.increment();
        uint256 _current= _accountIDX.current();
        account[_current]._tokenId=_tokenId;
        account[_current]._buyer=_buyer;
        account[_current]._seller=_seller;
        account[_current]._sentPrice=_priceSent;
        account[_current]._distributed=false;
        account[_current]._reported=false;
        return _current;
    }


    function() external payable {
        emit Received(msg.sender, msg.value);
    }
    function getBalance() public onlyOwner view returns(uint256){
        return address(this).balance;
    }
    function getserviceFee() public onlyOwner view returns(uint256){
        return serviceFeePrice;
    }
    function getAccount_tokenId(uint256 _accountIdx) public onlyOwner view returns(uint256){
        return account[_accountIdx]._tokenId;
    }
    function getAccount_buyer(uint256 _accountIdx) public onlyOwner view returns(address){
        return account[_accountIdx]._buyer;
    }
    function getAccount_seller(uint256 _accountIdx) public onlyOwner view returns(address){
        return account[_accountIdx]._seller;
    }
    function getAccount_price(uint256 _accountIdx) public onlyOwner view returns(uint256){
        return account[_accountIdx]._sentPrice;
    } 
    function getAccount_distributed(uint256 _accountIdx) public onlyOwner view returns(bool){
        return account[_accountIdx]._distributed;
    } 
    function getAccount_reported(uint256 _accountIdx) public onlyOwner view returns(bool){
        return account[_accountIdx]._reported;
    } 
    function withdrawServiceFee() public nonReentrant whiteUsersOnly whenNotPaused returns(bool) {
        address payable owner = address(uint160(_owner));
        (bool success, )=owner.call.value(serviceFeePrice)("");
        require(success, "Transfer failed.");
        emit SendForDistribution(address(this),_owner,serviceFeePrice,"service fee paid");
        serviceFeePrice=0;
        return true;
    }
    function setReported(uint256 _accountIdx) public whiteUsersOnly nonReentrant whenNotPaused {
        account[_accountIdx]._reported=true;
    }
    function setRemoveReported(uint256 _accountIdx) public whiteUsersOnly nonReentrant whenNotPaused{
        account[_accountIdx]._reported=false;
    }
    function withdrawRefund(uint256 _accountIdx) public whiteUsersOnly nonReentrant whenNotPaused returns(bool){
        require(account[_accountIdx]._reported==true,"this transaction is not reported");
        address buyer = account[_accountIdx]._buyer;
        uint256 refundPrice = account[_accountIdx]._sentPrice;
        address payable _buyer = address(uint160(buyer));
        (bool success, )=_buyer.call.value(refundPrice)("");
        require(success, "Transfer failed.");
        return true;
        }
    


    function withdraw(uint256 _depositId, uint256 _tokenId) public nonReentrant whiteUsersOnly whenNotPaused returns(bool) {
        require(account[_depositId]._distributed==false && account[_depositId]._reported==false,"the deposit already either distributed or reported");
        require(account[_depositId]._tokenId==_tokenId,"token Id and bankAccount are not matched");
        uint256 _soldPriced = account[_depositId]._sentPrice;
        uint256 serviceFee=(_soldPriced.mul(1)).div(20);
        serviceFeePrice=serviceFeePrice.add(serviceFee);
        uint256 royalty_price=0;
        address creator=nftAddress.getCreators(_tokenId);
        address _seller = account[_depositId]._seller;
        if(creator != address(0) && creator != _seller){
            royalty_price=nftAddress.royalty_calculation(_tokenId,_soldPriced);
            if (royalty_price >0){
            address payable _creator = address(uint160(creator));
            (bool success1, )=_creator.call.value(royalty_price)("");
            require(success1, "Transfer failed.");
            emit SendForDistribution(address(this),creator,royalty_price,"For royalty");
            }
        }
        uint256 leftOverPrice=_soldPriced-serviceFee-royalty_price;
        
        address payable seller = address(uint160(_seller));
        (bool success, )=seller.call.value(leftOverPrice)(""); 
        require(success, "Transfer failed.");
        emit SendForDistribution(address(this),_seller,leftOverPrice,"To Seller");
        account[_depositId]._distributed=true;
        return true;
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
