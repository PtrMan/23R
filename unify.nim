import std/tables
import std/options
import std/strformat

# for debugging

import term

type 
  UnifiedVarsRef* = ref UnifiedVars
  UnifiedVars* = object
    uVarAssignments*: Table[int64, TermObj] # variable assignment
    qVarAssignments*: Table[int64, TermObj] # variable assignments for question variables


type UnifyModeEnum* = enum
  unifyModeUvar
  unifyModeQvar

# term unifier
proc termTryUnify*(a: TermObj, b: TermObj, vars: UnifiedVarsRef, unifyMode: UnifyModeEnum): bool =
  proc tryAssign(id: int64, t: TermObj): bool =
    #echo(&"try to assign {convTermToStr(t)} to varId={id}") # DBG
    
    if unifyMode == unifyModeUvar:
      if id in vars.uVarAssignments:
        # assignment must be equal!
        return termEq(vars.uVarAssignments[id], b)
      else:
        # assign
        vars.uVarAssignments[id] = b
        return true
    else:
      if id in vars.qVarAssignments:
        # assignment must be equal!
        return termEq(vars.qVarAssignments[id], b)
      else:
        # assign
        vars.qVarAssignments[id] = b
        return true

  #echo(&"unify00: try to unify {convTermToStr(a)} + {convTermToStr(b)}") # DBG

  case a.type0
    of inh:
      case b.type0
      of inh:
        return termTryUnify(a.subject, b.subject, vars, unifyMode) and termTryUnify(a.predicate, b.predicate, vars, unifyMode)
      of uvar, qvar:
        return tryAssign(b.id, a)
      of `tuple`, sequence, name, prod, predImpl, impl, sim, img:
        return false

    of sim:
      case b.type0
      of sim:
        return termTryUnify(a.subject, b.subject, vars, unifyMode) and termTryUnify(a.predicate, b.predicate, vars, unifyMode)
      of uvar, qvar:
        return tryAssign(b.id, a)
      of `tuple`, sequence, name, prod, predImpl, impl, inh, img:
        return false

    of predImpl:
      case b.type0
      of predImpl:
        return termTryUnify(a.subject, b.subject, vars, unifyMode) and termTryUnify(a.predicate, b.predicate, vars, unifyMode)
      of uvar, qvar:
        return tryAssign(b.id, a)
      of `tuple`, sequence, name, prod, inh, impl, sim, img:
        return false
    
    of impl:
      case b.type0
      of impl:
        return termTryUnify(a.subject, b.subject, vars, unifyMode) and termTryUnify(a.predicate, b.predicate, vars, unifyMode)
      of uvar, qvar:
        return tryAssign(b.id, a)
      of `tuple`, sequence, name, prod, inh, predImpl, sim, img:
        return false

    of name:
      case b.type0
      of name:
        return a.name == b.name
      of uvar, qvar:
        return tryAssign(b.id, a)
      of inh, `tuple`, sequence, prod, predImpl, impl, sim, img:
        return false

    of `tuple`:
      case b.type0
      of `tuple`:
        if a.items0.len != b.items0.len:
          return false

        for iidx in 0..a.items0.len-1:
          if not termTryUnify(a.items0[iidx], b.items0[iidx], vars, unifyMode):
            return false
        return true

      of uvar, qvar:
        return tryAssign(b.id, a)
      of inh, name, prod, predImpl, sequence, impl, sim, img:
        return false

    of sequence:
      case b.type0
      of sequence:
        if a.items0.len != b.items0.len:
          return false

        for iidx in 0..<a.items0.len:
          if not termTryUnify(a.items0[iidx], b.items0[iidx], vars, unifyMode):
            return false
        return true
      
      of uvar, qvar:
        return tryAssign(b.id, a)

      of inh, `tuple`, name, prod, predImpl, impl, sim, img:
        return false
    
    of prod:
      case b.type0
      of prod:
        if a.items0.len != b.items0.len:
          return false

        for iidx in 0..<a.items0.len:
          if not termTryUnify(a.items0[iidx], b.items0[iidx], vars, unifyMode):
            return false
        return true

      of uvar, qvar:
        return tryAssign(b.id, a)

      of inh, `tuple`, name, predImpl, sequence, impl, sim, img:
        return false
    
    of uvar, qvar:
      case b.type0
      of prod, inh, `tuple`, name, predImpl, sequence, impl, sim, img:
        return tryAssign(a.id, b)
      of uvar, qvar:
        return false # var and var don't unify!
    
    of img:
      case b.type0
      of img:
        if a.idx != b.idx:
          return false

        if not termTryUnify(a.base, b.base, vars, unifyMode):
          return false

        if a.content.len != b.content.len:
          return false

        for iidx in 0..<a.content.len:
          if not termTryUnify(a.content[iidx], b.content[iidx], vars, unifyMode):
            return false
        return true
      of uvar, qvar:
        return tryAssign(b.id, a)
      of inh, `tuple`, name, predImpl, sequence, impl, sim, prod:
        return false


proc unifySubstitute*(t: TermObj, vars: UnifiedVarsRef): TermObj =
  case t.type0
  of inh:
    return termMkInh(unifySubstitute(t.subject, vars), unifySubstitute(t.predicate, vars))
  of predImpl:
    return termMkPredImpl(unifySubstitute(t.subject, vars), unifySubstitute(t.predicate, vars))
  of impl:
    return termMkImpl(unifySubstitute(t.subject, vars), unifySubstitute(t.predicate, vars))

  of name:
    return t

  of `tuple`, sequence, prod:
    var s: seq[TermObj] = @[]
    for iv in t.items0:
      s.add(unifySubstitute(iv, vars))
    
    case t.type0
    of `tuple`:
      return TermObj(type0:`tuple`, items0:s)
    of sequence:
      return TermObj(type0:sequence, items0:s)
    of prod:
      return TermObj(type0:prod, items0:s)
    of inh, predImpl, name, uvar, qvar, impl, sim, img:
      # internal error, should never occur!
      return t # HACK< just return >
  of uvar:
    if t.id in vars.uVarAssignments:
      return vars.uVarAssignments[t.id]
    else:
      return t # leave it unassigned
  
  of qvar:
    if t.id in vars.qVarAssignments:
      return vars.qVarAssignments[t.id]
    else:
      return t # leave it unassigned
  of sim:
    return termMkSim(unifySubstitute(t.subject, vars), unifySubstitute(t.predicate, vars))
  of img:
    var s: seq[TermObj] = @[]
    for iv in t.content:
      s.add(unifySubstitute(iv, vars))
    
    return termMkImg(t.idx, unifySubstitute(t.base, vars), s)


# try to unify and assign variables to terms
proc termTryUnifyAndAssign3*(a: TermObj, b: TermObj, unifyMode: UnifyModeEnum): Option[tuple[a: TermObj, b: TermObj, vars:UnifiedVarsRef]] =
  var vars: UnifiedVarsRef = UnifiedVarsRef(uVarAssignments:initTable[int64, TermObj](), qVarAssignments:initTable[int64, TermObj]())
  if not termTryUnify(a, b, vars, unifyMode):
    return none(tuple[a: TermObj, b: TermObj, vars: UnifiedVarsRef])

  let aUnified: TermObj = unifySubstitute(a, vars)
  let bUnified: TermObj = unifySubstitute(b, vars)

  return some((aUnified, bUnified, vars))




proc termCheckUnify(a: TermObj, b: TermObj): bool =
  return termTryUnifyAndAssign3(a, b, unifyModeUvar).isSome()

