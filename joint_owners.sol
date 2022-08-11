//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

contract JointOwners{
    event Deposit(address indexed sender, uint amount);
    event Submit(uint indexed txId);
    event Approve(address indexed owner, uint indexed txId);
    event Revoke(address indexed owner, uint indexed txId);
    event Execute(uint indexed txId);

    address[] public owners;
    mapping(address => bool) public isOwner;
    uint public required;

    struct Transaction{
        address to;
        uint value;
        bytes data;
        bool executed;
    }
    
    Transaction[] public transactions;
    mapping (uint => mapping(address => bool)) public approved;

    constructor(address[] memory _owners, uint _required){
        require(_owners.length != 0, "Owners required");
        require(_required > 0 && _required <= _owners.length, "_required value is <= 0 or > lenght of array");
        for (uint i = 0; i < _owners.length; i++){
            address _Inowners = _owners[i];
            require(_owners[i] != address(0), "Empty address");
            require(!isOwner[_Inowners], "Address not unique, already inserted");
     
            owners.push(_Inowners);
            isOwner[_Inowners] = true;
        }
        required = _required;
    }
    receive() external payable{
        emit Deposit(msg.sender, msg.value);
    }
     modifier onlyOwner() {
        require(isOwner[msg.sender], "Deploying address required");
        _;
    }
    modifier txExists(uint _txId){
        require(_txId < transactions.length, "TxId does not exist");
        _;
    }
    modifier notApproved(uint _txId){
        require(!approved[_txId][msg.sender], "Tx already approved");
        _;
    }
    modifier notExecuted(uint _txId){
        require(!transactions[_txId].executed, "Tx already executed");
        _;
    }
    function submit(address _to, uint _value, bytes memory _data) external onlyOwner{
        transactions.push(Transaction(_to,_value,_data, false));
        emit Submit(transactions.length -1);
    }
    function approve (uint _txId) 
        external 
        onlyOwner
        txExists(_txId)
        notApproved(_txId)
        notExecuted(_txId)
        
        {
        approved[_txId][msg.sender] = true;
        emit Approve(msg.sender, _txId);
    }
    function revoke(uint _txId) 
        external 
        onlyOwner
        txExists(_txId)
        notApproved(_txId)
        notExecuted(_txId)
    {
        approved[_txId][msg.sender] = false;
        emit Revoke(msg.sender, _txId);
    }

    function _getApprovalCount(uint _txId) private view returns(uint count){
        for(uint i = 0; i < owners.length - 1; i++){
            if(approved[_txId][owners[i]]){
                count++;
            }
        }
    }
    function execute(uint _txId) external onlyOwner{
        require(_getApprovalCount(_txId) < required, "Not enough approvals");
        Transaction storage transaction = transactions[_txId];
        transaction.executed = true;
        (bool confirm, ) = transaction.to.call{value: transaction.value}(transaction.data);
        require(confirm, "Transaction failed");
        emit Execute(_txId);
    }

}
