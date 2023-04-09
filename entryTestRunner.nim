import std/strformat
import std/parseutils
#import system/io
import strutils
import tables

import nar
import term

# runner for automated tests

var derivedConcls: seq[SentenceObj] = @[]
proc derivedConclCallback(s: SentenceObj) =
  echo(&"|-{convSentenceToStr(s)}")
  
  derivedConcls.add(s)

var invokedOpTerms: seq[TermObj] = @[]
proc invokeOpCallback(opTerm: TermObj) =
  invokedOpTerms.add(opTerm)


# reads a narsese file and runs it as a automated test
# immediatly returns false when a automated check failed
proc readNarseseAndRunTest(path: string): bool =
  panicDbgModel = true # panicDbg() causes program to exit with error!

  derivedConcls = @[]
  invokedOpTerms = @[]


  narInit()
  globalNarInstance.conclCallback = derivedConclCallback
  globalNarInstance.invokeOpCallback = invokeOpCallback

  # op for testing
  proc op0(args: seq[TermObj]) =
    echo("main: ^op0 was invoked")

  globalNarInstance.opRegistry.ops["^op0"] = op0
  globalNarInstance.opRegistry.ops["^n9ExecAndInj"] = opLibNal9ExecAndInj # NAL-9


  let fileContent: string = readFile(path)

  for iLine in split(fileContent, '\n'):

    if iLine.startsWith("//expectDeriv "):
      let expectedNarsese: string = iLine[14..iLine.len-1]

      # check in derived messages if it exists
      var found = false
      for iKnownConclusion in derivedConcls:
        let iKnownConclusionStr: string = convSentenceToStr(iKnownConclusion)

        if iKnownConclusionStr == expectedNarsese:
          found = true
          break
      
      if found:
        continue

      # we are here when it doesn't exist!
      echo(iLine)
      echo("FAIL: didn't find expected conclusion! EXIT")
      quit(1)

    if iLine.startsWith("//expectExeced "):
      let expectedNarsese: string = iLine[15..iLine.len-1]

      # check in derived messages if it exists
      var found = false
      for iKnownConclusion in invokedOpTerms:
        let iKnownConclusionStr: string = convTermToStr(iKnownConclusion)

        if iKnownConclusionStr == expectedNarsese:
          found = true
          break
      
      if found:
        continue

      # we are here when it doesn't exist!
      echo(iLine)
      echo("FAIL: didn't find expected op execution! EXIT")
      quit(1)


    if iLine.startsWith("//"):
      continue # ignore comments
    if iLine == "":
      continue # ignore empty lines

    # parse command
    if false:
      discard
    elif iLine == "!sm": # show memory
      proceduralShowAllBeliefs("mem")
      #proceduralShowAllBeliefs(goalMem, "goalMem")
      continue

    elif iLine == "!sp": # step procedural
      proceduralStep()
      proceduralAdvanceTime(1) # advance time implicitly
    else:
      block:
        var steps: int
        let parsedChars = parseInt(iLine, steps)
        if parsedChars != 0:

          # do inference steps
          if steps > 0:
            for iStep in 0..steps-1:
              ctrlStep()
              ctrlQaStep()
          
          continue

      # fallback to parsing narsese
      parseNarInputAndPut(iLine)


  return true


var testFiles: seq[string] = @[]

##testFiles.add("./nalTest/opCall0.narsese")


#testFiles.add("./nalTest/procDeriv1.narsese")
#testFiles.add("./nalTest/procDeriv0.narsese")
#testFiles.add("./nalTest/opCallNal9.narsese")

#testFiles.add("./nalTest/procDeriv2multi.narsese")
#testFiles.add("./nalTest/procDeriv3multiComplicated.nal")

#testFiles.add("./nalTest/procDeriv4img.nal")
#testFiles.add("./nalTest/procDeriv5RftNlu.nal")

#testFiles.add("./nalTest/nal2a.narsese")

testFiles.add("./nalTest/nal6a.narsese")

# call readNarseseAndRunTest for all test-files
for iPath in testFiles:
  if not readNarseseAndRunTest(iPath):
    quit(1)

echo("FIN: all done!")
quit(0)


# TODO< implement check for    //expectExeced <({SELF}*dummy0) --> ^op0> >

