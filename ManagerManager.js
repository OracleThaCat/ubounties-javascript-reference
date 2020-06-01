async function populateManagerManager(){
  console.log("populate Manager Manager")
  populateCreatorSelect()
  let selectedBounty = MBountySelect.value
  console.log(selectedBounty + "  selected bounty")
  populateSubmissionsSelect(selectedBounty);
  updateSubmissionManager(selectedBounty)
}

async function populateCreatorSelect(){
  console.log("Populate Poster Select")
  for (let j = 0; j<ubounties.length;j++){
    if(users[ubounties[j].creatorIndex]==signer._address && ubounties[j].numLeft!=0){
      var opt = document.createElement("option");
      console.log(j)
     opt.value= j;
     opt.innerHTML = j;

     MBountySelect.appendChild(opt);
   }
 }
}

function populateSubmissionsSelect(bountyId) {
  console.log("Populate Submission Select")
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
  console.log("update Submission Manager")
  var bountyId = MBountySelect.value
  if(ubounties[bountyId].numSubmissions==0){return}
  var submissionId = MSSubmissionSelect.value
  console.log(bountyId)
  console.log(submissionId)
  MSHunterLabel.innerHTML = "Hunter: " + ubounties[bountyId].submissions[submissionId][1]
  MSSubmissionLabel.innerHTML = "Submission: " + ubounties[bountyId].submissions[submissionId][0]
}
