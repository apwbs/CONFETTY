 pragma solidity ^0.5.3; 
	pragma experimental ABIEncoderV2;
	contract twoNested{
	event functionDone(string);
	enum State {DISABLED, ENABLED, DONE} State s; 
	struct Element{
			string ID;
		State status;
	}
		struct StateMemory{
	bool par1;
}
	Element[8] elements;
	  StateMemory currentMemory;
	string[2] roleList = [ "Participant 1", "Participant 2" ]; 
	mapping(string=>address payable) roles; 
constructor() public{
        elements[1] = Element("StartEvent_0i71l5l", State.ENABLED);
         //roles definition
         //mettere address utenti in base ai ruoli
	roles["Participant 1"] = 0x7A224d367EB99e849dC80F3d7b9FAC9E03Fe8Be0;
	roles["Participant 2"] = 0x7A224d367EB99e849dC80F3d7b9FAC9E03Fe8Be0;
		//enable the start process
		StartEvent_0i71l5l();
		emit functionDone("Contract creation");
	}
modifier checkRole(string memory role){ 
	require(msg.sender == roles[role]);
_; 

} function getRoles() public view returns( string[] memory, address[] memory){
    uint c = roleList.length;
    string[] memory allRoles = new string[](c);
    address[] memory allAddresses = new address[](c);
    
    for(uint i = 0; i < roleList.length; i ++){
        allRoles[i] = roleList[i];
        allAddresses[i] = roles[roleList[i]];
    }
    return (allRoles, allAddresses);
}
function() external payable{
    
} function StartEvent_0i71l5l() private {
	require(elements[1].status==State.ENABLED);
	done(1);
	enable("Message_1hvp5bm",2);

}

function Message_1hvp5bm(bool par1) public checkRole(roleList[0]) {
	require(elements[2].status==State.ENABLED);  
	done(2);
currentMemory.par1=par1;
	enable("ParallelGateway_12s9kx7",3);
ParallelGateway_12s9kx7(); 
}

function ParallelGateway_12s9kx7() private { 
	require(elements[3].status==State.ENABLED);
	done(3);
	enable("ParallelGateway_0awd9pc", 4); 
ParallelGateway_0awd9pc(); 
	enable("ParallelGateway_128iwct", 5); 
ParallelGateway_128iwct(); 
	enable("ParallelGateway_128iwct", 5); 
ParallelGateway_128iwct(); 
}

function ParallelGateway_0awd9pc() private { 
	require(elements[4].status==State.ENABLED);
	done(4);
	enable("ParallelGateway_0saxv30", 6); 
ParallelGateway_0saxv30(); 
	enable("ParallelGateway_0saxv30", 6); 
ParallelGateway_0saxv30(); 
}

function ParallelGateway_128iwct() private { 
	require(elements[5].status==State.ENABLED);
	done(5);
	if( elements[6].status==State.DONE && elements[3].status==State.DONE && elements[3].status==State.DONE ) { 
	enable("EndEvent_1jr85m8", 7); 
EndEvent_1jr85m8(); 
}} 

function EndEvent_1jr85m8() private {
	require(elements[7].status==State.ENABLED);
	done(7);  }

function ParallelGateway_0saxv30() private { 
	require(elements[6].status==State.ENABLED);
	done(6);
	if( elements[4].status==State.DONE && elements[4].status==State.DONE ) { 
	enable("ParallelGateway_128iwct", 5); 
ParallelGateway_128iwct(); 
}} 

	function enable(string memory _taskID, uint position) internal {
		elements[position] = Element(_taskID, State.ENABLED);
	}
    function disable(uint elementNum) internal {
		elements[elementNum].status=State.DISABLED; }

    function done(uint elementNum) internal {
 		elements[elementNum].status=State.DONE; 			emit functionDone(elements[elementNum].ID);
		 }
   
    function getCurrentState()public view  returns(Element[8] memory, StateMemory memory){
        // emit stateChanged(elements, currentMemory);
        return (elements, currentMemory);
    }
    
    function compareStrings (string memory a, string memory b) internal pure returns (bool) { 
        return keccak256(abi.encode(a)) == keccak256(abi.encode(b)); 
    }
}