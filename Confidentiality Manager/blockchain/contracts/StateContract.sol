// SPDX-License-Identifier: CC-BY-SA-4.0
pragma solidity >= 0.5.0 < 0.9.0;
import "./MARTSIAEth.sol";

//Registry contract -> tiene traccia di tutte le istanze aventi [elementi, stati, dati e utenti] per istanza
contract StateContract{
    //                  0    ,   1 ,  2   ,    3    ,    4   ,    5     ,     6   ,      7     ,  8
    enum ElementType {ELEMENT, MSG, START, EX_SPLIT, EX_JOIN, PAR_SPLIT, PAR_JOIN, EVENT_BASED, END}
    enum ElementState {DISABLED, ENABLED, COMPLETED}
    enum Operator {NO_CONDITION, EQ, NOT_EQ, G_THAN, L_THAN}
    address chorchainAddress = 0x62AbA4475128080Dd4B59FA5D7E2fAEb2B720A21;

    event functionDone(uint64, uint64);

    struct Instance {
        //messageIDs -> messages
        mapping(uint64 => Element) allElements;
        //contains all the process intstances
        mapping(bytes32 => bytes32) publicVariables;
        //associates variables to message and then more values
        //apping(bytes32 => mapping (bytes32 => bytes32)) publicVariables;
        //contains the public variables allowed. This is used to enforce what user can insert
        mapping(uint64 => mapping (bytes32 => bool)) allowedVars;
        //maps outgoing branches (next elements from an exclusive gw) to conditions
        mapping(uint64 => Condition) conditions;
        mapping(bytes32 => address) roles;
        bytes32 policyPart1;
        bytes32 policyPart2;
    }

    //an element contains its status (enabled/disabled), the participant address that can execute it and the reference to the next elements
    struct Element{
        ElementState state;
        ElementType elementType;
        bytes32 role;
        uint64[] next;
        uint64[] previous;
    }

    //it expresses a condition in a certain path. it contains the public variable to evaluate, the type of operand and the value to be used in the comparison
    struct Condition{
        bytes32 publicVar;
        Operator op;
        bytes32 value;
    }

    //it contains all the instances
    mapping(uint64 => Instance) allInstances;
    //address private martsiaAddress = 0x85529AC7416B246598f0Ca16191389c6d13e6b4a;
    constructor(address martsiaAddress){
        MARTSIAEth m = MARTSIAEth(martsiaAddress);
        m.setStateAddress();
    }

    function getInstancePolicy(uint64 instanceId) public view returns(bytes memory){
        bytes memory joined = new bytes(64);
        bytes32 p1 = allInstances[instanceId].policyPart1;
        bytes32 p2 = allInstances[instanceId].policyPart2;
        assembly {
            mstore(add(joined, 32), p1)
            mstore(add(joined, 64), p2)
        }
        return joined;
    }
    //checks if sender user is the one enabled in the element that is executed
    modifier UserRoleCheck(uint64 instanceId, uint64 msgToExecute, address user) {
        bytes32 enabledRole = allInstances[instanceId].allElements[msgToExecute].role;
        require(user == allInstances[instanceId].roles[enabledRole]);
        _;
    }

    /*modifier onlyMartsia(){
        require(msg.sender == martsiaAddress);
        _;
    }*/

    //checks if the element to execute is enabled
    modifier ElementStatusCheck(uint64 instanceId, uint64 msgToExecute) {
        require(allInstances[instanceId].allElements[msgToExecute].elementType == ElementType.MSG);
        require(allInstances[instanceId].allElements[msgToExecute].state == ElementState.ENABLED);
        _;
    }

    function getMartsiaChecks(uint64 instanceId, uint64 msgToExecute, address user) public view UserRoleCheck(instanceId, msgToExecute, user)
    ElementStatusCheck(instanceId, msgToExecute) returns(bool){
        return true;
    }


    //checks if the invoker is ChorChain
    modifier ChorChain() {
        require(chorchainAddress == msg.sender);
        _;
    }

    //per modifier su martsia
    function getInstanceElement(uint64 instanceId, uint64 _element) public view returns(Element memory){
        return allInstances[instanceId].allElements[_element];
    }



    function getCondition(uint64 instanceId, uint64 element) public view returns(Condition memory){
        return allInstances[instanceId].conditions[element];
    }

    function getAllowedVar(uint64 instanceId, uint64 element, bytes32 varName) public view returns(bool){
        return allInstances[instanceId].allowedVars[element][varName];
    }


    /*
    Function to create a new instance structure in the smart contract
    it takes in input the instance id, list of BPMN elements and their nexts to recreate the choreography tree, list of users for elements,
    the first element to enable and the hash for [reading policies --> TODO]
    */
    //TODO------> AVOID INSTANCES TO OVERWRITE ALREADY EXISTING ONES
    function instantiateProcess(uint64 instanceId, bytes32[] memory _roles, address[] memory users, uint64[] memory elements,
        uint64[][] memory nextElements, uint64[][] memory previousElements, ElementType[] memory types,
        bytes32 policy1, bytes32 policy2) public ChorChain{
        uint64 startEvent;
        allInstances[instanceId].policyPart1 = policy1;
        allInstances[instanceId].policyPart2 = policy2;
        for(uint8 i = 0; i < elements.length; i++){
            Element memory e;
            if(users[i] != address(0x0)){
                allInstances[instanceId].roles[_roles[i]] = users[i];
            }

            //if the element is the start event then set it to enabled. the start event is hard coded since it is always present
            //and it is always the starting point
            if(types[i] != ElementType.START){
                e = Element(ElementState.DISABLED, types[i], _roles[i], nextElements[i], previousElements[i]);
            }else{
                e = Element(ElementState.ENABLED, types[i], _roles[i], nextElements[i], previousElements[i]);
                startEvent = elements[i];
            }
            allInstances[instanceId].allElements[elements[i]] = e;
        }
        //automatically executes the start event
        changeStatus(instanceId, startEvent);
    }

    //function for creating a condition attached to an element. It requires the instance id, the set of elements to which associate conditions,
    //the set of public variables associated with the conditions, the operators associated with the conditions and the values used in the condition
    /*elementWithConditions = elements outgoing an exclusive gateway
      elementWithPublicVar = messages having a public varaible
      publicVars = left side of the operator. public variables used in choices
      operators =
      values = right side of the operator
    */
    function createConditions(uint64 instanceId, uint64[] memory elementWithConditions, uint64[] memory elementWithPublicVar,
        bytes32[] memory publicVars, Operator[] memory operators, bytes32[] memory values) public ChorChain{
        for(uint8 i = 0; i < elementWithPublicVar.length; i++){
            allInstances[instanceId].allowedVars[elementWithPublicVar[i]][publicVars[i]] = true;
        }
        for(uint8 i = 0; i < elementWithConditions.length; i++){
            //allow public variables attached to corresponding elements
            allInstances[instanceId].conditions[elementWithConditions[i]] = Condition(publicVars[i], operators[i], values[i]);
        }
    }

    /*function that simulates the cipher in Martsia contract.
    it has the modifiers for checking if 1) the element is a message, 2) the element is enabled, and 3) the user is the designed one
    inside the function it first checks if the message to execute comes after an event based gateway and in case it invokes the function
    for disabling the other concurrent ones.
    Then, it invokes the function for changing the status of the message and the next ones
    */
    function checkEventBased(uint64 instanceId, uint64 msgToExecute) public {
        uint64 previousId = allInstances[instanceId].allElements[msgToExecute].previous[0];
        Element memory previousElement = allInstances[instanceId].allElements[previousId];
        //if the previous element is an event based gw then invoke the function for disabling the concurrent ones
        if(previousElement.elementType == ElementType.EVENT_BASED){
            eventBased(previousElement, instanceId, msgToExecute);
        }
    }

    function cipher(uint64 instanceId, uint64 msgToExecute, bytes32[] memory publicvarNames, bytes32[] memory publicVarValues) public {

        //it manages the eventual update of public variables used later for the conditions in exclusive gateways
        //setPublicvariables(instanceId, msgToExecute, publicvarNames, publicVarValues);
        //it sets to COMPLETED the current message and enables the next ones
        //changeStatus(instanceId, msgToExecute);
        //return "sei stato abilitato complimenti";
    }

    //function for setting the value of a public variable previously allowed
    function setPublicvariables(uint64 instanceId, uint64 msgToExecute, bytes32[] memory publicVarNames, bytes32[] memory publicVarValues) public {
        Instance storage currentInstance = allInstances[instanceId];
        //for each user input variable, if it is allowed then insert it
        for(uint8 i = 0; i < publicVarNames.length; i++){
            if(currentInstance.allowedVars[msgToExecute][publicVarNames[i]] == true){
                currentInstance.publicVariables[publicVarNames[i]] = publicVarValues[i];
            }
        }
    }


    //checks if an element is a gateway and in case executes it
    function executeGateway(uint64 elementToExecute, uint64 instanceId) internal {
        Element storage element = allInstances[instanceId].allElements[elementToExecute];
        if(element.elementType == ElementType.EX_SPLIT){
            ex_split(instanceId, elementToExecute);
        }else if(element.elementType == ElementType.EX_JOIN){
            ex_join(instanceId, elementToExecute);
        }else if(element.elementType == ElementType.PAR_SPLIT || element.elementType == ElementType.EVENT_BASED){
            //in case of parallel split and event based gateways just enable the next elements (also called outgoing)
            par_event_split(instanceId, elementToExecute);
        }else if(element.elementType == ElementType.PAR_JOIN){
            par_join(element, instanceId);
        }else if(element.elementType == ElementType.END){
            //if the element is an end event just complete it thus terminating the process instance flow
            setCompleted(instanceId, elementToExecute);
            //element.state = ElementState.COMPLETED;
        }else if(element.elementType == ElementType.MSG){
            element.state = ElementState.ENABLED;
        }
    }


    //the function sets the status of the current element to false and of the next elements to true
    //then it invokes the function for checking if the element is a gateway eventually executing it
    function changeStatus(uint64 instanceId, uint64 elementToExecute) public {
        Element storage currentElement = allInstances[instanceId].allElements[elementToExecute];
        //currentElement.state = ElementState.COMPLETED;
        setCompleted(instanceId, elementToExecute);
        //for each next element enables it and triggers the function for eventually execute it in case it is a gateway
        for(uint8 i = 0; i < currentElement.next.length; i++){
            Element storage nextElement = allInstances[instanceId].allElements[currentElement.next[i]];
            nextElement.state = ElementState.ENABLED;
            executeGateway(currentElement.next[i], instanceId);
        }
        emit functionDone(instanceId, elementToExecute);

    }

    //function for the parallel split gateway, it enables the next elements and if they are gateways execute them
    function par_event_split(uint64 instanceId, uint64 element) internal {
        Element memory gateway = allInstances[instanceId].allElements[element];
        setCompleted(instanceId, element);
        //gateway.state = ElementState.COMPLETED;
        //for each element outgoing the gateway enable it and check if it is a gateway
        for(uint8 i = 0; i < gateway.next.length; i++){
            Element storage e = allInstances[instanceId].allElements[gateway.next[i]];
            e.state = ElementState.ENABLED;
            executeGateway(gateway.next[i], instanceId);
        }
    }

    //function for the parallel JOIN gateway, it enables the next elements (and if they are gateways execute them) only if the previous were both executed
    function par_join(Element storage gateway, uint64 instanceId) internal {
        for(uint8 i = 0; i < gateway.previous.length; i++){
            Element storage e = allInstances[instanceId].allElements[gateway.previous[i]];
            //if there is an element still not executed then interrupts the execution of the function
            if(e.state != ElementState.COMPLETED){
                return;
            }
        }
        gateway.state = ElementState.COMPLETED;
        //if the join is ok then check if the next element (join has only 1 outgoing) is a gateway
        executeGateway(gateway.next[0], instanceId);
    }

    //EVENT-BASED gateway is a race condition, the first element to be executed wins and disables the other ones
    //this function manages the disabling of the other elements outgoing from the event based not boing the current to execute
    function eventBased(Element memory gateway, uint64 instanceId, uint64 msgToExecute) internal {
        //iter outgoing elements from the event based to disable the one not being executed
        for(uint8 i = 0; i < gateway.next.length; i ++){
            //If outgoing element is not the message to execute then disable it
            if(gateway.next[i] != msgToExecute){
                allInstances[instanceId].allElements[gateway.next[i]].state = ElementState.DISABLED;
            }
        }
    }

    //function for the parallel JOIN gateway, it enables the next elements (and if they are gateways execute them) only if the previous were both executed
    function ex_join(uint64 instanceId, uint64 element) internal {
        Element memory gateway = allInstances[instanceId].allElements[element];
        for(uint8 i = 0; i < gateway.previous.length; i++){
            Element storage e = allInstances[instanceId].allElements[gateway.previous[i]];
            //if there is an element still not executed then interrupts the execution of the function
            if(e.state == ElementState.COMPLETED){
                setCompleted(instanceId, element);
                //gateway.state = ElementState.COMPLETED;
                //if the join is ok then check if the next element (join has only 1 outgoing) is a gateway
                executeGateway(gateway.next[0], instanceId);
            }
        }
    }

    //function for the exclusive gateway, for each outgoing element checks the related condition and evaluates it
    function ex_split(uint64 instanceId, uint64 element) internal{
        Element memory gateway = allInstances[instanceId].allElements[element];
        //if the gateway is used only as connector so has only one exit without condition then enable next element
        if(gateway.next.length == 1 && allInstances[instanceId].conditions[gateway.next[0]].op == Operator.NO_CONDITION){
            Element storage nextElement = allInstances[instanceId].allElements[gateway.next[0]];
            nextElement.state = ElementState.ENABLED;
            executeGateway(gateway.next[0], instanceId);
            setCompleted(instanceId, element);
        }else{
            for(uint8 i = 0; i < gateway.next.length; i++){
                //retrieves the condition attached to the outgoing element
                Condition memory c = allInstances[instanceId].conditions[gateway.next[i]];
                Element storage nextElement = allInstances[instanceId].allElements[gateway.next[i]];
                //reads the public variable (the one iserted by the user) required by the condition
                bytes32 publicVar = allInstances[instanceId].publicVariables[c.publicVar];
                //checks if the operator is EQUAL and the public variable is equal the condition valu
                if(c.op == Operator.EQ && publicVar == c.value){
                    nextElement.state = ElementState.ENABLED;
                    executeGateway(gateway.next[i], instanceId);
                    //checks if the operator is GREATER THAN and the public variable is greater than the condition value
                }else if(c.op == Operator.G_THAN && publicVar > c.value){
                    nextElement.state = ElementState.ENABLED;
                    executeGateway(gateway.next[i], instanceId);
                    //checks if the operator is LESS THAN and the public variable is less than the condition value
                }else if(c.op == Operator.L_THAN && publicVar < c.value){
                    nextElement.state = ElementState.ENABLED;
                    executeGateway(gateway.next[i], instanceId);
                }
                setCompleted(instanceId, element);
                //gateway.state = ElementState.COMPLETED;
            }
        }
    }

    function setCompleted(uint64 instanceId, uint64 element) internal {
        allInstances[instanceId].allElements[element].state = ElementState.COMPLETED;
    }


}
