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
}
