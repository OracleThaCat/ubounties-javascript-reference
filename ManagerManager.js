async function populateManagerManager(){
  console.log("populate Manager Manager")

  await populateBountyInfo()
  await populateSubmissionsTable()
  populateSubmissionsSelect()
  populateRevisions()
}



async function populateBountyInfo(){
  var bountyId = MBountySelect.value
  if (bountyId==""){return}

  let creatorAddress = users[ubounties[bountyId].creatorIndex]

  MCreatorLabel.innerHTML = "Poster: " + creatorAddress
  MNameLabel.innerHTML = "Name: " + ubounties[bountyId].name
  MDescriptionLabel.innerHTML = "Description: " + ubounties[bountyId].description
  if(ubounties[bountyId].hunterIndex==0){
    MHunterLabel.innerHTML = "Hunter: Any"
  }else{
    MHunterLabel.innerHTML = "Hunter: " + users[ubounties[bountyId].hunterIndex]
  }
  MAmountLabel.innerHTML = "Amount: " + ubounties[bountyId].amount + " " + symbol
  MAvailableLabel.innerHTML = "Available: " + ubounties[bountyId].available
  //document.getElementById("submissionLabel").innerHTML = "Submission: " + ubounties[bountyId].submissionStrings[ubounties[bountyId].numSubmissions-1]
  MDeadlineLabel.innerHTML = "Deadline: none"
}

async function populateSubmissionsTable(){
  console.log("Populate Submissions Table")

  let selectedBounty = ubounties[MBountySelect.value]
  let submissions = selectedBounty.submissions

  MSTable.innerHTML = ""
  for (let j = 0; j<submissions.length;j++){
      let s = submissions[j]
      console.log(j)

      let row=document.createElement("tr");
      cell0 = document.createElement("td")
      cell1 = document.createElement("td");
      cell2 = document.createElement("td");
      cell3 = document.createElement("td");
      cell4 = document.createElement("td");





      let hunterAddress = ubounties[MBountySelect.value].submissions[j][1]
      let hunterLink = await getAddressLink(hunterAddress,hunterAddress)

      let submission = s[0]
      let revisionsMade = s.revisions.length
      let status = getSubmissionStatus(MBountySelect.value,j)

            textnode0=document.createTextNode(j);
           textnode2=document.createTextNode(submission);
           textnode3=document.createTextNode(revisionsMade);
           textnode4=document.createTextNode(status)

           cell0.appendChild(textnode0);
           cell1.appendChild(hunterLink);
           cell2.appendChild(textnode2);
           cell3.appendChild(textnode3);
           cell4.appendChild(textnode4);



           row.appendChild(cell0);
           row.appendChild(cell1);
           row.appendChild(cell2);
           row.appendChild(cell3);
           row.appendChild(cell4);

        MSTable.appendChild(row)
    }
}
function populateSubmissionsSelect() {
  console.log("Populate Submission Select")
  while(MSubmissionSelect.length>0){
    console.log(MSubmissionSelect.length)
    MSubmissionSelect.remove(MSubmissionSelect.length-1)
  }
  let selectedBounty = MBountySelect.value
  let submissions = ubounties[selectedBounty].submissions;
  let numSubmissions = ubounties[selectedBounty].numSubmissions;
  for (let j = 0;j<numSubmissions;j++){
    let s = submissions[j]

      let submitter = s.submitter;
      let submission = s.submission

      var opt = document.createElement("option");
      opt.value= j;
      opt.innerHTML = j; // whatever property it has

      // then append it to the select element
      MSubmissionSelect.appendChild(opt);

    console.log(j)
  }
}

function populateRevisions(){
  console.log("PopulateRevisions")
  MSRTable.innerHTML = ""
  let bountyId = MBountySelect.value
  if(ubounties[bountyId].numSubmissions==0){return}
  let submissionId = MSubmissionSelect.value
  let s = ubounties[bountyId].submissions[submissionId]

  let numRevisions = s.revisions.length

  for(let j=0;j<numRevisions;j++){
    console.log(j)
    let id = j
    let revision = s.revisions[j]

    let row=document.createElement("tr");

    cell1 = document.createElement("td");
    cell2 = document.createElement("td");

    textnode1=document.createTextNode(id);
    textnode2=document.createTextNode(revision);

    cell1.appendChild(textnode1);
    cell2.appendChild(textnode2);

    row.appendChild(cell1);
    row.appendChild(cell2);

    MSRTable.appendChild(row)
  }
}





async function fContribute(){
  let amount = CAmountInput.value
  let bountyId = MBountySelect.value
  contribute(bountyId,amount)
}

async function fApprove(){
  let uI = MBountySelect.value
  let sI = MSubmissionSelect.value
  let feedback = MFeedbackInput.value
  await approve(uI,sI,feedback)
}

async function fReject(){
  let uI = MBountySelect.value
  let sI = MSubmissionSelect.value
  let feedback = MFeedbackInput.value
  await reject(uI,sI,feedback)
}

async function fRequestRevision(){
  let uI = MBountySelect.value
  let sI = MSubmissionSelect.value
  let feedback = MFeedbackInput.value
  await requestRevision(uI,sI,feedback)
}
