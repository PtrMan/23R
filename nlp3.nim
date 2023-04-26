import osproc
import strutils
import std/strformat

import nar
import term



# run python script to use LM, return result as text
proc runModuleNlp4AsStr(nlText: string): string =
  let result = execProcess("python", args=["./moduleNlp4/toolParseNl4.py", &"{nlText}"], options={poUsePath})
  return result

# run python script to disambigate a word
proc runPartDisambiguate0(npWord: string): string =
  let result = execProcess("python", args=["./partDisambiguate/partDisambiguate0.py", &"{npWord}"], options={poUsePath})
  return result


# runs NLP and returns terms
proc runModuleNlp4*(nlText: string): seq[TermObj] =
  # we give the request to the LM
  let resStr: string = runModuleNlp4AsStr(nlText)

  echo("TERMINAL RESULT >>>") # DBG
  echo(resStr)
  echo("\n<<<")

  var res: seq[TermObj] = @[]
  let lines = resStr.split('\n')

  for iLine in lines:
    if iLine.startsWith("statement="):
      let nlStatement: string = iLine["statement=".len..iLine.len-1]
      echo(&"DBG nl to module={nlStatement}")

      
      let tokens: seq[string] = nlStatement.split(" ") # tokenize
      var tokens2: seq[string] = @[]
      for z in tokens:
        if not (z in ["a", "an"]): # remove "a" and "an"
          tokens2.add(z)
      
      echo(tokens2)

      if tokens2.len == 3 and tokens2[1] == "is": # is relation detected 
        echo("IS relation detected!")

        let subjNl: string = tokens2[0]
        let predNl: string = tokens2[2]

        var wordtypePredNl: string
        block:
          let terminalOut2: string = runPartDisambiguate0(predNl) # run external program to disambiguate word
          echo(terminalOut2)
          for iLine2 in terminalOut2.split('\n'):
            if iLine2.startsWith("wordType0="):
              wordtypePredNl = iLine2["wordType0=".len..iLine2.len-1]

        var predNarsese: string = predNl
        if wordtypePredNl in ["JJ"]:
          predNarsese = "["&predNl&"]" # is a NAL property

        let narsese: string = &"<{subjNl} --> {predNarsese}>."
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

