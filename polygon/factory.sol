// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;
import "./ERC1155_modifier.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
//import "./MAS_WhiteLists.sol";

abstract contract ContextMixin {
    function msgSender()
        internal
        view
        returns (address payable sender)
    {
        if (msg.sender == address(this)) {
            bytes memory array = msg.data;
            uint256 index = msg.data.length;
            assembly {
                // Load the 32 bytes word from memory with the address on the lower 20 bytes, and mask those.
                sender := and(
                    mload(add(array, index)),
                    0xffffffffffffffffffffffffffffffffffffffff
                )
            }
        } else {
            sender = payable(msg.sender);
        }
        return sender;
    }
}
contract Initializable {
    bool inited = false;

    modifier initializer() {
        require(!inited, "already inited");
        _;
        inited = true;
    }
}
/**
 * https://github.com/maticnetwork/pos-portal/blob/master/contracts/common/EIP712Base.sol
 */
contract EIP712Base is Initializable {
    struct EIP712Domain {
        string name;
        string version;
        address verifyingContract;
        bytes32 salt;
    }

    string constant public ERC712_VERSION = "1";

    bytes32 internal constant EIP712_DOMAIN_TYPEHASH = keccak256(
        bytes(
            "EIP712Domain(string name,string version,address verifyingContract,bytes32 salt)"
        )
    );
    bytes32 internal domainSeperator;

    // supposed to be called once while initializing.
    // one of the contractsa that inherits this contract follows proxy pattern
    // so it is not possible to do this in a constructor
    function _initializeEIP712(
        string memory name
    )
        internal
        initializer
    {
        _setDomainSeperator(name);
    }

    function _setDomainSeperator(string memory name) internal {
        domainSeperator = keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH,
                keccak256(bytes(name)),
                keccak256(bytes(ERC712_VERSION)),
                address(this),
                bytes32(getChainId())
            )
        );
    }

    function getDomainSeperator() public view returns (bytes32) {
        return domainSeperator;
    }

    function getChainId() public view returns (uint256) {
        uint256 id;
        assembly {
            id := chainid()
        }
        return id;
    }

    /**
     * Accept message hash and returns hash message in EIP712 compatible form
     * So that it can be used to recover signer from signature signed using EIP712 formatted data
     * https://eips.ethereum.org/EIPS/eip-712
     * "\\x19" makes the encoding deterministic
     * "\\x01" is the version byte to make it compatible to EIP-191
     */
    function toTypedMessageHash(bytes32 messageHash)
        internal
        view
        returns (bytes32)
    {
        return
            keccak256(
                abi.encodePacked("\x19\x01", getDomainSeperator(), messageHash)
            );
    }
}
/**
 * https://github.com/maticnetwork/pos-portal/blob/master/contracts/common/NativeMetaTransaction.sol
 */
contract NativeMetaTransaction is EIP712Base {
    bytes32 private constant META_TRANSACTION_TYPEHASH = keccak256(
        bytes(
            "MetaTransaction(uint256 nonce,address from,bytes functionSignature)"
        )
    );
    event MetaTransactionExecuted(
        address userAddress,
        address payable relayerAddress,
        bytes functionSignature
    );
    mapping(address => uint256) nonces;

    /*
     * Meta transaction structure.
     * No point of including value field here as if user is doing value transfer then he has the funds to pay for gas
     * He should call the desired function directly in that case.
     */
    struct MetaTransaction {
        uint256 nonce;
        address from;
        bytes functionSignature;
    }

    function executeMetaTransaction(
        address userAddress,
        bytes memory functionSignature,
        bytes32 sigR,
        bytes32 sigS,
        uint8 sigV
    ) public payable returns (bytes memory) {
        MetaTransaction memory metaTx = MetaTransaction({
            nonce: nonces[userAddress],
            from: userAddress,
            functionSignature: functionSignature
        });

        require(
            verify(userAddress, metaTx, sigR, sigS, sigV),
            "Signer and signature do not match"
        );

        // increase nonce for user (to avoid re-use)
        nonces[userAddress] = nonces[userAddress] + 1;

        emit MetaTransactionExecuted(
            userAddress,
            payable(msg.sender),
            functionSignature
        );

        // Append userAddress and relayer address at the end to extract it from calling context
        (bool success, bytes memory returnData) = address(this).call(
            abi.encodePacked(functionSignature, userAddress)
        );
        require(success, "Function call not successful");

        return returnData;
    }

    function hashMetaTransaction(MetaTransaction memory metaTx)
        internal
        pure
        returns (bytes32)
    {
        return
            keccak256(
                abi.encode(
                    META_TRANSACTION_TYPEHASH,
                    metaTx.nonce,
                    metaTx.from,
                    keccak256(metaTx.functionSignature)
                )
            );
    }

    function getNonce(address user) public view returns (uint256 nonce) {
        nonce = nonces[user];
    }

    function verify(
        address signer,
        MetaTransaction memory metaTx,
        bytes32 sigR,
        bytes32 sigS,
        uint8 sigV
    ) internal view returns (bool) {
        require(signer != address(0), "NativeMetaTransaction: INVALID_SIGNER");
        return
            signer ==
            ecrecover(
                toTypedMessageHash(hashMetaTransaction(metaTx)),
                sigV,
                sigR,
                sigS
            );
    }
}


contract MAS is ERC1155_added,Ownable,ContextMixin,NativeMetaTransaction,Pausable{
    using Counters for Counters.Counter;
    Counters.Counter private _currentTokenID;
    //registryAddress private userRegistryAddress;
    mapping (uint256 => address) private creators;
    mapping (uint256 => uint256) private tokenSupply;
    mapping (uint256 => bool) public tokenNFT;
    mapping (uint256 => string) private _mapURI;
    string  names;
    string  symbols;
    /**
    * @dev Require msg.sender to be the creator of the token id
    */
    modifier creatorOnly(uint256 _id) {
        require(creators[_id] == _msgSender(), "ERC1155Tradable#creatorOnly: ONLY_CREATOR_ALLOWED");
        _;
    }
    /**
    * @dev Require msg.sender to own more than 0 of the token id
    */
    modifier ownersOnly(uint256 _tokenId) {
        require(balanceOf(_msgSender(),_tokenId) > 0, "ERC1155Tradable#ownersOnly: ONLY_OWNERS_ALLOWED");
        _;
    }

    // modifier registeredUsers() {
    //     require(userRegistryAddress.isRegistered(_msgSender()),"only Registered users");
    //     _;
    // }
    constructor(
        string memory _name,
        string memory _symbol,
        //address _proxyRegistryAddress,
        string memory _uri
        ) ERC1155_added(_uri)  {
        names = _name;
        symbols = _symbol;
        _initializeEIP712(names);
        //userRegistryAddress = registryAddress(_proxyRegistryAddress);
    }
    function name() external view returns (string memory) {
    return names;
    }

    function symbol() external view returns (string memory) {
        return symbols;
    }

    function getCreators(uint256 _tokenId) external view returns(address){
        return creators[_tokenId];
    }
    //1155:0xd9b67a26, 2981 0x2a55205a
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1155_added)
        returns (bool)
        {
        return
            ERC1155_added.supportsInterface(interfaceId);
        }
    //토큰이 존재하는지 체크
    function _exists(uint256 _id) internal view returns (bool) {
        return creators[_id] != address(0);
    }
    
    //발행된 현재 토큰 수량 id 별
    function totalSupply(uint256 _id) public view returns (uint256) {
        return tokenSupply[_id];
    }    

    // 배치 nft 발행 1st
    function mintBatch_by_Owner_1st(address _to, uint256 n_generates,uint256 [] memory _amounts, bool [] memory _nfts, string [] memory _uris) public onlyOwner whenNotPaused{
        require(_to != address(0),"To address should not be 0");
        require(n_generates==_nfts.length && n_generates==_uris.length,"the array length is not matched");
        uint256[] memory new_tokens = new uint256[](n_generates);
        for (uint256 i=0; i<n_generates;i++){
            _currentTokenID.increment();
            uint256 _tokenId = _currentTokenID.current();
            new_tokens[i]=_tokenId;
            if(_nfts[i]==true){
                require(_amounts[i]==1,"NFT token should set the amount as 1");
            }
            tokenNFT[_tokenId]=_nfts[i];
            seturi(_tokenId,_uris[i]);
            creators[_tokenId]=_to;
            tokenSupply[_tokenId]+=_amounts[i];
        }
        _mintBatch(_to,new_tokens,_amounts,"");//배치 민트

    }
    // 배치 nft 발행 additional
    function min_byAnyOneBatch_additional(address _to,uint256 [] memory _tokenIds, uint256 [] memory _amounts) public whenNotPaused onlyOwner{
        require(_to != address(0),"To address should not be 0");
        require(_tokenIds.length==_amounts.length,"the length of array is not matched");
        for (uint256 i=0; i<_tokenIds.length;i++){
            require(creators[_tokenIds[i]]==_to,"Only token Owners generate additional Token");
            require(tokenNFT[_tokenIds[i]]==false,"NFT Unable to generate additional Token");
            tokenSupply[_tokenIds[i]]+=_amounts[i];
        }
        _mintBatch(_to,_tokenIds,_amounts,"");
    }
     function getCurrentToken() public view returns(uint256){
        return _currentTokenID.current();        
    }
    //only token Owner
    function burn(address _to,uint256 _tokenId,uint256 _burnAmount) public onlyOwner whenNotPaused {
        require(balanceOf(_to,_tokenId)>0,"To address should own the tokens");
        if (balanceOf(_to,_tokenId)<_burnAmount){
            _burnAmount=balanceOf(_to,_tokenId);
        }
        _burn(_to,_tokenId,_burnAmount);
        tokenSupply[_tokenId]-=_burnAmount;
        
        if (tokenSupply[_tokenId]==0){
        seturi(_tokenId,"");
        tokenNFT[_tokenId]=false;
        creators[_tokenId]=address(0);
        }
    }
    // onlye token Creator
    function seturi(uint256 _tokenId, string memory _uri) private {
        _mapURI[_tokenId]=_uri;
    }
    
    function uri(uint256 _tokenId) public override view returns(string memory){
        return _mapURI[_tokenId];
    }
    
    /**
   * Override isApprovedForAll to auto-approve OS's proxy contract
   */
    function isApprovedForAll(
        address _owner,
        address _operator
    ) public override view returns (bool isOperator) {
        // if OpenSea's ERC1155 Proxy Address is detected, auto-return true
       if (_operator == address(0x207Fa8Df3a17D96Ca7EA4f2893fcdCb78a304101)) {
            return true;
        }
        // otherwise, use the default ERC1155.isApprovedForAll()
        return ERC1155_added.isApprovedForAll(_owner, _operator);
    }
    function _msgSender()
        internal
        override
        view
        returns (address sender)
    {
        return ContextMixin.msgSender();
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
    //오너가 강제로 트렌스퍼 가능
    //만약 0x0000000000000000000000000000000000000000 으로 트랜스퍼 하면 burn.
    function transfer_forced(
        address from,
        address to,
        uint256 id,
        uint256 amount) public onlyOwner {
            safeTransferByOwner(from,to,id,amount,"");
            if (to==address(0)){
                tokenSupply[id]-=amount;
                tokenNFT[id]=false;
                creators[id]=address(0);
                seturi(id,"");
            }
        }
}
