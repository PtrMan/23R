import std/strformat
import std/parseutils
import system/io
import tables
import os
import strutils

import nar
import tv
import term
import nlp3 # NLP module

import moduleNlp3/moduleNlp3 # NLP module


#import narsese

# shell frontend for Nar

# compile and run with
#    nim compile --run entryShell.nim

narInit()










# op for testing
proc op0(args:seq[TermObj]) =
  echo("main: ^op0 was invoked")








if isMainModule: # manually testing procedural reasoning
  block:
    var createdRegOp: RegisteredOpRef = makeOp(op0)
    globalNarInstance.opRegistry.ops["^op0"] = createdRegOp




  echo("ENTER manual test")

  #let goalMem: MemObj = MemObj(concepts: @[])


  if false: # manually testing of building of sequence
    if true:
      # add testing goal
      let term = termMkName("a2")
      var inSentence: SentenceObj = new(SentenceObj)
      inSentence.term = term
      inSentence.punct = goal
      insentence.tv = makeTv(1.0, 0.92)
      inSentence.stamp = makeStamp()
      var inEvent: EventObj = EventObj(s:inSentence)
      goalSystemPutGoal(inEvent, globalNarInstance.goalMem, false)


    if false: # disabled because  derivation (a0,a1)! a1.:|: |- a0.:|: works
      # add testing goal
      let term0 = termMkName("a0")
      let term1 = termMkName("a1")
      let term2 = termMkSeq(term0, term1)

      var inSentence: SentenceObj = new(SentenceObj)
      inSentence.term = term2
      inSentence.punct = goal
      insentence.tv = makeTv(1.0, 0.92)
      inSentence.stamp = makeStamp()
      var inEvent: EventObj = EventObj(s:inSentence)
      goalSystemPutGoal(inEvent, globalNarInstance.goalMem, false)


    # add testing (perceived) judgement event
    block:
      block:
        let term = termMkName("a0")
        var inSentence: SentenceObj = new(SentenceObj)
        inSentence.term = term
        inSentence.punct = judgement
        insentence.tv = makeTv(1.0, 0.92)
        inSentence.stamp = makeStamp()
        proceduralInputPerceiveAtCurrentTime(inSentence, globalNarInstance.mem)
        proceduralAdvanceTime(1)

      block:
        let term = termMkName("a1")
        var inSentence: SentenceObj = new(SentenceObj)
        inSentence.term = term
        inSentence.punct = judgement
        insentence.tv = makeTv(1.0, 0.92)
        inSentence.stamp = makeStamp()
        proceduralInputPerceiveAtCurrentTime(inSentence, globalNarInstance.mem)
        proceduralAdvanceTime(1)

      block:
        let term = termMkName("a2")
        var inSentence: SentenceObj = new(SentenceObj)
        inSentence.term = term
        inSentence.punct = judgement
        insentence.tv = makeTv(1.0, 0.92)
        inSentence.stamp = makeStamp()
        proceduralInputPerceiveAtCurrentTime(inSentence, globalNarInstance.mem)
        proceduralAdvanceTime(1)

    for iStep in 0..2-1:  
      echo("main: do procedural step of NAR")
      proceduralStep()

      proceduralShowAllBeliefs("mem")
      proceduralShowAllBeliefs("goalMem")

      echo("")
      echo("")
      echo("")
      echo("")
      echo("")

  if true:
    # test parsing etc.
    #parseNarInputAndPut("<a-->b>.:|:") # BUG: doesn't parse correctly!
    discard

  echo("EXIT  manual test")


# /return true if the outer loop should >continue<
proc parseLine(line: string): bool =
  if line.len > 0 and line[0] == '>': # NLP input
    let nlText: string = line[1..line.len-1]
    let statements: seq[TermObj] = runModuleNlp4(nlText)
    for iStatement in statements:
      echo &"DBG: narsese from NLU ={convTermToStr(iStatement)}"

      # feed into NAR
      var inSentence: SentenceObj = new (SentenceObj)
      inSentence.term = iStatement
      inSentence.punct = judgement
      inSentence.tv = makeTv(1.0, 0.92)
      inSentence.stamp = makeStamp()
      proceduralInputPerceiveAtCurrentTime(inSentence, globalNarInstance.mem)

  if line.len >= 2 and line[0..1] == ">>": # NLP input for NAR based parsing
    # commented because the functionality is not ready yet
    let nlText: string = line[2..line.len-1]
    let conclSentences: seq[SentenceObj] = processNl0(nlText)
    for iConclSentence in conclSentences:
      # forward to main-NAR
      iConclSentence.stamp = makeStamp() # override stamp
      putInput(globalNarInstance.mem, iConclSentence, false)


  elif line == "!diag": # diagnostics
    echo fmt"nConcept={globalNarInstance.mem.retNumberOfConcept()}"
    return true
  elif line == "!sm": # show memory
    proceduralShowAllBeliefs("mem")
    #proceduralShowAllBeliefs(goalMem, "goalMem")
    return true
  elif line == "!sp": # step procedural
    proceduralStep()
    proceduralAdvanceTime(1) # advance time implicitly



  block:
    var steps: int
    let parsedChars = parseInt(line, steps)
    if parsedChars != 0:

      # do inference steps
      if steps > 0:
        for iStep in 0..steps-1:
          ctrlStep()
          ctrlQaStep()
      
      return false

  parseNarInputAndPut(line)  # try to parse as narsese


if isMainModule:
  narInit() # reset memory and everything so we start cleanly into shell
  block:
    var createdRegOp: RegisteredOpRef = makeOp(op0)
    globalNarInstance.opRegistry.ops["^op0"] = createdRegOp


  var showDerivations: bool = true
  proc derivConclCallback(s: SentenceObj) =
    if showDerivations:
      echo(&"|- {convSentenceToStr(s)}")
  globalNarInstance.conclCallback = derivConclCallback



  # parse files
  block:
    for iParamIdx in 0..<paramCount():
      let nalPath: string = paramStr(iParamIdx+1)
      let narseseContent: string = readFile(nalPath)

      # interpret content of file
      for iLine in narseseContent.split('\n'):
        echo(iLine)

        let forceContinue: bool = parseLine(iLine)
        if forceContinue:
          continue

        # implicit step is here explicit
        ctrlStep()
        ctrlQaStep()


  

  while true:
    var line: string = stdin.readLine()
    echo(line)

    let forceContinue: bool = parseLine(line)
    if forceContinue:
      continue

    # implicit step is here explicit
    ctrlStep()
    ctrlQaStep()


# TODO< test natural language input with >> >
