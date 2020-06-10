//blocks to read events from

let fromBlock = 7990783
let toBlock = 8100783

async function gatherEventLogs(){
	console.log("gather Logs")
	event_logs = new Object()

	let provider = ethers.getDefaultProvider("ropsten");

	let createdTopic = ethers.utils.id("created(uint256,uint256,uint256,uint256)")
	let submittedTopic = ethers.utils.id("submitted(uint256,uint256)");
	let revisedTopic = ethers.utils.id("revised(uint256,uint256,uint256)");
	let approvedTopic = ethers.utils.id("approved(uint256,uint256,string)");
	let rejectedTopic = ethers.utils.id("rejected(uint256,uint256,string)");
	let revisionRequestedTopic = ethers.utils.id("revisionRequested(uint256,uint256,string)");
	let rewardedTopic = ethers.utils.id("rewarded(uint256,address,uint256,uint256)");
	let reclaimedTopic = ethers.utils.id("reclaimed(uint256,uint256,uint256)");
	let completedTopic = ethers.utils.id("completed(uint256)");
	let feeChangeTopic = ethers.utils.id("feeChange(uint256,uint256)");
	let waiverChangeTopic = ethers.utils.id("waiverChange(uint256,uint256)");


	let createdFilter = createFilter(createdTopic)
	let submittedFilter = createFilter(submittedTopic)
	let revisedFilter = createFilter(revisedTopic)
	let approvedFilter = createFilter(approvedTopic)
	let rejectedFilter = createFilter(rejectedTopic)
	let revisionRequestedFilter = createFilter(revisionRequestedTopic)
	let rewardedFilter = createFilter(rewardedTopic)
	let reclaimedFilter = createFilter(reclaimedTopic)
	let completedFilter = createFilter(completedTopic)
  let feeChangedFilter = createFilter(feeChangeTopic)
	let waiverChangedFilter = createFilter(waiverChangeTopic)

	let createdLogs = await provider.getLogs(createdFilter)
	let submittedLogs = await provider.getLogs(submittedFilter)
	let revisedLogs = await provider.getLogs(revisedFilter)
	let approvedLogs = await provider.getLogs(approvedFilter)
	let rejectedLogs = await provider.getLogs(rejectedFilter)
	let revisionRequestedLogs = await provider.getLogs(revisionRequestedFilter)
	let rewardedLogs = await provider.getLogs(rewardedFilter)
	let reclaimedLogs = await provider.getLogs(reclaimedFilter)
	let completedLogs= await provider.getLogs(completedFilter)
  let feeChangedLogs = await provider.getLogs(feeChangedFilter)
	let waiverChangedLogs = await provider.getLogs(waiverChangedFilter)

	let createdInfo = await getCreatedInfo(createdLogs)
	let submittedInfo = await getSubmittedInfo(submittedLogs)
	let revisedInfo = await getRevisedInfo(revisedLogs)
	let approvedInfo = await getApprovedInfo(approvedLogs)
	let rejectedInfo = await getRejectedInfo(rejectedLogs)
	let revisionRequestedInfo = await getRevisionRequestedInfo(revisionRequestedLogs)
	let rewardedInfo = await getRewardedInfo(rewardedLogs)
	let reclaimedInfo = await getReclaimedInfo(reclaimedLogs)
	let completedInfo = await getCompletedInfo(completedLogs)
  let feeChangedInfo = await getFeeChangedInfo(feeChangedLogs)
	let waiverChangedInfo = await getWaiverChangedInfo(waiverChangedLogs)

  let orderedFeedback = await getOrderedFeedback(approvedLogs,rejectedLogs,revisionRequestedLogs)


	event_logs.created = createdInfo
	event_logs.submitted = submittedInfo
	event_logs.revised = revisedInfo
	event_logs.approved = approvedInfo
	event_logs.rejected = rejectedInfo
	event_logs.revisionRequested = revisionRequestedInfo
	event_logs.rewarded = rewardedInfo
	event_logs.reclaimed = reclaimedInfo
	event_logs.completed = completedInfo
  event_logs.feeChanged = feeChangedInfo
	event_logs.waiverChanged = waiverChangedInfo

  event_logs.orderedFeedback = orderedFeedback

}


function createFilter(topic){
  let filter = {
		address: ubcAddress,
		fromBlock: fromBlock,
		toBlock: toBlock,
		topics: [ topic ]
	}
  return(filter)
}

function ArrayifyLogData(logs) {
	let events = new Array()
	for (n=0;n<logs.length;n++){
		let log = new Object()
		let data = logs[n].data
		data = data.substring(2)
		data = data.match(/.{1,64}/g) //divide data from event log into 64 length sections
		for (j=0;j<data.length;j++){
			data[j] = "0x" + data[j]
		}
		events.push(data)
	}
	return(events)
}

function HexToAddress(hex){
	return("0x" + hex.substring(26))
}

function HexToInt(hex,decimals){
	return(ethers.utils.formatUnits(ethers.utils.bigNumberify(hex),decimals))
}

function HexToString(hex) {
	return(web3.toAscii(hex))
}

async function getTimeStamp(blockNumber){
  let provider = ethers.getDefaultProvider("ropsten")
  let block = await provider.getBlock(blockNumber)
  return block.timestamp
}

async function getNonce(txHash){
  let provider = ethers.getDefaultProvider("ropsten")
  let tx = await provider.getTransaction(txHash)
  return(tx.nonce)
}

async function getCreatedInfo(createdLogs){
  let createdHexArray = ArrayifyLogData(createdLogs)
  let createdInfo = new Array()

  for (n=0;n<createdLogs.length;n++){
  		let log = createdHexArray[n]
  		let eventInfo = new Object()
  		eventInfo.ubountyIndex = HexToInt(log[0],0)
			eventInfo.bountiesAvailable = HexToInt(log[1],0)
  		eventInfo.bountyAmount  = HexToInt(log[2],decimals)
			eventInfo.ethBountyAmount = HexToInt(log[3],18)
      eventInfo.eventInfo = createdLogs[n]
      eventInfo.timestamp = await getTimeStamp(createdLogs[n].blockNumber)
      eventInfo.nonce = await getNonce(createdLogs[n].transactionHash)
  		createdInfo.push(eventInfo)
  	}
    return(createdInfo)
}

async function getSubmittedInfo(submittedLogs){
  let submittedHexArray = ArrayifyLogData(submittedLogs)
  let submittedInfo = new Array()

  for (n=0;n<submittedHexArray.length;n++){
  		let log = submittedHexArray[n]
  		let eventInfo = new Object()
  		eventInfo.ubountyIndex = HexToInt(log[0],0)
  		eventInfo.submissionIndex  = HexToInt(log[1],0)
      eventInfo.eventInfo = submittedLogs[n]
      eventInfo.timestamp = await getTimeStamp(submittedLogs[n].blockNumber)
      eventInfo.nonce = await getNonce(submittedLogs[n].transactionHash)

  		submittedInfo.push(eventInfo)
  	}
    return(submittedInfo)
}
async function getRevisedInfo(revisedLogs){
  let revisedHexArray = ArrayifyLogData(revisedLogs)
  let revisedInfo = new Array()

  for (n=0;n<revisedHexArray.length;n++){
  		let log = revisedHexArray[n]
  		let eventInfo = new Object()
  		eventInfo.ubountyIndex = HexToInt(log[0],0)
  		eventInfo.submissionIndex  = HexToInt(log[0],0)
  		eventInfo.revisionIndex = HexToInt(log[0],0)
      eventInfo.eventInfo = revisedLogs[n]
      eventInfo.timestamp = await getTimeStamp(revisedLogs[n].blockNumber)
      eventInfo.nonce = await getNonce(revisedLogs[n].transactionHash)
  		revisedInfo.push(eventInfo)
  	}
    return(revisedInfo)
}
async function getApprovedInfo(approvedLogs){
  let approvedHexArray = ArrayifyLogData(approvedLogs)

  let approvedInfo = new Array()
  for (n=0;n<approvedHexArray.length;n++){
  		let log = approvedHexArray[n]
  		let eventInfo = new Object()
  		eventInfo.ubountyIndex = HexToInt(log[0],0)
  		eventInfo.submissionIndex  = HexToInt(log[1],0)
      eventInfo.feedback = ""
      for (let j=4;j<log.length;j++){
        eventInfo.feedback += HexToString(log[j])
  		}

      eventInfo.eventInfo = approvedLogs[n]
      eventInfo.timestamp = await getTimeStamp(approvedLogs[n].blockNumber)
      eventInfo.nonce = await getNonce(approvedLogs[n].transactionHash)
  		approvedInfo.push(eventInfo)
  	}
    return(approvedInfo)
}
async function getRejectedInfo(rejectedLogs){
  let rejectedHexArray = ArrayifyLogData(rejectedLogs)

  let rejectedInfo = new Array()
  for (n=0;n<rejectedHexArray.length;n++){
  		let log = rejectedHexArray[n]
  		let eventInfo = new Object()
  		eventInfo.ubountyIndex = HexToInt(log[0],0)
  		eventInfo.submissionIndex  = HexToInt(log[1],0)
      eventInfo.feedback = ""
      for (let j=4;j<log.length;j++){
        eventInfo.feedback += HexToString(log[j])
  		}

      eventInfo.eventInfo = rejectedLogs[n]
      eventInfo.timestamp = await getTimeStamp(rejectedLogs[n].blockNumber)
      eventInfo.nonce = await getNonce(rejectedLogs[n].transactionHash)
  		rejectedInfo.push(eventInfo)
  	}
    return(rejectedInfo)
}
async function getRevisionRequestedInfo(revisionRequestedLogs){
  let revisionRequestedHexArray = ArrayifyLogData(revisionRequestedLogs)

  let revisionRequestedInfo = new Array()
  for (n=0;n<revisionRequestedHexArray.length;n++){
  		let log = revisionRequestedHexArray[n]
  		let eventInfo = new Object()
  		eventInfo.ubountyIndex = HexToInt(log[0],0)
  		eventInfo.submissionIndex  = HexToInt(log[1],0)
      eventInfo.feedback = ""
      for (let j=4;j<log.length;j++){
        eventInfo.feedback += HexToString(log[j])
  		}

      eventInfo.eventInfo = revisionRequestedLogs[n]
      eventInfo.timestamp = await getTimeStamp(revisionRequestedLogs[n].blockNumber)
      eventInfo.nonce = await getNonce(revisionRequestedLogs[n].transactionHash)
  		revisionRequestedInfo.push(eventInfo)
  	}
    return(revisionRequestedInfo)
}
async function getRewardedInfo(rewardedLogs){
  let rewardedHexArray = ArrayifyLogData(rewardedLogs)

  let rewardedInfo = new Array()
  for (n=0;n<rewardedHexArray.length;n++){
  		let log = rewardedHexArray[n]
  		let eventInfo = new Object()
  		eventInfo.ubountyIndex = HexToInt(log[0],0)
  		eventInfo.hunter  = HexToAddress(log[1])
  		eventInfo.rewardAmount = HexToInt(log[2],decimals)
			eventInfo.ethRewardAmount = HexToInt(log[3],18)
      eventInfo.eventInfo = rewardedLogs[n]
      eventInfo.timestamp = await getTimeStamp(rewardedLogs[n].blockNumber)
      eventInfo.nonce = await getNonce(rewardedLogs[n].transactionHash)
  		rewardedInfo.push(eventInfo)
  	}
    return(rewardedInfo)
}
async function getReclaimedInfo(reclaimedLogs){
  let reclaimedHexArray = ArrayifyLogData(reclaimedLogs)

  let reclaimedInfo = new Array()
  for (n=0;n<reclaimedHexArray.length;n++){
  		let log = reclaimedHexArray[n]
  		let eventInfo = new Object()
  		eventInfo.ubountyIndex = HexToInt(log[0],0)
  		eventInfo.reclaimedAmount  = HexToInt(log[1],8)
			eventInfo.ethReclaimedAmount = HexToInt(log[2],18)

      eventInfo.eventInfo = reclaimedLogs[n]
      eventInfo.timestamp = await getTimeStamp(reclaimedLogs[n].blockNumber)
      eventInfo.nonce = await getNonce(reclaimedLogs[n].transactionHash)
  		reclaimedInfo.push(eventInfo)
  	}
    return(reclaimedInfo)
}
async function getCompletedInfo(completedLogs){
  let completedHexArray = ArrayifyLogData(completedLogs)

  let completedInfo = new Array()
  for (n=0;n<completedHexArray.length;n++){
  		let log = completedHexArray[n]
  		let eventInfo = new Object()
  		eventInfo.ubountyIndex = HexToInt(log[0],0)

      eventInfo.eventInfo = completedLogs[n]
      eventInfo.timestamp = await getTimeStamp(completedLogs[n].blockNumber)
      eventInfo.nonce = await getNonce(completedLogs[n].transactionHash)
  		completedInfo.push(eventInfo)
  	}
    return(completedInfo)
}

async function getFeeChangedInfo(feeChangedLogs){
  let feeChangedHexArray = ArrayifyLogData(feeChangedLogs)

  let feeChangedInfo = new Array()
  for (n=0;n<feeChangedHexArray.length;n++){
  		let log = feeChangedHexArray[n]
  		let eventInfo = new Object()
  		eventInfo.oldFee = HexToInt(log[0],8)
  		eventInfo.newFee  = HexToInt(log[1],8)

      eventInfo.eventInfo = feeChangedLogs[n]
      eventInfo.timestamp = await getTimeStamp(feeChangedLogs[n].blockNumber)
      eventInfo.nonce = await getNonce(feeChangedLogs[n].transactionHash)
  		feeChangedInfo.push(eventInfo)
  	}
    return(feeChangedInfo)
}

async function getWaiverChangedInfo(waiverChangedLogs){
  let waiverChangedHexArray = ArrayifyLogData(waiverChangedLogs)

  let waiverChangedInfo = new Array()
  for (n=0;n<waiverChangedHexArray.length;n++){
  		let log = waiverChangedHexArray[n]
  		let eventInfo = new Object()
  		eventInfo.oldWaiver = HexToInt(log[0],8)
  		eventInfo.newWaiver  = HexToInt(log[1],8)

      eventInfo.eventInfo = waiverChangedLogs[n]
      eventInfo.timestamp = await getTimeStamp(waiverChangedLogs[n].blockNumber)
      eventInfo.nonce = await getNonce(waiverChangedLogs[n].transactionHash)
  		waiverChangedInfo.push(eventInfo)
  	}
    return(waiverChangedInfo)
}

async function getOrderedFeedback(approvedLogs,rejectedLogs,revisionRequestedLogs){
  let approvedHexArray = ArrayifyLogData(approvedLogs)
  let rejectedHexArray = ArrayifyLogData(rejectedLogs)
  let revisionRequestedHexArray = ArrayifyLogData(revisionRequestedLogs)

  let feedbackInfo = new Array()

  for (n=0;n<approvedHexArray.length;n++){
  		let log = approvedHexArray[n]
      let uI = parseInt(HexToInt(log[0],0))
      let sI = parseInt(HexToInt(log[1],0))
      let eventInfo = new Object
      let feedback = ""

      for (let j=4;j<log.length;j++){
        feedback += HexToString(log[j])
  		}
      if(feedbackInfo[uI]==undefined){
        feedbackInfo[uI] = new Array()
      }
      if(feedbackInfo[uI][sI]==undefined){
        feedbackInfo[uI][sI] = new Array()
      }
      eventInfo.event = "Approved"
      eventInfo.feedback = feedback
      eventInfo.nonce = await getNonce(approvedLogs[n].transactionHash)
      eventInfo.timestamp = await getTimeStamp(revisionRequestedLogs[n].blockNumber)
  		feedbackInfo[uI][sI].push(eventInfo)
  	}

    for (n=0;n<rejectedHexArray.length;n++){
    		let log = rejectedHexArray[n]
        let uI = parseInt(HexToInt(log[0],0))
        let sI = parseInt(HexToInt(log[1],0))
        let eventInfo = new Object
        let feedback = ""

        for (let j=4;j<log.length;j++){
          feedback += HexToString(log[j])
    		}
        if(feedbackInfo[uI]==undefined){
          feedbackInfo[uI] = new Array()
        }
        if(feedbackInfo[uI][sI]==undefined){
          feedbackInfo[uI][sI] = new Array()
        }
        eventInfo.event = "Rejected"
        eventInfo.feedback = feedback
        eventInfo.nonce = await getNonce(rejectedLogs[n].transactionHash)
        eventInfo.timestamp = await getTimeStamp(revisionRequestedLogs[n].blockNumber)
    		feedbackInfo[uI][sI].push(eventInfo)
    	}

      for (n=0;n<revisionRequestedHexArray.length;n++){
      		let log = revisionRequestedHexArray[n]
          let uI = parseInt(HexToInt(log[0],0))
          let sI = parseInt(HexToInt(log[1],0))
          let eventInfo = new Object
          let feedback = ""

          for (let j=4;j<log.length;j++){
            feedback += HexToString(log[j])
      		}
          if(feedbackInfo[uI]==undefined){
            feedbackInfo[uI] = new Array()
          }
          if(feedbackInfo[uI][sI]==undefined){
            feedbackInfo[uI][sI] = new Array()
          }
          eventInfo.event = "Revision Requested"
          eventInfo.feedback = feedback
          eventInfo.nonce = await getNonce(revisionRequestedLogs[n].transactionHash)
          eventInfo.timestamp = await getTimeStamp(revisionRequestedLogs[n].blockNumber)
      		feedbackInfo[uI][sI].push(eventInfo)
      	}

        for(let p = 0;p<feedbackInfo.length;p++){
          if(feedbackInfo[p]!=undefined){
            for(let q = 0;q<feedbackInfo[p].length;q++){
              if(feedbackInfo[p][q]!=undefined){
                  feedbackInfo[p][q].sort((a,b)=>a.nonce-b.nonce)
              }
            }
          }
        }

        return(feedbackInfo)

}


async function getOrderedApprovedInfo(approvedHexArray){
  let approvedInfo = new Array()
  for (n=0;n<approvedHexArray.length;n++){
  		let log = approvedHexArray[n]
      let uI = parseInt(HexToInt(log[0],0))
      let sI = parseInt(HexToInt(log[1],0))
      let feedback = ""

      for (let j=4;j<log.length;j++){
        feedback += HexToString(log[j])
  		}
      if(approvedInfo[uI]==undefined){
        approvedInfo[uI] = new Array()
      }
      if(approvedInfo[uI][sI]==undefined){
        approvedInfo[uI][sI] = new Array()
      }
  		approvedInfo[uI][sI].push(feedback)
  	}
    return(approvedInfo)
}
async function getOrderedRejectedInfo(rejectedHexArray){
  let rejectedInfo = new Array()
  for (n=0;n<rejectedHexArray.length;n++){
  		let log = rejectedHexArray[n]
      let uI = parseInt(HexToInt(log[0],0))
      let sI = parseInt(HexToInt(log[1],0))
      let feedback = ""

      for (let j=4;j<log.length;j++){
        feedback += HexToString(log[j])
  		}
      if(rejectedInfo[uI]==undefined){
        rejectedInfo[uI] = new Array()
      }
      if(rejectedInfo[uI][sI]==undefined){
        rejectedInfo[uI][sI] = new Array()
      }
  		rejectedInfo[uI][sI].push(feedback)
  	}
    return(rejectedInfo)
}
async function getOrderedRevisionRequestedInfo(revisionRequestedHexArray){
  let revisionRequestedInfo = new Array()
  for (n=0;n<revisionRequestedHexArray.length;n++){
  		let log = revisionRequestedHexArray[n]
      let uI = parseInt(HexToInt(log[0],0))
      let sI = parseInt(HexToInt(log[1],0))
      let feedback = ""

      for (let j=4;j<log.length;j++){
        feedback += HexToString(log[j])
  		}
      if(revisionRequestedInfo[uI]==undefined){
        revisionRequestedInfo[uI] = new Array()
      }
      if(revisionRequestedInfo[uI][sI]==undefined){
        revisionRequestedInfo[uI][sI] = new Array()
      }
  		revisionRequestedInfo[uI][sI].push(feedback)
  	}
    return(revisionRequestedInfo)
}



async function getAwarded() {
	console.log("get Event Logs")
	let eventLogs = new Array()

	let topic = ethers.utils.id("awarded(address,address,string,uint256)");
	let filter = {
    address: "0xe1074d040de6a7ab526a45ef6439a68e64026f5a",//"0x7DE09eE61Fd4c326098bE7C4C86b80408707DB9b",
    fromBlock: 10000000,
    toBlock: 11111111,
    topics: [ topic ]
	}

	let provider = ethers.getDefaultProvider("ropsten")

	let result = await provider.getLogs(filter)	//get event logs of all instances of bounties awarded
	console.log(result)
	for (n=0;n<result.length;n++){
		let log = new Object()
		let data = result[n].data
		data = data.substring(2)
		data = data.match(/.{1,64}/g) //divide data from event log into 64 length sections
		for (j=0;j<6;j++){
			data[j] = "0x" + data[j]
		}
		let descriptionData = ""
		for (j=5;j<data.length;j++){
			descriptionData += data[j]
		}
		let poster = "0x" + data[0].substring(26)
		let hunter = "0x" + data[1].substring(26)
		let amount = ethers.utils.formatUnits(ethers.utils.bigNumberify(data[3]),8)
		let description = web3.toAscii(descriptionData)
		log.poster = poster
		log.hunter = hunter
		log.amount = amount
		log.description = description
		log.txHash = result[n].transactionHash
		eventLogs.push(log)
	}
}

function getSubmissionStatus(uI,sI){
	try{
		let events = event_logs.orderedFeedback[uI][sI]
		return(events[events.length-1].event)
	} catch {
		return("awaiting feedback")
	}
}
