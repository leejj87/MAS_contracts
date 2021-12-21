# MAS_contracts
Polygon
1. 컨트랙 deploy 순서
  1)MAS_WhiteLists.sol (registryAddress)
  2)factory.sol (MAS)
  3)MASRoyalty.sol (royalty)
  
2. 1) MAS_WhiteLists.sol (registryAddress)
    - 민팅 할 수 있는 유저 등록. 컨트랙트 오너만 등록해줄수 있음. register(address)
    - 등록 후, 유저는 민팅 할 수 있는 권한을 가짐.
    - 유저 제거, 또는 유저가 등록되어있는지 확인 함수가 포함되어 있음.
   2) factory.sol(MAS)
    - 컨스트럭터에, _proxyRegistryAddress 는 MAS_WhiteLists.sol 의 컨트랙 주소.
    - transfer_forced() 함수는 컨트렉트 오너가 토큰을 조정 할 수 있음. _to 주소에 0x0000000000000000000000000000000000000000 주소를 넣으면 강제 burn과 같은 역활.
   3) MASRoyalty(royalty)
    - setRoyalty, removeRoyalty 함수로 최초 생성자가 로얄티 설정 가능.
    - 컨트랙트 오너가 로얄티를 조정할수 있음 changeRoyaltySettings
