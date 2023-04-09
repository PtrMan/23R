import std/[asyncnet, asyncdispatch]

import std/strformat
#import std/parseutils
#import system/io
import tables
import random

import md5

import nar
#import tv
import term
#import nlp2 # NLP module

narInit()

# queue with messages of op executions to be sent to client
var opExecMsgQueue: seq[string] = @[]

# op for testing
proc op0(args: seq[TermObj]) =
  echo("main: ^op0 was invoked")
  opExecMsgQueue.add(&"^op0 with {convTermToStr(args[0])}, {convTermToStr(args[1])}")

globalNarInstance.opRegistry.ops["^op0"] = op0 # op for testing
globalNarInstance.opRegistry.ops["^n9ExecAndInj"] = opLibNal9ExecAndInj # NAL-9


var forwardConclQueue: seq[SentenceObj] = @[]

# conclusion handler which adds the conclusion to a queue to be sent to the clients
proc forwardConclhandler(concl: SentenceObj) =
  forwardConclQueue.add(concl)

globalNarInstance.conclCallback = forwardConclhandler






# Create the socket
var socket = newAsyncSocket()



block:
  # Connect to the server
  let host = "127.0.0.1"
  let port: Port = Port(1237)
  waitFor socket.connect(host, port)
  echo "net: Connected to the server"


  var recvFuture: Future[system.string] = socket.recvLine()

  
  while true:
    poll(25)

    if recvFuture.finished:
      echo "DBG: recvFuture finished"

      if not recvFuture.failed:
        let recvMsg: string = recvFuture.read
        echo "net: recv=", recvMsg

        let recvNarsese: string = recvMsg
        echo "net: recv.narsese=", recvNarsese

        parseNarInputAndPut(recvMsg)  # try to parse as narsese


        # send acknowledgement as input message to client
        block:
          # compute unique id for networking
          let uniqueId: string = getMd5(recvMsg&(&"{rand(0xfffffff)}"))

          let json: string = fmt"{{""narsese"":""{recvNarsese}"", ""uniqueId"":""{uniqueId}"", ""type"":""narseseInput""}}"
          let send: string = json&"\n"
          waitFor socket.send(send)

      
      recvFuture = socket.recvLine()


    # declarative
    ctrlStep()
    ctrlQaStep()
    
    # procedural
    proceduralStep()
    proceduralAdvanceTime(1) # advance time

    
    # send op execs to server
    block:
      for iOpExecMsg in opExecMsgQueue:
        let uniqueId: string = getMd5(iOpExecMsg&(&"{rand(0xfffffff)}"))

        let json: string = fmt"{{""narsese"":""{iOpExecMsg}"", ""uniqueId"":""{uniqueId}"", ""type"":""opExecMsg""}}"
        let send: string = json&"\n"
        waitFor socket.send(send)
      opExecMsgQueue = @[]

    # send conclusion to server
    for iDerivedConcl in forwardConclQueue:
      let conclSentenceAsStr: string = convSentenceToStr(iDerivedConcl)

      # compute unique id for networking
      let uniqueId: string = getMd5(conclSentenceAsStr&(&"{rand(0xfffffff)}"))

      let json: string = fmt"{{""narsese"":""{conclSentenceAsStr}"", ""uniqueId"":""{uniqueId}"", ""type"":""deriv""}}"
      let send: string = json&"\n"
      waitFor socket.send(send)

    forwardConclQueue = @[] # flush because we sent it to the server



# TODO UI< add handling of NLP input from web-UI! >
