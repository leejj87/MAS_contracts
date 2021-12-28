// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./Mas_Royalty.sol";
import "./factory.sol";
import "./whiteLists.sol";
contract Bank is Ownable,Pausable,ReentrancyGuard {
    using Counters for Counters.Counter;
    Counters.Counter private _accountIDX;
    MAS public nftAddress;
    royalty public royaltyAddress;
    WhiteLists private whiteListsAddress;
    uint256 serviceFeePrice;
    address _owner;
    address _salesAddress;
    event Received(address _from, uint256 value);
    event SendForDistribution(address _from, address _to, uint256 value, string  purpose);
    constructor (address _masAddress,
                address _royaltyAddress,
                address _whiteListsAddress){
                    nftAddress = MAS(_masAddress);
                    royaltyAddress = royalty(_royaltyAddress);
                    _owner = msg.sender;
                    serviceFeePrice=0;
                    whiteListsAddress = WhiteLists(_whiteListsAddress);
                }
    modifier whiteUsersOnly(){
        require(whiteListsAddress.getWhiteLists(_msgSender())==true,"operators in the whitelist only");
        _;
    }
    struct accountDetail{
        uint256 _tokenId;
        address _buyer;
        address _seller;
        uint256 _sendPrice;
        bool _distributed;
        bool _reported;
    }
    mapping (uint256 => accountDetail) account;

    function setSalesContract(address salesContract) public whiteUsersOnly {
        _salesAddress = salesContract;
    }

    function deposit(uint256 _tokenId, address _buyer, address _seller, uint256 _priceSent) public nonReentrant whenNotPaused returns(uint256){
        require(_salesAddress==msg.sender,"sender is not matched");
        _accountIDX.increment();
        uint256 _current = _accountIDX.current();
        account[_current]._tokenId=_tokenId;
        account[_current]._buyer=_buyer;
        account[_current]._seller=_seller;
        account[_current]._sendPrice=_priceSent;
        account[_current]._distributed=false;
        account[_current]._reported=false;
        return _current;
    }


    function getBalance() public whiteUsersOnly view returns(uint256){
        return address(this).balance;
    }
    function getserviceFee() public whiteUsersOnly view returns(uint256){
        return serviceFeePrice;
    }
    function getAccount_tokenId(uint256 _accountIdx) public whiteUsersOnly view returns(uint256){
        return account[_accountIdx]._tokenId;
    }
    function getAccount_buyer(uint256 _accountIdx) public whiteUsersOnly view returns(address){
        return account[_accountIdx]._buyer;
    }
    function getAccount_seller(uint256 _accountIdx) public whiteUsersOnly view returns(address){
        return account[_accountIdx]._seller;
    }
    function getAccount_price(uint256 _accountIdx) public whiteUsersOnly view returns(uint256){
        return account[_accountIdx]._sendPrice;
    } 
    function getAccount_distributed(uint256 _accountIdx) public whiteUsersOnly view returns(bool){
        return account[_accountIdx]._distributed;
    } 
    function getAccount_reported(uint256 _accountIdx) public whiteUsersOnly view returns(bool){
        return account[_accountIdx]._reported;
    } 
    function withdrawServiceFee() public nonReentrant whiteUsersOnly returns(bool) {
        (bool success, )=payable(_owner).call{value:serviceFeePrice}("");
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
    //refund if only if the NFT is reported as outlawed
    function withdrawRefund(uint256 _accountIdx) public whiteUsersOnly nonReentrant whenNotPaused returns(bool){
        require(account[_accountIdx]._reported==true,"this transaction is not reported");
        address buyer = account[_accountIdx]._buyer;
        uint256 refundPrice = account[_accountIdx]._sendPrice;
        (bool success, )=payable(buyer).call{value:refundPrice}("");
        require(success, "Transfer failed.");
        return true;
    }
    function withdraw(uint256 _depositId, uint256 _tokenId) public nonReentrant whenNotPaused whiteUsersOnly returns(bool) {
        //로얄티 정보
        require(account[_depositId]._distributed==false && account[_depositId]._reported==false,"the deposit already either distributed or reported");
        require(account[_depositId]._tokenId==_tokenId,"token Id and banckAccount are not matched");
        uint256 _soldPrice = account[_depositId]._sendPrice;
        uint256 serviceFee=_soldPrice*1/20;
        serviceFeePrice+=serviceFee;
        uint256 royalty_price=0;
        address creator=nftAddress.getCreators(_tokenId);
        address _seller = account[_depositId]._seller;
        require(_seller != address(0),"seller address is 0");
        if(creator != address(0) && creator != _seller){
            royalty_price=royaltyAddress.royalty_calculation(_tokenId,_soldPrice);
            if (royalty_price >0){
            (bool success1, )=payable(creator).call{value:royalty_price}("");
            require(success1, "Transfer failed.");
            emit SendForDistribution(address(this),creator,royalty_price,"For royalty");
            }
        }
        uint256 leftOverPrice=_soldPrice-serviceFee-royalty_price;
        
        
        
        
        (bool success, )=payable(_seller).call{value:leftOverPrice}(""); 
        require(success, "Transfer failed.");
        emit SendForDistribution(address(this),_seller,leftOverPrice,"To Seller");
        account[_depositId]._distributed=true;
        return true;
    }
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }
    function pause() public whiteUsersOnly {
        _pause();
    }
    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function unpause() public whiteUsersOnly{
        _unpause();
    }

}
