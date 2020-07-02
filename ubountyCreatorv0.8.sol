pragma solidity ^0.5.11;

//Contract deployed on ropsten: 0x0ab27d1add579E4C71a341a9579244385066bBC1
//Test Cash contract: 0x0f54093364b396461AAdf85C015Db597AAb56203

//Mainnet: 0x73aa31Cd548AC14713F778f454348d90564e2dE1
//Devcash: 0x0fca8Fdb0FB115A33BAadEc6e7A141FFC1bC7d5a


contract ERC20{
    function balanceOf(address who) public view returns (uint256);
    function transfer(address to, uint256 value) public returns (bool);
    function transferFrom(address from, address to, uint256 value) public returns (bool);
}

contract ERC20Approve {
 function approve(address spender, uint256 value) public returns (bool);
}

contract bountyChest{
    constructor () public {
        ERC20Approve(0x0f54093364b396461AAdf85C015Db597AAb56203).approve(msg.sender,2**256-1);
    }
}

contract ubountyCreator{

    string public version = "ubounties-v0.8";

    event created(uint uBountyIndex,uint bountiesAvailable, uint tokenAmount, uint weiAmount);        //add a

    event submitted(uint uBountyIndex, uint submissionIndex);
    event revised(uint uBountyIndex,uint submissionIndex, uint revisionIndex);

    event approved(uint uBountyIndex, uint submissionIndex, string feedback);
    event rejected(uint uBountyIndex, uint submissionIndex, string feedback);
    event revisionRequested(uint uBountyIndex, uint submissionIndex, string feedback);

    event rewarded(uint uBountyIndex, uint submissionIndex, address Hunter, uint tokenAmount,uint weiAmount);

    event reclaimed(uint uBountyIndex, uint tokenAmount, uint weiAmount);

    event completed(uint uBountyIndex);

    event feeChange(uint oldFee, uint newFee);
    event waiverChange(uint oldWaiver, uint newWaiver);

    address public devcash = 0x0f54093364b396461AAdf85C015Db597AAb56203;
    address public admin;
    address payable public collector = 0xB1F445F64CDDe81d58c26ab1C340FE2a82F55A4C;

    uint public fee = 1000000000000000;
    uint public waiver = 2500000000000;

    struct submission{
        uint32 submitterIndex;
        string submissionString;
        bool approved;
        mapping(uint=>string) revisions;
        uint8 numRevisions;
    }

    struct ubounty{
        uint8 available;          //rename to avaiable
        uint8 numSubmissions;
        uint32 hunterIndex;
        uint32 creatorIndex;
        uint32 bountyChestIndex;
        uint48 deadline;
        uint weiAmount;
        string name;
        string description;
        mapping(uint => submission) submissions;
    }

    mapping(uint => ubounty) public ubounties;
    uint public numUbounties;

    function getSubmission(uint ubountyIndex, uint submissionIndex) public view returns(string memory,address, bool,uint) {
        return (
            ubounties[ubountyIndex].submissions[submissionIndex].submissionString,
            userList[ubounties[ubountyIndex].submissions[submissionIndex].submitterIndex],
            ubounties[ubountyIndex].submissions[submissionIndex].approved,
            ubounties[ubountyIndex].submissions[submissionIndex].numRevisions);
    }

    function getRevision(uint ubountyIndex,uint submissionIndex, uint revisionIndex) public view returns (string memory){
        return ubounties[ubountyIndex].submissions[submissionIndex].revisions[revisionIndex];
    }

    mapping(address=>uint32) bountyChests;
    address[] public bCList; //list of bounty chest addresses
    uint[] public freeBC; // list of unused bounty chests
    function numBC() public view returns(uint){
        return bCList.length;
    }

    mapping(address => uint32) public users;
    address payable[] public userList;
    function numUsers() public view returns(uint){
        return userList.length;
    }

    constructor() public {
        admin = msg.sender;
        userList.push(address(0));
        bCList.push(address(0));
    }

        //rename numleft to numavailable
    function postOpenBounty(
        string memory name,
        string memory description,
        uint8 available,
        uint amount,
        uint48 deadline
        ) public payable{
            require(msg.value>=fee||satisfiesWaiver(msg.sender), "ETH fee and DEV waiver not met");

            uint _fee = getFee(msg.sender);

            addUser(msg.sender);

            address bCAddress = getBountyChest();

            uint weiAmount = msg.value-_fee;

            if(deadline==0){
                deadline = 2**48-1;
            }

            setUbounty(users[msg.sender], 0, available, name, description, bountyChests[bCAddress], weiAmount, deadline);


            collector.transfer(_fee);
            ERC20(devcash).transferFrom(msg.sender,bCAddress,amount);
            emit created(numUbounties++,available,amount,weiAmount);
    }

    function postPersonalBounty(
        string memory name,
        string memory description,
        address payable hunter,
        uint8 available,
        uint amount,
        uint48 deadline
        ) public payable{
            require(msg.value>=fee||satisfiesWaiver(msg.sender), "ETH fee and DEV waiver not met");

            uint _fee = getFee(msg.sender);

            addUser(msg.sender);

            addUser(hunter);

            address bCAddress = getBountyChest();

            uint weiAmount = msg.value-_fee;

            if(deadline==0){
                deadline = 2**48-1;
            }

            setUbounty(users[msg.sender], users[hunter], available, name, description, bountyChests[bCAddress], weiAmount, deadline);

            collector.transfer(_fee);
            ERC20(devcash).transferFrom(msg.sender,bCAddress,amount);
            emit created(numUbounties++,available,amount,weiAmount);
    }

    function awardOpenBounty(uint ubountyIndex, address payable hunter) public{
        require(users[msg.sender]==ubounties[ubountyIndex].creatorIndex,"You are not the bounty publisher");
        require(ubounties[ubountyIndex].available>0,"This bounty is inactive");
        require(ubounties[ubountyIndex].hunterIndex==0,"Only works for Open Bounties");

        uint rewardAmount = bountyAmount(ubountyIndex)/ubounties[ubountyIndex].available;
        uint weiRewardAmount = weiBountyAmount(ubountyIndex)/ubounties[ubountyIndex].available;
        ubounties[ubountyIndex].weiAmount-= weiRewardAmount;
        ubounties[ubountyIndex].available--;

        ERC20(devcash).transferFrom(bCList[ubounties[ubountyIndex].bountyChestIndex],hunter,rewardAmount);
        hunter.transfer(weiRewardAmount);

        if(ubounties[ubountyIndex].available==0){
            freeBC.push(ubounties[ubountyIndex].bountyChestIndex);
            emit completed(ubountyIndex);
        }
        emit rewarded(ubountyIndex,0,hunter,rewardAmount,weiRewardAmount);
    }

    function awardPersonalBounty(string memory name, string memory description, address payable hunter, uint tokenAmount) public payable {
        require(msg.value>=fee||satisfiesWaiver(msg.sender), "ETH fee and DEV waiver not met");

        uint _fee = getFee(msg.sender);

        addUser(msg.sender);
        addUser(hunter);

        setUbounty(users[msg.sender], users[hunter], 0, name, description, 0, 0, 0);

        uint weiAmount = msg.value-_fee;

        hunter.transfer(weiAmount);
        ERC20(devcash).transferFrom(msg.sender,hunter,tokenAmount);

        collector.transfer(_fee);
        emit rewarded(numUbounties,0,hunter,tokenAmount,weiAmount);
        emit completed(numUbounties++);
    }

    function getFee(address Poster) public view returns(uint _fee) {
            if(satisfiesWaiver(Poster)){
                _fee=0;
            } else{
                _fee = fee;
            }
            return(_fee);
    }

    function addUser(address payable user) public {
        if (users[user]==0){
            users[user] = uint32(userList.length);
            userList.push(user);
        }
    }

    function getBountyChest() internal returns(address bCAddress){
        if (freeBC.length>0){
                bCAddress = bCList[freeBC[freeBC.length-1]];
                freeBC.length--;
            } else{
                bountyChest C = new bountyChest();
                bCAddress = address(C);
                bountyChests[bCAddress] = uint32(bCList.length);
                bCList.push(bCAddress);
            }
        return(bCAddress);
    }

    function setUbounty(
        uint32 creatorIndex,
        uint32 hunterIndex,
        uint8 available,
        string memory name,
        string memory description,
        uint32 bountyChestIndex,
        uint weiAmount,
        uint48 deadline
        ) internal {
            ubounties[numUbounties].creatorIndex = creatorIndex;
            ubounties[numUbounties].hunterIndex = hunterIndex;
            ubounties[numUbounties].available = available;
            ubounties[numUbounties].name = name;
            ubounties[numUbounties].description = description;
            ubounties[numUbounties].bountyChestIndex = bountyChestIndex;
            ubounties[numUbounties].weiAmount = weiAmount;
            ubounties[numUbounties].deadline = deadline;
    }

    function submit(uint ubountyIndex, string memory submissionString) public {
        require(ubounties[ubountyIndex].hunterIndex==0 || msg.sender==userList[ubounties[ubountyIndex].hunterIndex],"You are not the bounty hunter");
        require(now<=ubounties[ubountyIndex].deadline,"The bounty deadline has passed");
        require(ubounties[ubountyIndex].available>0,"This bounty is inactive");  //make sure available is more than 0

        if(users[msg.sender]==0){
            users[msg.sender] = uint32(userList.length);
            userList.push(msg.sender);
        }

        ubounties[ubountyIndex].submissions[ubounties[ubountyIndex].numSubmissions].submissionString = submissionString;
        ubounties[ubountyIndex].submissions[ubounties[ubountyIndex].numSubmissions].submitterIndex = users[msg.sender];

        emit submitted(ubountyIndex,ubounties[ubountyIndex].numSubmissions++);
    }

    function revise(uint ubountyIndex, uint32 submissionIndex, string memory revisionString) public {
        require(msg.sender==userList[ubounties[ubountyIndex].submissions[submissionIndex].submitterIndex],"You are not the submitter");
        require(ubounties[ubountyIndex].available>0,"This bounty is inactive");  //make sure available is more than 0
        require(ubounties[ubountyIndex].submissions[submissionIndex].approved==false,"This submission has already been approved");

        uint8 numRevisions = ubounties[ubountyIndex].submissions[submissionIndex].numRevisions;
        ubounties[ubountyIndex].submissions[submissionIndex].revisions[numRevisions] = revisionString;
        emit revised(ubountyIndex,submissionIndex,numRevisions);
        ubounties[ubountyIndex].submissions[submissionIndex].numRevisions++;
    }

    function approve(uint ubountyIndex,uint submissionIndex,string memory feedback) public{
        require(users[msg.sender]==ubounties[ubountyIndex].creatorIndex,"You are not the bounty publisher");
        require(ubounties[ubountyIndex].available>0,"This bounty is inactive");
        require(submissionIndex<ubounties[ubountyIndex].numSubmissions,"Submission does not exist");
        require(ubounties[ubountyIndex].submissions[submissionIndex].approved==false,"This submission has already been approved");

        emit approved(ubountyIndex, submissionIndex, feedback);
        ubounties[ubountyIndex].submissions[submissionIndex].approved=true;
        address payable hunter = userList[ubounties[ubountyIndex].submissions[submissionIndex].submitterIndex];
        reward(ubountyIndex,submissionIndex,hunter);
    }

    function reject(uint ubountyIndex,uint submissionIndex,string memory feedback) public{
        require(users[msg.sender]==ubounties[ubountyIndex].creatorIndex,"You are not the bounty publisher");
        require(ubounties[ubountyIndex].available>0,"This bounty is inactive");
        require(submissionIndex<ubounties[ubountyIndex].numSubmissions,"Submission does not exist");
        require(ubounties[ubountyIndex].submissions[submissionIndex].approved==false,"This bounty has already been approved");

        emit rejected(ubountyIndex, submissionIndex, feedback);
    }

    function requestRevision(uint ubountyIndex,uint submissionIndex,string memory feedback) public {
        require(users[msg.sender]==ubounties[ubountyIndex].creatorIndex,"You are not the bounty publisher");
        require(ubounties[ubountyIndex].available>0,"This bounty is inactive");
        require(submissionIndex<ubounties[ubountyIndex].numSubmissions,"Submission does not exist");
        require(ubounties[ubountyIndex].submissions[submissionIndex].approved==false,"This bounty has already been approved");

        emit revisionRequested(ubountyIndex,submissionIndex,feedback);
    }

    function reward(uint ubountyIndex, uint submissionIndex, address payable hunter) internal {

        uint rewardAmount = bountyAmount(ubountyIndex)/ubounties[ubountyIndex].available;
        uint weiRewardAmount = weiBountyAmount(ubountyIndex)/ubounties[ubountyIndex].available;
        ubounties[ubountyIndex].weiAmount-=weiRewardAmount;
        ubounties[ubountyIndex].available--;

        hunter.transfer(weiRewardAmount);
        ERC20(devcash).transferFrom(bCList[ubounties[ubountyIndex].bountyChestIndex],hunter,rewardAmount);

        emit rewarded(ubountyIndex,submissionIndex,hunter,rewardAmount,weiRewardAmount);

        if(ubounties[ubountyIndex].available==0){
            freeBC.push(ubounties[ubountyIndex].bountyChestIndex);
            emit completed(ubountyIndex);
        }
    }

    function contribute(uint ubountyIndex, uint amount) public{
        require(ubounties[ubountyIndex].available>0,"This bounty is inactive");
        address bCAddress = bCList[ubounties[ubountyIndex].bountyChestIndex];
        ERC20(devcash).transferFrom(msg.sender,bCAddress,amount);
    }

    function contributeWei(uint ubountyIndex) public payable{
        require(ubounties[ubountyIndex].available>0,"This bounty is inactive");
        ubounties[ubountyIndex].weiAmount += msg.value;
    }

    function reclaim(uint ubountyIndex) public {
        require(users[msg.sender]==ubounties[ubountyIndex].creatorIndex,"You are not the bounty creator");
        require(ubounties[ubountyIndex].deadline!=2**48-1,"This bounty was created without a deadline, and is not reclaimable");
        require(now>ubounties[ubountyIndex].deadline,"The bounty deadline has not yet elapsed");
        require(ubounties[ubountyIndex].available>0,"This bounty is inactive");

        uint weiAmount = weiBountyAmount(ubountyIndex);
        ubounties[ubountyIndex].weiAmount = 0;

        ERC20(devcash).transferFrom(bCList[ubounties[ubountyIndex].bountyChestIndex],msg.sender,bountyAmount(ubountyIndex));
        msg.sender.transfer(weiAmount);

        freeBC.push(ubounties[ubountyIndex].bountyChestIndex);

        ubounties[ubountyIndex].available = 0;

        for(uint i=0;i<ubounties[ubountyIndex].numSubmissions&&i<1800;i++){
            if(ubounties[ubountyIndex].submissions[i].approved==false){
                emit rejected(ubountyIndex,i,"bounty has been reclaimed");
            }
        }

        emit reclaimed(ubountyIndex,bountyAmount(ubountyIndex),weiAmount);
    }

    function reclaimable(uint ubountyIndex) public view returns(bool){
        if(ubounties[ubountyIndex].deadline!=2**48-1){
            return true;
        } else {
            return false;
        }
    }

    function reclaimableNow(uint ubountyIndex) public view returns(bool){
        if(now>ubounties[ubountyIndex].deadline){
            return true;
        } else {
            return false;
        }
    }

    function bountyAmount(uint ubountyIndex) public view returns(uint){
        return(ERC20(devcash).balanceOf(bCList[ubounties[ubountyIndex].bountyChestIndex]));
    }

    function weiBountyAmount(uint ubountyIndex) public view returns(uint){
        return(ubounties[ubountyIndex].weiAmount);
    }

    function createBountyChest() public {
        bountyChest C = new bountyChest();
        address bCAddress = address(C);
        bountyChests[bCAddress] = uint32(bCList.length);
        freeBC.push(bCList.length);
        bCList.push(bCAddress);
    }

    function setFee(uint _fee) public {
        require(admin==msg.sender);
        emit feeChange(fee,_fee);
        fee = _fee;
    }

      function setWaiver(uint _waiver) public {
        require(admin==msg.sender);
        emit waiverChange(waiver,_waiver);
        waiver = _waiver;
    }

    function satisfiesWaiver(address poster) public view returns(bool){
        if(ERC20(devcash).balanceOf(poster)>=waiver){
            return true;
        } else {
            return false;
        }
    }
}
