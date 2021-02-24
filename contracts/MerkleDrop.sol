pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "./MerkleProof.sol";
import "./IERC20.sol";
import "./SafeMath.sol";
import "./Ownable.sol";

contract TokenVault {
    address public owner;
    address public token;

    constructor(address _owner, address _token) public {
        owner = _owner;
        token = _token;
    }
     /**
     * @dev transfers token to 'whom' address with 'amount'.
     */
    function transferToken(address _whom, uint256 _amount)
        public
        returns (bool)
    {
        require(msg.sender == owner, "caller should be owner");
        safeTransfer(_whom, _amount);
        return true;
    }

    function safeTransfer(address to, uint256 value) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))),"TransferHelper: TRANSFER_FAILED" );
    }
}

abstract contract MerkleDropStorage {
    
    /**
     *  airdropCreator - token airdropCreator
     * 'tokenAddress '  - token's contract address
     *  'amount' - amount of tokens to be airdropped
     *  'rootHash' -  merkle root hash
     *  'airdropDate' - airdrop creation date
     *  'airdropExpirationDate'- token's airdrop Exipration Date
     */
    struct MerkleAirDrop {
        address airdropCreator; 
        address tokenAddress; 
        bytes32 rootHash; 
        uint256 amount; 
        uint256 airdropStartDate; 
        uint256 airdropExpirationDate;
       
    }
    
    //Events
    event AirDropSubmitted(
        address indexed _airdropCreator,
        address indexed _token,
        uint256 _amount,
        uint256 _airdropDate,
        uint256 _airdropExpirationDate
    );

    event Claimed(address indexed account, uint256 amount, address vault);

    //Mapping
    mapping(address => MerkleAirDrop) public airdroppedtokens;
    mapping(address => mapping(uint256 => bool)) public claimedMap;
    mapping(bytes32 => address) public vaultAddress;
    
}

contract MerkleDrop is MerkleDropStorage,SafeMath,Ownable {
    using MerkleProof for bytes32[];
    
    address public tokenAddress;
    
    uint256 public feeInToken;
    
    uint256 public feeInEth;
    
    address public walletAddress;
    
    constructor(address _token,uint256 _feeToken,uint256 _feeEth,address _walletAddress)public{
        tokenAddress = _token;
        feeInToken = _feeToken;
        feeInEth = _feeEth;
        walletAddress = _walletAddress;
    }
    
    //To perform safe transfer of token
    function safeTransferFrom(
        address _token,
        address from,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = _token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))),"TransferHelper: TRANSFER_FROM_FAILED");
    }
    
    /**
     * @dev creates token airdrop.
     * 
     * @param
     * ' _token '  - token's contract address
     *  ' _amount' - amount of tokens to be airdropped
     *  '_root' -  merkle root hash
     *  '_airdropStartDate' airdrop start date
     *  '_airdropExpirationDate'- token's airdrop Exipration Date
     *  '_paymentInToken' - pay in tokens
     */
    function createAirDrop(
        address _token, 
        uint256 _amount, 
        bytes32 _root, 
        uint256  _airdropStartDate,
        uint256 _airdropExpirationDate,
        bool _paymentInToken
    ) external payable returns (bool) {
        if(_paymentInToken){
            IERC20(tokenAddress).transferFrom(msg.sender,walletAddress,feeInToken);
        }
        else{
            (bool success,) = walletAddress.call{value:feeInEth}(new bytes(0));
            require(success,"ERR_TRANSFER_FAILED");
        }
        require(vaultAddress[_root] == address(0),"ERR_HASH_ALREADY_CREATED");
        TokenVault vault = new TokenVault(address(this), _token);
        safeTransferFrom(_token, msg.sender, address(vault), _amount);
        MerkleAirDrop memory merkledrop = MerkleAirDrop(msg.sender,_token, _root,_amount,_airdropStartDate,_airdropExpirationDate);
        airdroppedtokens[address(vault)] = merkledrop;
        vaultAddress[_root] = address(vault);
        emit AirDropSubmitted(msg.sender,_token,_amount,now,_airdropExpirationDate);
        return true;
    }

    //To set token fee 
    function setTokenFee(uint256 _fee) external onlyOwner(){
        feeInToken = _fee;
    }
    
    //To set eth fee
    function setEthFee(uint256 _fee) external onlyOwner(){
        feeInEth = _fee;
    }
    
    //To set walletAddress
    function setWalletAddress(address _walletAddress)external onlyOwner(){
        walletAddress = _walletAddress;
    }
    
     /**
     * @dev to claim the airdropped tokens.
     * 
     *  @param
     * ' _hex'  - hex bytes
     *  ' _proof' - merkle proof
     *  'index' - address index
     *  '_amount' -  amount of token to be claimed
     */
    function claim(
        bytes32[] memory _hex,
        bytes32[][] memory _proof,
        uint256[] memory index,
        uint256[] memory amount
    ) external returns (bool) {
        address _userAddress = msg.sender;
        for (uint256 i = 0; i < _hex.length; i++) {
            address vault = vaultAddress[_hex[i]];
            MerkleAirDrop memory merkledrop = airdroppedtokens[vault];
            require(now > merkledrop.airdropStartDate ,"ERR_AIRDROP_NOT_STARTED");
            require(merkledrop.airdropExpirationDate > now,"ERR_AIRDROP_HAS_EXPIRED");
            require(!claimedMap[vault][index[i]],"ERR_AIRDROP_ALREADY_CLAIMED");
            bytes32 root = merkledrop.rootHash;
            bytes32 node = keccak256(abi.encodePacked(index[i], _userAddress, amount[i]));
            bytes32[] memory proof = _proof[i];
            if (MerkleProof.verify(proof, root, node)){
                TokenVault(vault).transferToken(msg.sender,amount[i]);
                claimedMap[vault][index[i]] = true;
                emit Claimed(msg.sender, amount[i],vault);
            }
        }
        return true;
    }

     /**
     * @dev to send the airdropped tokens back to AirDropper.
     * 
     *  @param
     * ' _vault'  - vault Address
     */
    function sendTokenBackToAirDropperByVault(address _vault) external returns (bool) {
        MerkleAirDrop memory merkledrop = airdroppedtokens[_vault];
        require(merkledrop.airdropCreator == msg.sender, "ERR_NOT_AUTHORIZED");
        require(merkledrop.airdropExpirationDate < now, "ERR_TOKEN_AIRDROP_HASNOT_EXPIRED");
        TokenVault(_vault).transferToken(merkledrop.airdropCreator,IERC20(TokenVault(_vault).token()).balanceOf(_vault));
        return true;
    }
    
    /**
     * @dev to send the airdropped tokens back to AirDropper.
     * 
     *  @param
     * ' _hex'  - hex bytes
     */
    function sendTokenBackToAirDropperByHex(bytes32 _hex) external returns (bool) {
        address _vault = vaultAddress[_hex];
        MerkleAirDrop memory merkledrop = airdroppedtokens[_vault];
        require(merkledrop.airdropCreator == msg.sender, "ERR_NOT_AUTHORIZED");
        require(merkledrop.airdropExpirationDate < now, "ERR_TOKEN_AIRDROP_HASNOT_EXPIRED");
        TokenVault(_vault).transferToken(merkledrop.airdropCreator,IERC20(TokenVault(_vault).token()).balanceOf(_vault));
        return true;
    }
    
    fallback() external payable {
        revert();
    }

    receive() external payable {
        revert();
    }  
}
