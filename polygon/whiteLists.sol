// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";


contract WhiteLists is Ownable, Pausable {
    //0:minting, 1:royalty 2:bank 3:purchase
    mapping(uint256=>mapping(address=>bool)) white_lists;
    constructor(){
        setWhiteLists(0,msg.sender,true);
        setWhiteLists(1,msg.sender,true);
        setWhiteLists(2,msg.sender,true);
        setWhiteLists(3,msg.sender,true);
    }
    function setWhiteLists(uint256 _type,address _address, bool _allow) public onlyOwner {
        white_lists[_type][_address]=_allow;
    }

    function getWhiteLists(uint256 _type,address _address) public view returns(bool){
        return white_lists[_type][_address];
    }

    function pause() public onlyOwner {
        _pause();
    }
    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function unpause() public onlyOwner{
        _unpause();
    }



}
