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
let event_logs

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
  await gatherEventLogs()
	populateFrontend()

}

async function populateFrontend(){
  console.log("Populate Frontend")
  getElements()
  await populateBalance()
  await populatePosterManager()
  await populateHunterManager()
  await populateManagerManager()
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
  console.log("Populate Balance")
  ETHBalanceLabel.innerHTML = "Eth Balance: " + await getETHBalance()
  DBalanceLabel.innerHTML = "Devcash Balance: " + await getDevcashBalance()
  DApprovedLabel.innerHTML = "Approved Devcash: " + await getApprovedBalance()
}




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

async function getAddressLink(displayText, address){
  let link = document.createElement("a")
  link.innerHTML = displayText

  let network = (await signer.provider.getNetwork()).name


  if (network=="homestead"){
    link.href ="https://etherscan.io/address/" + address
  } else{
    link.href = "https://" + network + ".etherscan.io/address/" + address
  }
  
  return(link)
}
