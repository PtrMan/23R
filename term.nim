import std/strformat
import std/hashes

type TermTypeEnum* = enum
  name, inh, predImpl, `tuple`, prod, sequence, uvar, qvar, impl, sim, img #, extSet


type
  TermObj* = ref Term
  Term* = object
    case type0*: TermTypeEnum 
    of name:
      name*: string
    of inh, predImpl, impl, sim:
      subject*: TermObj
      predicate*: TermObj
    of `tuple`, prod, sequence:
      items0*: seq[TermObj]
    of uvar, qvar: # universal variable + question variable
      id*: int64
    of img:
      idx*: int
      content*: seq[TermObj]
      base*: TermObj


proc termMkName*(s:string): TermObj =
  return TermObj(type0:name, name:s)

proc termMkInh*(subject: TermObj, predicate: TermObj): TermObj =
  return TermObj(type0:inh, subject:subject, predicate:predicate)

proc termMkSim*(subject: TermObj, predicate: TermObj): TermObj =
  return TermObj(type0:sim, subject:subject, predicate:predicate)

proc termMkPredImpl*(subject: TermObj, predicate: TermObj): TermObj =
  return TermObj(type0:predImpl, subject:subject, predicate:predicate)

proc termMkImpl*(subject: TermObj, predicate: TermObj): TermObj =
  return TermObj(type0:impl, subject:subject, predicate:predicate)

# TODO LOW< remove this function>
proc termMkProd*(items0:varargs[TermObj]): TermObj =
  var items1: seq[TermObj] = @[]
  for iv in items0:
    items1.add(iv)
  return TermObj(type0:prod, items0:items1)

proc termMkProd2*(items:seq[TermObj]): TermObj =
  return TermObj(type0:prod, items0:items)

proc termMkTuple*(items0:varargs[TermObj]): TermObj =
  var items1: seq[TermObj] = @[]
  for iv in items0:
    items1.add(iv)
  return TermObj(type0:`tuple`, items0:items1)

# TODO LOW< remove this function>
proc termMkSeq*(items0:varargs[TermObj]): TermObj =
  var items1: seq[TermObj] = @[]
  for iv in items0:
    items1.add(iv)
  return TermObj(type0:sequence, items0:items1)

proc termMkSeq2*(items:seq[TermObj]): TermObj =
  return TermObj(type0:sequence, items0:items)

proc termMkImg*(idx: int, base:TermObj, content:seq[TermObj]): TermObj =
  return TermObj(type0:img, idx:idx, base:base, content:content)


proc termMkUvar*(id: int64): TermObj =
  return TermObj(type0:uvar, id: id)

proc termMkQvar*(id: int64): TermObj =
  return TermObj(type0:qvar, id: id)


proc termEq*(a: TermObj, b: TermObj): bool =
  case a.type0
  of name:
    case b.type0
    of name:
      return a.name == b.name
    else:
      return false
  of inh:
     case b.type0
     of inh:
       return termEq(a.subject, b.subject) and termEq(b.predicate, b.predicate)
     else:
       return false
  of predImpl:
    case b.type0
    of predImpl:
      return termEq(a.subject, b.subject) and termEq(b.predicate, b.predicate)
    else:
      return false
  of impl:
    case b.type0
    of impl:
      return termEq(a.subject, b.subject) and termEq(b.predicate, b.predicate)
    else:
      return false
  of `tuple`:
    case b.type0
    of `tuple`:
      if a.items0.len == b.items0.len:
        for iidx in 0..a.items0.len-1:
          if not termEq(a.items0[iidx], b.items0[iidx]):
            return false
        return true
      return false
    else:
      return false
  of prod:
    case b.type0
    of prod:
      if a.items0.len == b.items0.len:
        for iidx in 0..a.items0.len-1:
          if not termEq(a.items0[iidx], b.items0[iidx]):
            return false
        return true
      return false
    else:
      return false
  of sequence:
    case b.type0
    of sequence:
      if a.items0.len == b.items0.len:
        for iidx in 0..a.items0.len-1:
          if not termEq(a.items0[iidx], b.items0[iidx]):
            return false
        return true
      return false
    else:
      return false
  of uvar, qvar:
    return false # variables are never equal!
  of sim:
     case b.type0
     of sim:
       return termEq(a.subject, b.subject) and termEq(b.predicate, b.predicate)
     else:
       return false
  of img:
    case b.type0
    of img:
      if a.content.len != b.content.len:
        return false
      for idx in 0..<a.content.len:
        if not termEq(a.content[idx], b.content[idx]):
          return false
      
      if not termEq(a.base, b.base):
        return false

      if a.idx != b.idx:
        return false
      return true
    else:
      return false



proc hash*(t: TermObj): Hash =
  case t.type0
  of name:
    return hash(t.name)
  of inh, predImpl, impl, sim:
    return hash(t.subject) + hash(t.predicate)
  of uvar, qvar:
    return hash(t.id)
  of `tuple`, prod, sequence:
    # TODO
    return hash(0)
  of img:
    # TODO
    return hash(0)


proc convTermToStr*(t: TermObj): string =
  case t.type0
  of name:
    return t.name
  of inh:
    return fmt"<{convTermToStr(t.subject)} --> {convTermToStr(t.predicate)}>"
  of sim:
    return fmt"<{convTermToStr(t.subject)} <-> {convTermToStr(t.predicate)}>"
  of predImpl:
    return fmt"<{convTermToStr(t.subject)} =/> {convTermToStr(t.predicate)}>"
  of impl:
    return fmt"<{convTermToStr(t.subject)} ==> {convTermToStr(t.predicate)}>"
  of `tuple`, prod, sequence:
    var s0 = ""

    var idx = 0
    for iv in t.items0:
      s0 = s0&convTermToStr(iv)
      if idx < t.items0.len-1:
        case t.type0
        of `tuple`:
          s0 = s0&"##"
        of sequence:
          s0 = s0&","
        of prod:
          s0 = s0&"*"
        of inh, name, predImpl, uvar, qvar, impl, sim, img:
          discard
      idx=idx+1

    return fmt"({s0})"
  of uvar:
    return &"$${t.id}"
  of qvar:
    return &"?{t.id}"
  of img:
    if t.idx == 0:
      return &"(/ {convTermToStr(t.base)} _ {convTermToStr(t.content[0])})"
    return &"(/ {convTermToStr(t.base)} {convTermToStr(t.content[0])} _)"



# returns nil if some error occurred
proc seqRemoveLast*(t: TermObj): TermObj =
  case t.type0
  of sequence:
    return termMkSeq2(t.items0[0..t.items0.len-1-1])
  else:
    return nil

# casts sequence to term if length is one
# else it returns a sequence
# returns nil if some error occurred
proc seqRemoveLastAndCastToTermIfNecessary*(t: TermObj): TermObj =
  let seq0: TermObj = seqRemoveLast(t)
  if seq0 == nil:
    return nil

  # is seq, check if it has only one item, return that if so
  case seq0.type0
  of sequence:
    if seq0.items0.len == 1:
      return seq0.items0[0]
    else:
      return seq0
  else:
    return nil



# TERMUTILS
# fold seq term
func termFoldSeq*(term: TermObj): TermObj =
  var items: seq[TermObj] = @[]

  # unwind
  func unwindRec(term: TermObj) =
    case term.type0
    of sequence:
      for iItem in term.items0:
        unwindRec(iItem)
    else:
      items.add(term) # store
  
  unwindRec(term)

  return termMkSeq2(items)