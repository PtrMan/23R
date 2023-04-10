# narsese.nim: tokenizer+parser

import std/strformat
import std/strutils

import term

type TokenTypeEnum* = enum
  open, close, copinh, copsim, copPredImpl, TokenName, braceOpen, braceClose, star, comma, tupleToken, uvar, impl


type
  Token0Obj* = ref Token0
  Token0* = object
    case type0*: TokenTypeEnum 
    of open: # '<'
      dummy0: int
    of close: # '>'
      dummy1: int
    of copinh, copsim, impl: # '-->' '<->' '==>'
      discard
    of copPredImpl: # '-->'
      dummy6: int
    of TokenName:
      str: string
    of braceOpen: # '('
      dummy3: int
    of braceClose: # ')'
      dummy4: int
    of star: # '*'
      dummy5: int
    of comma: # ','
      dummy7: int
    of tupleToken: # "##"
      dummy8: int
    of TokenTypeEnum.uvar:
      id*: int64 # id of the variable
    
    depth*: int # depth in the tree, can be 0 if it's not used or at root without braces

proc convTokenToStr*(token: Token0Obj): string =
  case token.type0
  of open:
    return "<"
  of close:
    return ">"
  of copinh:
    return "-->"
  of copsim:
    return "<->"
  of impl:
    return "==>"
  of copPredImpl:
    return "=/>"
  of TokenName:
    return token.str
  of braceOpen:
    return "("
  of braceClose:
    return ")"
  of star:
    return "*"
  of comma:
    return ","
  of tupleToken:
    return "##"
  of TokenTypeEnum.uvar:
    return &"%%{token.id}"

# print tokens to output
proc dbgTokens*(tokens: seq[Token0Obj]) =
  for iToken in tokens:
    echo("token:"&convTokenToStr(iToken))


# for debugging
proc debugTokensSeq*(tokens: seq[Token0Obj]): string =
  var s: string = ""
  for iToken in tokens:
    s = s&" "&convTokenToStr(iToken)
  return s


proc parse*(s: seq[Token0Obj]): TermObj =
  # used to match for product or sequence
  proc tryMatchProdOrSeqOrTuple(s: seq[Token0Obj], connector: TokenTypeEnum): TermObj =
    let thisDepth: int = s[0].depth # the depth of this expression is the depth of the first token

    case s[0].type0
    of braceOpen:
      discard
    else:
      return nil

    case s[s.len-1].type0
    of braceClose:
      discard
    else:
      return nil

    # scan for connector which seperates the content
    var connectorIdxs: seq[int] = @[]
    for iidx in 2..s.len-3:
      if s[iidx].type0 == connector and s[iidx].depth == thisDepth: # connector token must be on same depth!
        connectorIdxs.add(iidx)
    
    if connectorIdxs.len == 0:
      return nil

    var tokensBetweenSeperators: seq[ seq[Token0Obj] ] = @[]
    block:
      let beforeTokens: seq[Token0Obj] = s[1..connectorIdxs[0]-1]
      tokensBetweenSeperators.add(beforeTokens)
    
    for iConnectorIdx in 0..connectorIdxs.len-1-1:
      let startIdx: int = connectorIdxs[iConnectorIdx]+1
      let endIdx: int = connectorIdxs[iConnectorIdx+1]-1
      let middleTokens: seq[Token0Obj] = s[startIdx..endIdx] # extract tokens between connectors
      tokensBetweenSeperators.add(middleTokens)
    
    block:
      let endTokens: seq[Token0Obj] = s[connectorIdxs[connectorIdxs.len-1]+1..s.len-1-1]
      tokensBetweenSeperators.add(endTokens)
    
    #for iTokensBetween in tokensBetweenSeperators:
    #  echo(debugTokensSeq(iTokensBetween))
    #echo ""

    var betweenSeperatorsParsings: seq[TermObj] = @[]
    for iTokensSeq in tokensBetweenSeperators:
      let res: TermObj = parse(iTokensSeq)
      if res == nil: # parsing failed?
        return nil
      betweenSeperatorsParsings.add(res)
    
    if connector == star:
      return TermObj(type0:prod, items0:betweenSeperatorsParsings)
    elif connector == comma:
      return TermObj(type0:sequence, items0:betweenSeperatorsParsings)
    elif connector == tupleToken:
      return TermObj(type0:`tuple`, items0:betweenSeperatorsParsings)
  
  proc tryMatchCopula(s: seq[Token0Obj], cop:TermTypeEnum): TermObj =
    if s.len < 5:
      return nil # can't be copula
    
    case s[0].type0
    of open:
      discard
    else:
      return nil

    case s[s.len-1].type0
    of close:
      discard
    else:
      return nil
    
    # first and last token fit

    # scan for "-->" token
    for iidx in 2..s.len-3:
      if (s[iidx].type0 == copinh and cop == inh) or (s[iidx].type0 == copsim and cop == sim) or (s[iidx].type0 == copPredImpl and cop == predImpl) or (s[iidx].type0 == impl and cop == TermTypeEnum.impl):
        let before: seq[Token0Obj] = s[1..iidx-1]
        let after: seq[Token0Obj] = s[iidx+1..s.len-1-1]
        let beforeRes: TermObj = parse(before)
        let afterRes: TermObj = parse(after)

        if beforeRes != nil and afterRes != nil:
          if cop == inh:
            return termMkInh(beforeRes, afterRes)
          elif cop == sim:
            return termMkSim(beforeRes, afterRes)
          elif cop == predImpl:
            return termMkPredImpl(beforeRes, afterRes)
          elif cop == TermTypeEnum.impl:
            return termMkImpl(beforeRes, afterRes)
          else:
            discard
            # internal error - ignore for now

    return nil
  

  if true:
    # try match single name or variable
    if s.len == 1:
      case s[0].type0
        of TokenName:
          return termMkName(s[0].str)
        of TokenTypeEnum.uvar:
          return termMkUvar(s[0].id)
        else:
          return nil

  if true:
    let t = tryMatchCopula(s, inh)
    if t != nil:
      return t

  if true:
    let t = tryMatchCopula(s, sim)
    if t != nil:
      return t

  if true:
    let t = tryMatchCopula(s, predImpl)
    if t != nil:
      return t

  if true:
    let t = tryMatchCopula(s, TermTypeEnum.impl)
    if t != nil:
      return t


  if true:
    let t = tryMatchProdOrSeqOrTuple(s, star)
    if t != nil:
      return t
  
  if true:
    let t = tryMatchProdOrSeqOrTuple(s, comma)
    if t != nil:
      return t

  if true:
    let t = tryMatchProdOrSeqOrTuple(s, tupleToken)
    if t != nil:
      return t


  return nil








# this is a implementation of the tokenizer
proc tokenize*(str:string): seq[Token0Obj] =
  var acc = ""

  var tokens: seq[Token0Obj] = @[]

  # helper to flush and emit current token if there is any
  proc flush() =
    if acc.len != 0:
      if acc.len > 2 and acc[0..1] == "%%":
        let idStr: string = acc[2..acc.len-1]
        let id: int64 = parseInt(idStr)
        tokens.add(Token0Obj(type0:TokenTypeEnum.uvar, id:id))
      else:
        tokens.add(Token0Obj(type0:TokenName, str:acc, depth:0))
    acc = ""

  for iChar in str:
    if iChar == '#':
      if acc == "#":
        tokens.add(Token0Obj(type0:tupleToken, depth:0))
        acc=""
        continue
      
      flush()
      acc="#"
      continue

    if iChar == '-':
      if acc=="-": # -->
        discard
      else:
        # special handling to parse <%%0-->X>   etc.
        flush()
        acc="-"
        continue

    elif iChar == '>':
      if acc == "--":
        tokens.add(Token0Obj(type0:copinh, depth:0))
        acc=""
        continue
      if acc == "=/":
        tokens.add(Token0Obj(type0:copPredImpl, depth:0))
        acc=""
        continue
      if acc == "<-":
        tokens.add(Token0Obj(type0:copsim, depth:0))
        acc=""
        continue
      if acc == "==":
        tokens.add(Token0Obj(type0:impl, depth:0))
        acc=""
        continue


    if iChar == '<':
      flush()
      tokens.add(Token0Obj(type0:open, depth:0))
    elif iChar == '>':
      flush()
      tokens.add(Token0Obj(type0:close, depth:0))
    elif iChar == '(':
      flush()
      tokens.add(Token0Obj(type0:braceOpen, depth:0))
    elif iChar == ')':
      flush()
      tokens.add(Token0Obj(type0:braceClose, depth:0))
    elif iChar == '*':
      flush()
      tokens.add(Token0Obj(type0:star, depth:0))
    elif iChar == ',':
      flush()
      tokens.add(Token0Obj(type0:comma, depth:0))
    elif iChar == ' ':
      flush()
    else:
      acc=acc&iChar

  flush()
  return tokens

# TODO< use regular expressions in tokenizer!!! >
