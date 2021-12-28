# MAS_contracts
Polygon
1. 컨트랙 deploy 순서
  1)whiteLists.sol(whitelist)
  2)factory.sol (MAS)
  3)MASRoyalty.sol (royalty)
  4)bank.sol(Bank)
  5)Sales.sol
  
2. 1) factory.sol(MAS)
    - transfer_forced() 함수는 컨트렉트 오너가 토큰을 조정 할 수 있음. _to 주소에 0x0000000000000000000000000000000000000000 주소를 넣으면 강제 burn과 같은 역활.
   2) MASRoyalty(royalty)
    - nftAddress는 1 factory 컨트랙트 주소
    - setRoyalty, removeRoyalty 함수로 최초 생성자가 로얄티 설정 가능.
    - 컨트랙트 오너가 로얄티를 조정할수 있음 changeRoyaltySettings
    3)bank.sol
    - nft address 와 royalty address 필요함.
    - withdraw (seller address, token Id, sold price) ==> 팔리고 난 후, 로얄티, 판매자에게 자동 분배
    - withdrawServiceFee ==> 판매 수수료 한번에 오너에게 전송
    3)Sales.sol
     - nft address 와 bank address 필요함
      -setSales 하기 전에 factory 컨트랙트에서 setApproveForAll 함수 사용하여서 사용자가, Sales 컨트랙 주소로 true를 설정해줘야 함.
      
Klaytn
1. 컨트랙 deploy 순서
   1) factory.sol(MAS)
   2) bank.sol
   3) Sales_MAS.sol
  MAS
  1. 기능
     1)민팅
     2)로얄티 세팅
     3)Burn & 강제 트랜스퍼 by Contract Owner
     4)ERC721 기본 함수 사용.
  2. Deploy
     1)Name & Symbol 입력.
  4.	Functions
    1)	Getter
      a.	getCreators(uint256 _tokenId) public view returns(address)
        i.	최초 토큰 생성자 주소 리턴
      b.	getRoyalty(uint256 _tokenId) public view returns(uint16)
        i.	로얄티 % 리턴
      c.	royalty_calculation(uint256 _tokenId,uint256 _price) public view returns(uint256)
        i.	로얄티 계산 결과
    2)	Setter
      a.	setRoyaltyByContract(uint256 _tokenId, uint16 _setUpRate) public onlyOwner
        i.	로얄티 수정. 단 소숫점을 제공 안함. 100%=>10000,10%=>1000,0%=>0
      b.	setRoyalty(address _to,uint256 _tokenId, uint16 _setUpRate) public onlyOwner
        i.	로얄티 최초 입력.
    3)	일반 함수
      a.	mint_by_owner(address _to, string memory _uri) public onlyOwner
        i.	NFT 민트 함수
      b.	transferFromByOwner(address from, address to, uint256 tokenId) public onlyOwner
        i.	오너 강제 NFT 이동.
        ii.	Burn 시킬 경우, address(0) 을 입력. 


