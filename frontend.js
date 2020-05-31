let ETHBalanceLabel
let DBalanceLabel
let DApprovedLabel
let DApproveAmountInput

let OBNameInput
let OBDescriptionInput
let OBAvailableInput
let OBAmountInput
let OBTimeIntervalInput
let OBTimeFrameSelect

let PBHunterInput
let PBNameInput
let PBDescriptionInput
let PBAvailableInput
let PBAmountInput
let PBTimeIntervalInput
let PBTimeFrameSelect

let ABHunterInput
let ABNameInput
let ABDescriptionInput
let ABAmountInput

let MBountySelect
let MCreatorLabel
let MNameLabel
let MDescriptionLabel
let MHunterLabel
let MAmountLabel
let MAvailableLabel
let MDeadlineLabel

let CAmountInput

let MSSubmissionSelect
let MSHunterLabel
let MSSubmissionLabel

let OHTable   //Open Hunter Table
let PHTable   //Personal Hunter Table
let HSTable   //Hunter Submissions Table

let ubounties
let users

async function initialize(web3) {
  await ethereum.enable()
  let provider = new ethers.providers.Web3Provider(web3.currentProvider)
  let accounts = await provider.listAccounts()
  signer = provider.getSigner(accounts[0])

  ubc = new ethers.Contract(ubcAddress,ubcABI,signer)
  devcash = new ethers.Contract(devcashAddress,devcashABI,signer)

  decimals = await devcash.decimals()
  symbol = await devcash.symbol()

  ubounties = await getUbountiesInfo()
  users = await getUsers()

	populateFrontend()
}

async function populateFrontend(){
  console.log("Populate Frontend")
  getElements()
  await populateBalance()
  await populatePosterManager()
  await populateHunterManager()
}

async function getElements(){
  ETHBalanceLabel = document.getElementById("ETHBalanceLabel")
  DBalanceLabel = document.getElementById("DBalanceLabel")
  DApprovedLabel = document.getElementById("DApprovedLabel")
  DApproveAmountInput = document.getElementById("DApproveAmountInput")

  OBNameInput = document.getElementById("OBNameInput")
  OBDescriptionInput = document.getElementById("OBDescriptionInput")
  OBAvailableInput = document.getElementById("OBAvailableInput")
  OBAmountInput = document.getElementById("OBAmountInput")
  OBTimeIntervalInput = document.getElementById("OBTimeIntervalInput")
  OBTimeFrameSelect = document.getElementById("OBIntervalSelect")

  PBHunterInput = document.getElementById("PBHunterInput")
  PBNameInput = document.getElementById("PBNameInput")
  PBDescriptionInput = document.getElementById("PBDescriptionInput")
  PBAvailableInput = document.getElementById("PBAvailableInput")
  PBAmountInput = document.getElementById("PBAmountInput")
  PBDeadlineInput = document.getElementById("PBDeadlineInput")
  PBIntervalSelect = document.getElementById("PBIntervalSelect")

  ABHunterInput = document.getElementById("ABHunterInput")
  ABNameInput = document.getElementById("ABNameInput")
  ABDescriptionInput = document.getElementById("ABDescriptionInput")
  ABAmountInput = document.getElementById("ABAmountInput")

  MBountySelect = document.getElementById("MBountySelect")
  MCreatorLabel = document.getElementById("MCreatorLabel")
  MNameLabel = document.getElementById("MNameLabel")
  MDescriptionLabel = document.getElementById("MDescriptionLabel")
  MHunterLabel = document.getElementById("MHunterLabel")
  MAmountLabel = document.getElementById("MAmountLabel")
  MAvailableLabel = document.getElementById("MAvailableLabel")
  MDeadlineLabel = document.getElementById("MDeadlineLabel")

  CAmountInput = document.getElementById("CAmountInput")

  MSSubmissionSelect = document.getElementById("MSSubmissionSelect")
  MSHunterLabel = document.getElementById("MSHunterLabel")
  MSSubmissionLabel = document.getElementById("MSSubmissionLabel")

  OHTable = document.getElementById("OHTable")
  PHTable = document.getElementById("PHTable")
  HSTable = document.getElementById("HSTable")
}

async function populateBalance(){
  ETHBalanceLabel.innerHTML = "Eth Balance: " + await getETHBalance()
  DBalanceLabel.innerHTML = "Devcash Balance: " + await getDevcashBalance()
  DApprovedLabel.innerHTML = "Approved Devcash: " + await getApprovedBalance()
}

async function populatePosterManager(){
  console.log("populate Poster Manager")
  await populateCreatorSelect()
  var bountyId = document.getElementById("MBountySelect").value
  if (bountyId==""){return}

  let creatorLink = document.createElement("a")
  MCreatorLabel.innerHTML = "Creator: "
  let creatorAddress = users[ubounties[bountyId].creatorIndex]
  creatorLink.innerText = creatorAddress
  creatorLink.href = "https://etherscan.io/address/" + creatorAddress
  MCreatorLabel.appendChild(creatorLink)
  MNameLabel.innerHTML = "Name: " + ubounties[bountyId].name
  MDescriptionLabel.innerHTML = "Description: " + ubounties[bountyId].description
  MHunterLabel.innerHTML = "Hunter: " + users[ubounties[bountyId].hunter]
  MAmountLabel.innerHTML = "Amount: " + ubounties[bountyId].amount + " " + symbol
  MAvailableLabel.innerHTML = "Available: " + ubounties[bountyId].available
  //document.getElementById("submissionLabel").innerHTML = "Submission: " + ubounties[bountyId].submissionStrings[ubounties[bountyId].numSubmissions-1]
  MDeadlineLabel.innerHTML = "Deadline: none"

  populateSubmissionsSelect(bountyId);
  updateSubmissionManager(bountyId)
}

async function populateCreatorSelect(){
  console.log("Populate Manager")
  for (let j = 0; j<ubounties.length;j++){
    if(users[ubounties[j].creatorIndex]==signer._address && ubounties[j].numLeft!=0){
      var opt = document.createElement("option");
      console.log(j)
     opt.value= j;
     opt.innerHTML = j; // whatever property it has

     // then append it to the select element
     document.getElementById("MBountySelect").appendChild(opt);
   }
 }
}

function populateSubmissionsSelect(bountyId) {
  console.log("populateSubmissionsSelect")
  let submissions = ubounties[bountyId].submissions;
  let numSubmissions = ubounties[bountyId].numSubmissions;
  for (let j = 0;j<numSubmissions;j++){
    let s = submissions[j]

      let submitter = s.submitter;
      let submission = s.submission

      var opt = document.createElement("option");
      opt.value= j;
      opt.innerHTML = j; // whatever property it has

      // then append it to the select element
      MSSubmissionSelect.appendChild(opt);

    console.log(j)
  }
}

function updateSubmissionManager(){
  var bountyId = MBountySelect.value
  if(ubounties[bountyId].numSubmissions==0){return}
  var submissionId = MSSubmissionSelect.value
  console.log(bountyId)
  console.log(submissionId)
  MSHunterLabel.innerHTML = "Hunter: " + ubounties[bountyId].submissions[submissionId].submitter
  MSSubmissionLabel.innerHTML = "Submission: " + ubounties[bountyId].submissions[submissionId].submissionString
}


function populateHunterManager() {
  console.log("Populate Hunter Manager")
  OHTable.innerHTML = ""
  PHTable.innerHTML = ""
  for (let j = 0; j<ubounties.length;j++){
    if(ubounties[j].available>0){
      console.log(j)

      let row=document.createElement("tr");
      cell1 = document.createElement("td");
      cell2 = document.createElement("td");
      cell3 = document.createElement("td");
      cell4 = document.createElement("td");
      cell5 = document.createElement("td");
      cell6 = document.createElement("td");
      cell7 = document.createElement("td");

      let creator = users[ubounties[j].creatorIndex]
      let name = ubounties[j].name
      let description = ubounties[j].description
      console.log(ubounties[j].bountyChestIndex)
      let amount = ubounties[j].amount
      let deadline = "none"

      let submissionInput = document.createElement("input")
      submissionInput.placeholder = "submission..."

      let submitButton = document.createElement("input")
      submitButton.type="button"
      submitButton.value = "submit"
      submitButton.onclick = function () {
                submitString(j-1,submissionInput.value)
            };

           textnode1=document.createTextNode(creator);
           textnode2=document.createTextNode(name);
           textnode3=document.createTextNode(description);
           textnode4=document.createTextNode(amount)
           textnode5=document.createTextNode(deadline);

           cell1.appendChild(textnode1);
           cell2.appendChild(textnode2);
           cell3.appendChild(textnode3);
           cell4.appendChild(textnode4);
           cell5.appendChild(textnode5);
           cell6.appendChild(submissionInput);
           cell7.appendChild(submitButton);

          //  console.log(textnode1);
          // console.log(textnode2);
          //  console.log(textnode3);
          //  console.log(amount);
          //  console.log(textnode5);
          //  console.log(textnode6);
          //  console.log(submissionInput);
          //  console.log(submitButton);

           row.appendChild(cell1);
           row.appendChild(cell2);
           row.appendChild(cell3);
           row.appendChild(cell4);
           row.appendChild(cell5);
           row.appendChild(cell6);
           row.appendChild(cell7);

           console.log(row)
          if(ubounties[j].hunterIndex==0){
           OHTable.appendChild(row);
         }else if(users[ubounties[j].hunterIndex] == signer._address){
           PHTable.appendChild(row);
         }
    }
  }
}
//
// function populateCreatorSelect(){
//   console.log("populateCreatorSelect Multi")
//   for (let j = 1; j<ubounties.length;j++){
//     if(creatorList[ubounties[j].creatorIndex]==signer._address && ubounties[j].hunterIndex==0 && ubounties[j].numLeft!=0){
//       var opt = document.createElement("option");
//       console.log(j)
//      opt.value= j;
//      opt.innerHTML = j; // whatever property it has
//
//      // then append it to the select element
//      document.getElementById("BountySelect").appendChild(opt);
//    }
//  }
// }
//
// function populateHunterSelect(){
//   console.log("populateHunterSelect")
//   for (let j = 0; j<multiBounties.length;j++){
//
//      if(multiBounties[j].active==true){
//        var opt = document.createElement("option");
//        opt.value= j;
//        opt.innerHTML = j; // whatever property it has
//
//        // then append it to the select element
//        document.getElementById("BountySelect").appendChild(opt);
//    }
//  }
// }
//

async function fApproveDevcash(){
  let amount = DApproveAmountInput.value;
  approveDevcash(amount)
}

async function fPostOpenBounty(){
  let name = OBNameInput.value
  let description = OBDescriptionInput.value
  let available = OBAvailableInput.value
  let amount = OBAmountInput.value
  //let deadline = OB
  await postOpenBounty(name,description,available,amount,0)
}

async function fPostPersonalBounty(){
  let name = PBNameInput.value
  let description = PBDescriptionInput.value
  let hunter = PBHunterInput.value
  let available = PBAvailableInput.value
  let amount = PBAmountInput.value
  await postPersonalBounty(name,description,hunter,available,amount,0)
}
