//      let creatorLink = await getAddressLink(creatorAddress,creatorAddress)

async function populateHunterManager() {
  console.log("Populate Hunter Manager")
  OHTable.innerHTML = ""
  PHTable.innerHTML = ""
  HSTable.innerHTML = ""

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
      cell7 = document.createElement("td");
      cell8 = document.createElement("td");

      let creatorAddress = users[ubounties[j].creatorIndex]
      let creatorLink = await getAddressLink(creatorAddress,creatorAddress)

      let name = ubounties[j].name
      let description = ubounties[j].description
      console.log(ubounties[j].bountyChestIndex)

      let rewardAddress = await getBountyChest(ubounties[j].bountyChestIndex)
      let rewardText = ubounties[j].amount + " " + symbol
      let rewardLink = await getAddressLink(rewardText,rewardAddress)

      let ethRewardText = ubounties[j].ethAmount + " ETH"

      let deadline = "none"

      let submissionInput = document.createElement("input")
      submissionInput.placeholder = "submission..."

      let submitButton = document.createElement("input")
      submitButton.type="button"
      submitButton.value = "submit"
      submitButton.onclick = function () {
        console.log(j)
        console.log(submissionInput.values)
                submit(j,submissionInput.value)
            };

           textnode2=document.createTextNode(name);
           textnode3=document.createTextNode(description);
           textnode4=document.createTextNode(ethRewardText)
           textnode5=document.createTextNode(deadline);

           cell1.appendChild(creatorLink);
           cell2.appendChild(textnode2);
           cell3.appendChild(textnode3);
           cell4.appendChild(rewardLink);
           cell5.appendChild(textnode4)
           cell6.appendChild(textnode5);
           cell7.appendChild(submissionInput);
           cell8.appendChild(submitButton);

           row.appendChild(cell1);
           row.appendChild(cell2);
           row.appendChild(cell3);
           row.appendChild(cell4);
           row.appendChild(cell5);
           row.appendChild(cell6);
           row.appendChild(cell7);
           row.appendChild(cell8);

          if(ubounties[j].hunterIndex==0){
           OHTable.appendChild(row);
           await addSubmissions(j)
         }else if(users[ubounties[j].hunterIndex] == signer._address){
           PHTable.appendChild(row);
           await addSubmissions(j)
         }
    }
  }
}

  async function addSubmissions(ubountyIndex){

    let bounty = ubounties[ubountyIndex]
    let submissions = bounty.submissions
    if (submissions.length==0){return}
    for (let j = 0; j<submissions.length;j++){
      let s = submissions[j]
      if(s[1]==signer._address){
        await addSubmission(ubountyIndex,j)
      }
    }
  }

  async function addSubmission(uI,sI){
    console.log("Add " + uI + " " + sI)

    let s = ubounties[uI].submissions[sI]

    let row=document.createElement("tr");
    cell1 = document.createElement("td");
    cell2 = document.createElement("td");
    cell3 = document.createElement("td");
    cell4 = document.createElement("td");
    cell5 = document.createElement("td");
    cell6 = document.createElement("td");
    cell7 = document.createElement("td");
    cell8 = document.createElement("td");
    cell9 = document.createElement("td");

    let name = ubounties[uI].name

    let posterAddress = users[ubounties[uI].creatorIndex]
    let posterLink = await getAddressLink(posterAddress,posterAddress)

    let submission = s[0]

    let rewardText = ubounties[uI].amount + " " + symbol
    let rewardAddress = await getBountyChest(ubounties[uI].bountyChestIndex)
    let rewardLink = await getAddressLink(rewardText,rewardAddress)
    
    let ethRewardText = ubounties[uI].ethAmount + " ETH"

    let status = getSubmissionStatus(uI,sI)
    let deadline = "none"

    let revisionInput = document.createElement("input")
    revisionInput.placeholder = "revision..."

    let reviseButton = document.createElement("input")
    reviseButton.type="button"
    reviseButton.value = "revise"
    reviseButton.onclick = function () {
              revise(uI,sI,revisionInput.value)
          };

          textnode1=document.createTextNode(name);
          textnode3=document.createTextNode(submission);
          textnode4=document.createTextNode(ethRewardText)
          textnode5=document.createTextNode(deadline);
          statusTextNode=document.createTextNode(status);

          cell1.appendChild(textnode1);
          cell2.appendChild(posterLink);
          cell3.appendChild(textnode3);
          cell4.appendChild(rewardLink);
          cell5.appendChild(textnode4)
          cell6.appendChild(textnode5);
          cell7.appendChild(revisionInput);
          cell8.appendChild(reviseButton);
          cell9.appendChild(statusTextNode);

          row.appendChild(cell1);
          row.appendChild(cell2);
          row.appendChild(cell3);
          row.appendChild(cell4);
          row.appendChild(cell5);
          row.appendChild(cell6);
          row.appendChild(cell7);
          row.appendChild(cell8);
          row.appendChild(cell9);

    HSTable.appendChild(row)

  }
  //   for (let j = 0; j<ubounties.length;j++){
  //     if(ubounties[j].available>0){
  //       console.log(j)
  //
  //       let row=document.createElement("tr");
  //       cell1 = document.createElement("td");
        cell2 = document.createElement("td");
        cell3 = document.createElement("td");
        cell4 = document.createElement("td");
        cell5 = document.createElement("td");
        cell6 = document.createElement("td");
        cell7 = document.createElement("td");
  //
  //       let creator = users[ubounties[j].creatorIndex]
  //       let name = ubounties[j].name
  //       let description = ubounties[j].description
  //       console.log(ubounties[j].bountyChestIndex)
  //       let amount = ubounties[j].amount
  //       let deadline = "none"
  //
  //       let submissionInput = document.createElement("input")
  //       submissionInput.placeholder = "submission..."
  //
  //       let submitButton = document.createElement("input")
  //       submitButton.type="button"
  //       submitButton.value = "submit"
  //       submitButton.onclick = function () {
  //         console.log(j)
  //         console.log(submissionInput.values)
  //                 submit(j,submissionInput.value)
  //             };
  //
  //            textnode1=document.createTextNode(creator);
  //            textnode2=document.createTextNode(name);
  //            textnode3=document.createTextNode(description);
  //            textnode4=document.createTextNode(amount)
  //            textnode5=document.createTextNode(deadline);
  //
  //            cell1.appendChild(textnode1);
  //            cell2.appendChild(textnode2);
  //            cell3.appendChild(textnode3);
  //            cell4.appendChild(textnode4);
  //            cell5.appendChild(textnode5);
  //            cell6.appendChild(submissionInput);
  //            cell7.appendChild(submitButton);
  //
  //           //  console.log(textnode1);
  //           // console.log(textnode2);
  //           //  console.log(textnode3);
  //           //  console.log(amount);
  //           //  console.log(textnode5);
  //           //  console.log(textnode6);
  //           //  console.log(submissionInput);
  //           //  console.log(submitButton);
  //
  //            row.appendChild(cell1);
  //            row.appendChild(cell2);
  //            row.appendChild(cell3);
  //            row.appendChild(cell4);
  //            row.appendChild(cell5);
  //            row.appendChild(cell6);
  //            row.appendChild(cell7);
  //
  //            console.log(row)
  //           if(ubounties[j].hunterIndex==0){
  //            OHTable.appendChild(row);
  //          }else if(users[ubounties[j].hunterIndex] == signer._address){
  //            PHTable.appendChild(row);
  //          }
  // }
//}
