import osproc
import strutils
import std/strformat

import nar
import term

# run python script to use LM, return result as text
proc runModuleNlp0AsStr(nlText: string): string =
  let result = execProcess("python", args=["./moduleNlp3/toolParseNl4.py", &"{nlText}"], options={poUsePath})
  return result


# runs NLP and returns terms
proc runModuleNlp4*(nlText: string): seq[TermObj] =
  # we give the request to the LM
  let resStr: string = runModuleNlp0AsStr(nlText)

  echo("TERMINAL RESULT >>>") # DBG
  echo(resStr)
  echo("\n<<<")

  var res: seq[TermObj] = @[]
  let lines = resStr.split('\n')
  for iLine in lines:
    if iLine.startsWith("statement="):
      let nlStatement: string = iLine["statement=".len..iLine.len]
      echo(&"DBG nl to module={nlStatement}")

      
      let tokens: seq[string] = nlStatement.split(" ") # tokenize
      var tokens2: seq[string] = @[]
      for z in tokens:
        if not (z in ["a", "an"]): # remove "a" and "an"
          tokens2.add(z)
      
      echo(tokens2)

      if tokens2.len == 3 and tokens2[1] == "is": # is relation detected 
        echo("IS relation detected!")

        let subj: string = tokens2[0]
        let pred: string = tokens2[2]
        let narsese: string = &"<{subj} --> {pred}>."
        echo(&"nl to narsese={narsese}")
        
        
        let resParse = parseNarsese(narsese)
        if resParse.success and resParse.punct == judgement:
          res.add(resParse.term)

      elif tokens2.len == 3: # generic relation detected
        echo("generic relation detected!")

        let narsese: string = &"<({tokens2[0]} * {tokens2[2]}) --> {tokens2[1]}>."
        echo(&"nl to narsese={narsese}")

        let resParse = parseNarsese(narsese)
        if resParse.success and resParse.punct == judgement:
          res.add(resParse.term)
      else:
        echo(&"nl: failed to identify nl statement={nlStatement}")
  
  return res

