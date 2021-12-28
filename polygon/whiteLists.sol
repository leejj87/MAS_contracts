// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";


contract WhiteLists is Ownable, Pausable {

    mapping(address=>bool) white_lists;
    constructor(){
        setWhiteLists(msg.sender,true);
    }
    function setWhiteLists(address _address, bool _allow) public onlyOwner {
        white_lists[_address]=_allow;
    }

    function getWhiteLists(address _address) public view returns(bool){
        return white_lists[_address];
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
