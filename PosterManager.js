async function populatePosterManager(){
  console.log("populate Poster Manager")
  await populateCreatorSelect()
}
async function populateCreatorSelect(){
  console.log("Populate Poster Select")

  for (let j = 0; j<ubounties.length;j++){
    if(users[ubounties[j].creatorIndex]==signer._address && ubounties[j].available!=0){
      var opt = document.createElement("option");
      console.log(j)
     opt.value= j;
     opt.innerHTML = j;
     MBountySelect.appendChild(opt);
   }
 }
}
