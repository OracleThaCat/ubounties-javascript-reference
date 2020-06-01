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
        console.log(j)
        console.log(submissionInput.values)
                submit(j,submissionInput.value)
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
