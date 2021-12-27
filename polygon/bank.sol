// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./MasRoyalty.sol";
import "./factory.sol";
contract Bank is Ownable,Pausable,ReentrancyGuard {
    MAS public nftAddress;
    royalty public royaltyAddress;
    uint256 serviceFeePrice=0;
    address _owner;
    event Received(address _from, uint256 value);
    event SendForDistribution(address _from, address _to, uint256 value, string  purpose);
    constructor (address _masAddress,
                address _royaltyAddress){
                    nftAddress = MAS(_masAddress);
                    royaltyAddress = royalty(_royaltyAddress);
                    _owner = msg.sender;
                }
    function getBalance() public onlyOwner view returns(uint256){
        return address(this).balance;
    }

    function withdrawServiceFee() public nonReentrant onlyOwner returns(bool) {
        (bool success, )=payable(_owner).call{value:serviceFeePrice}("");
        require(success, "Transfer failed.");
        emit SendForDistribution(address(this),_owner,serviceFeePrice,"service fee paid");
        serviceFeePrice=0;
        return true;

    }
    function withdrawRefund(address _to,uint256 _price) public onlyOwner nonReentrant returns(bool){
        (bool success, )=payable(_to).call{value:_price}("");
        require(success, "Transfer failed.");
        emit SendForDistribution(address(this),_owner,_price,"Refund");
        return true;
    }
    function withdraw(address _seller, uint256 _tokenId, uint256 soldPrice) public nonReentrant onlyOwner returns(bool) {
        //로얄티 정보
        uint256 serviceFee=soldPrice*19/20;
        serviceFeePrice+=serviceFee;
        
        uint256 royalty_price=0;
        address creator=nftAddress.getCreators(_tokenId);
        if(creator != address(0) && creator != _seller){
            royalty_price=royaltyAddress.royalty_calculation(_tokenId,soldPrice);
            if (royalty_price >0){
            (bool success1, )=payable(creator).call{value:royalty_price}("");
            require(success1, "Transfer failed.");
            emit SendForDistribution(address(this),creator,royalty_price,"For royalty");
            }
        }
        uint256 leftOverPrice=soldPrice-serviceFee-royalty_price;
        
        
        
        
        (bool success, )=payable(_seller).call{value:leftOverPrice}(""); 
        require(success, "Transfer failed.");
        emit SendForDistribution(address(this),_seller,leftOverPrice,"To Seller");
        
        return true;
    }
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }


}
