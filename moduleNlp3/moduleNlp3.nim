import std/strformat
import strutils
import tables

import "../nar"
import "../term"


# process natural input
proc processNl0*(nlIn: string): seq[SentenceObj] =
  
  narInit()
  
  # op for testing
  proc op0(args: seq[TermObj]) =
    echo("main: ^op0 was invoked")

  globalNarInstance.opRegistry.ops["^op0"] = op0
  globalNarInstance.opRegistry.ops["^n9ExecAndInj"] = opLibNal9ExecAndInj # NAL-9

  # install handler to intercept derived conclusion
  var concls: seq[SentenceObj] = @[]
  proc derivConclCallback(s: SentenceObj) =
    if s.term.type0 == inh:
      concls.add(s)
      echo(&"|- {convSentenceToStr(s)}")
  globalNarInstance.conclCallback = derivConclCallback


  # feed it knowledge about grammar
  parseNarInputAndPut("<(<%%0 --> idxp0>, <ARE --> idxp1>, <%%2 --> idxp2>, <({SELF}*dummy0) --> ^op0>) =/> Z0>.")


  var idx = 0
  for iNlToken in split(nlIn, ' '):
    let wordconceptname: string = iNlToken
    var narsese: string = &"<{wordconceptname} --> idxp{idx}>. :|:"
    parseNarInputAndPut(narsese)

    proceduralStep()
    proceduralAdvanceTime(1) # advance time implicitly

    idx+=1

  # give compute resources to reasoner
  for z in 0..<15:
    proceduralStep()

  parseNarInputAndPut("Z0! :|:")

  # give compute resources to reasoner
  for z in 0..<15:
    proceduralStep()

  return concls



# functionality is tested with procDeriv5RftNlu.nal


# TODO< intercept derived conclusion! >
# TODO< refactor reasoning code and stuff so we can spawn local NAR! >

