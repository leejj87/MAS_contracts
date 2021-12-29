// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;
import "./factory.sol";
import "./whiteLists.sol";
import "https://github.com/dievardump/EIP2981-implementation/blob/main/contracts/ERC2981PerTokenRoyalties.sol";
contract royalty is ERC2981PerTokenRoyalties{
    MAS private nftAddress;
    WhiteLists private whiteListsAddress;
    struct Royalty_data {
        uint16 royalty_percentage;
        bool royalty_set;
    } 
    mapping (uint256 => Royalty_data) royaltyInfo;
    modifier whiteUsersOnly(){
        require(whiteListsAddress.getWhiteLists(1,msg.sender)==true,"operators in the whitelist only");
        _;
    }
    event royalty_record(address who_triggered,uint256 tokenId,uint16 royaltySetup);
    
    constructor (address _nftAddress,
                address _whiteListsAddress){
        nftAddress = MAS(_nftAddress);
        whiteListsAddress = WhiteLists(_whiteListsAddress);
    }
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC2981Base)
        returns (bool)
        {
        return
            ERC2981Base.supportsInterface(interfaceId);
        }
    function getRoyalty(uint256 _tokenId) public view returns(uint16) {
        if(royaltyInfo[_tokenId].royalty_set == true){
            return royaltyInfo[_tokenId].royalty_percentage;
        }else{
            return 0;
        }
    }
    //로얄티 계산
    function royalty_calculation(uint256 _token_Id, uint256 _price) public view returns(uint256){
        uint256 royaltyRate=0;
        if (royaltyInfo[_token_Id].royalty_set){
            royaltyRate=royaltyInfo[_token_Id].royalty_percentage;
        }else{
            royaltyRate=0;
        }
        
        return (_price*royaltyRate)/10000;
    }
    function changeRoyaltySettings(uint256 _tokenId,uint16 _new_royalty, bool _royalty) public whiteUsersOnly{
        royaltyInfo[_tokenId].royalty_percentage=_new_royalty;
        royaltyInfo[_tokenId].royalty_set=_royalty;
        address creator = nftAddress.getCreators(_tokenId);
        emit royalty_record(creator,_tokenId,_new_royalty);
    }
    function setRoyalty(uint256 _tokenId,uint16 _royalties) public whiteUsersOnly{
        //only original owner can set the royalty!
        //royalties 0%=>0,10% => 1000, 50% => 5000,100% => 10000
        require(_royalties>0,"royalties should set more than 0");//set proper values for royalty not 0
        address creator = nftAddress.getCreators(_tokenId);
        _setTokenRoyalty(_tokenId,creator,_royalties);
        royaltyInfo[_tokenId]=Royalty_data(_royalties,true);
        emit royalty_record(creator,_tokenId,_royalties);
        }
    function removeRoyalty(uint256 _tokenId) public whiteUsersOnly{
        address creator = nftAddress.getCreators(_tokenId);
        _setTokenRoyalty(_tokenId,creator,0);
        royaltyInfo[_tokenId]=Royalty_data(0,false);
        emit royalty_record(creator,_tokenId,0);
    }
}
