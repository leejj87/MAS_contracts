# MAS_contracts
Polygon
1. 컨트랙 deploy 순서
  1)factory.sol (MAS)
  2)MASRoyalty.sol (royalty)
  3)bank.sol(Bank)
  4)Sales.sol
  
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
2. factory.sol(MAS)
   - 컨트랙트 오너가 전부 처리함.
   - 로얄티 세팅

