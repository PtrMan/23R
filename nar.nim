import std/strformat
import std/algorithm
import std/tables
import std/sequtils
import random
import std/options
import std/math

import tv
import stamp
import term
import narsese
import unify


# import tsetlin0 # commented because not used yet for control

# compile and run with
#    nim compile --run nar.nim


var enPerception1: bool = true # enable perception1 perception engine? - disable only for debugging

var enPerceptionLayer: bool = false # enable "perception layer" specialized perception deriver for complicated predImpl's



# DEPRECATED
var enProceduralSampleAndBuildContigency: bool = false # enable sample and build contigency perception engine?



const STAMPMAXLEN: int = 25



var verbosityDbgA: int = 0 # verbosity for some debugging of deriver



var procRng: Rand = initRand(345) # rng for procedural reasoner



proc debug0(msg:string, verbosity: int = 1) =
  if verbosity <= 2:
    debugEcho fmt"DBG: {msg}"

# call when something non-critical recoverable happened which may indicate a bug
proc fixme0(msg: string) =
  debugEcho &"FIXME: {msg}"

var panicDbgModel*: bool = false # set to true that panicDbg() terminates the program

# for debugging only!
proc panicDbg(msg: string) =
  debugEcho &"PANICDBG: {msg}"

  if panicDbgModel:
    quit(2) # quit because of panic


type PunctEnum* = enum
  judgement, question, goal

# link of a predictive implication from the predicate to the subject (target)
type
  PredImplLinkObj* = ref PredImplLink
  PredImplLink* = object
    target*: TermObj
    tv*: Tv # truth value of the predictive implication
    stamp*: seq[int64] # stamp of the predictive implication link

    pred*: TermObj # predicate of virtual =/>

type
  SentenceObj* = ref Sentence
  Sentence* = object
    term*: TermObj
    tv*: Tv
    punct*: PunctEnum
    stamp*: seq[int64]

    # link which points from the predicate to the subject over a predictive implication
    # can be nil if it has no link
    predImplLinks: seq[PredImplLinkObj]


    originContingency: PredImplLinkObj # predimpllink which stands for contingency, which is the origin of that goal, can be nil
                                       # example: (a, ^x)!:|:  has originContingency (a, ^x)=/>b.



type
  EventObj* = object
    s*: SentenceObj
    occTime: int64
    tvProjected: Tv



proc sentenceEq(a: SentenceObj, b: SentenceObj): bool =
  let epsilon: float = 0.0000001
  if abs(a.tv.f-b.tv.f) > epsilon or abs(a.tv.evi-b.tv.evi) > epsilon:
    return false # can't be equal if the TV is different
  if a.punct != b.punct:
    return false
  if not termEq(a.term, b.term):
    return false
  return true


# checks if the link exists already, update it if so
# add it if it doesn't exist
proc sentenceUpdateLink(s:SentenceObj, link:PredImplLinkObj) =
  # update existing links if necessary
  for iLink in s.predImplLinks:
    if termEq(iLink.target, link.target):
      # update
      # TODO LOW
      discard
  
  # check if link already exists
  for iLink in s.predImplLinks:
    if termEq(iLink.target, link.target):
      return # yes link already exists, exit because we don't need to add

  debug0(&"sentenceUpdateLink(): add link {convTermToStr(link.target)} =/> {convTermToStr(s.term)}")

  # add link because it doesn't exist
  s.predImplLinks.add(link)
  
  # keep links under AIR
  # TODO MID< implement me! >




type
  AikrArr*[T] = object
    content*: seq[T]
    maxLen*: int

# doesn't check if it is valid to insert item
proc insert*[T](arr: var AikrArr[T], v: T) =
  arr.content.add(v)

  if arr.content.len > arr.maxLen:
    # sort
    # TODO TODO TODO

    arr.content = arr.content[0..arr.maxLen-1]


# CONCEPT
# prediction links point at subj of =/>
# TODO< implement this procedural stuff >

type
  ConceptObj* = ref Concept
  Concept* = object
    name: TermObj
    content: AikrArr[SentenceObj]
    contentProcedural: AikrArr[SentenceObj] # procedural beliefs, predImpl

# store or revise
proc put(c: ConceptObj, s: SentenceObj) =
  for iIdx in 0..<c.content.content.len:
    let iContent = c.content.content[iIdx]

    if termEq(iContent.term, s.term):
      if checkStampOverlap(iContent.stamp, s.stamp):
        # choice rule - if statement is the same then select candidate with higher conf
        if s.tv.retConf() > iContent.tv.retConf():
          c.content.content[iIdx] = s
      else:
        # revision
        # FIXME< replace item at index!!! >
        iContent.stamp = merge(iContent.stamp, s.stamp, STAMPMAXLEN)
        iContent.tv = tvRev(iContent.tv, s.tv)

      return
  
  insert(c.content, s)


# store or revise
proc putPredImpl(c: ConceptObj, s: SentenceObj) =
  case s.term.type0
  of predImpl:
    # returns false when the term of =/> wasnt found
    # /param update 
    proc checkOrUpdate(update: bool): bool =
      for iContent in c.content.content:
        if termEq(iContent.term, s.term.predicate):
          for iPredImplLink in iContent.predImplLinks:
            if termEq(iPredImplLink.target, s.term.subject):
              # we are here if the term of =/> is the same

              # TODO LOW< here we would have to revise/choice rule > 
              return true
          
          # if we are here then a belief with the same term as s.term wasn't found
          if update:
            #echo "HERE"
            #echo convTermToStr(s.term.subject)
            #quit(1)
            
            
            # add new link and return
            var createdLink: PredImplLinkObj = PredImplLinkObj(target:s.term.subject, tv:s.tv, stamp:s.stamp, pred:s.term.predicate)
            sentenceUpdateLink(iContent, createdLink)
            
          return true

      # if we are here then the term of =/> wasn't found and there is no belief with the right (( B of A=/>B ))
      return false
    
    if not checkOrUpdate(false):
      var predSentence: SentenceObj = SentenceObj(term:s.term.predicate)
      insert(c.content, predSentence)
    
    discard checkOrUpdate(true)

  else:
    discard
    # not expected term, just return silently









# memory
type
  MemObj* = ref Mem
  Mem* = object
    #concepts*: seq[ConceptObj] # OLD
    conceptsByName*: Table[TermObj, ConceptObj]

    capacityConcepts*: int # PARAM
# initTable[TermObj, ConceptObj]()


# helper to compare priority of concepts
proc compareMemGc(a, b: tuple[c:ConceptObj, worth:float64]): int  =
  return cmp(a.worth, b.worth)

proc memGc*(mem: MemObj) =

  if mem.conceptsByName.len > mem.capacityConcepts:
    #var z: seq[ConceptObj] = @[]
    var z: seq[tuple[c:ConceptObj, worth:float64]] = @[]

    for iKey in mem.conceptsByName.keys:
      var tuple0: tuple[c:ConceptObj, worth:float64]
      tuple0.c = mem.conceptsByName[iKey]

      var worth: float64 = 0.0
      for iBelief in tuple0.c.content.content:
        worth = max(calcExp(iBelief.tv), worth)
      for iBelief in tuple0.c.contentProcedural.content:
        worth = max(calcExp(iBelief.tv), worth)

      z.add(tuple0)

    # * sort
    sort(z, compareMemGc)

    # * limit
    z = z[0..mem.capacityConcepts]

    mem.conceptsByName.clear()
    for iv in z:
      mem.conceptsByName[iv.c.name] = iv.c



# lookup concept by name
proc memLookupConceptByName(mem: MemObj, name: TermObj): ConceptObj =
  #echo(&"DBGE {convTermToStr(name)} {hash(name)}")
  
  #echo("ENUM")
  # HACKY SLOW WAY to find it!
  for iv in mem.conceptsByName.keys:
    if hash(iv)==hash(name):
      let ic = mem.conceptsByName[iv]
      #echo(ic != nil)
      return ic

    #echo(&"DGGG {convTermToStr(iv)} {hash(iv)}")
  return nil

  #return mem.conceptsByName[name]
  
  #echo(mem.conceptsByName.hasKey(name))

  # hacky slow way because "if name in mem.conceptsByName:" doesn't work with current Nim version!
  #try:
  #  return mem.conceptsByName[name]
  #except KeyError as e:
  #  echo("DBGGG ret nil")
  #  return nil

  # old way which doesn't work because something is buggy in Nim
  #if name in mem.conceptsByName:
  #  return mem.conceptsByName[name]
  #return nil

proc retNumberOfConcept*(mem: MemObj): int =
  ##return mem.concepts.len
  return mem.conceptsByName.len

proc reset*(mem: MemObj) =
  #mem.concepts = @[]
  mem.conceptsByName.clear()



# returns the names of the concepts
proc termRetConcepts(t: TermObj, fullRecursive: bool = false): seq[TermObj] =
  var res: seq[TermObj] = @[]
  case t.type0
  of name:
    return @[t]
  of inh, predImpl, TermTypeEnum.impl, sim:
    res = @[t.subject, t.predicate]
    if fullRecursive:
      res=res&termRetConcepts(t.subject, fullRecursive)
      res=res&termRetConcepts(t.predicate, fullRecursive)
    return res
  of sequence:
    res.add(t) # the term itself, ex: (a, b)
    for iv in t.items0:
      res.add(iv)

    if fullRecursive:
      for iv in t.items0:
        res=res&termRetConcepts(iv, fullRecursive)

    return res
  of img:
    return t.content
  of `tuple`, TermTypeEnum.prod, TermTypeEnum.uvar, TermTypeEnum.qvar:
    return @[]







proc convSentenceToStr*(s: SentenceObj): string =
  if s == nil:
    fixme0(&"convSentenceToStr(): s is nil!")
    return "NULL"

  var punct="."
  if s.punct == goal:
    punct="!"
  elif s.punct == question:
    punct="?"

  return fmt"{convTermToStr(s.term)}{punct} {{{s.tv.f} {retConf(s.tv)}}}"

# conv sentence to full string
proc convSentenceToStr2(s: SentenceObj): string =
  var res: string = convSentenceToStr(s)
  
  var originContigencyTargetStr: string = "NULL"

  if s.originContingency!=nil:
    originContigencyTargetStr = convTermToStr(s.originContingency.target)

  return res&"\n"&"originContigency.target="&originContigencyTargetStr

var CONCEPTBELIEFMAXN = 15 # capacity of beliefs per concept

# create a concept
# (only call if the concept doesnt exist!)
proc createConcept(mem: MemObj, name: TermObj): ConceptObj =
  let concept1: ConceptObj = ConceptObj(name:name, content:AikrArr[SentenceObj](maxLen:CONCEPTBELIEFMAXN))
  mem.conceptsByName[name] = concept1
  return concept1

# add or revise in memory
proc put(mem: MemObj, s: SentenceObj) =
  block: # handling of =/> copula
    case s.term.type0
    of predImpl:
      

      # * add procedural link of =/>
      var c: ConceptObj = memLookupConceptByName(mem, s.term.predicate)
      if c == nil:
        # we need to create the concept
        c = createConcept(mem, s.term.predicate)
    
      c.putPredImpl(s)
      return
    else:
      discard
  
  
  
  let touchedConcepts: seq[TermObj] = termRetConcepts(s.term)

  # store into concepts
  for iConceptName in touchedConcepts:
    var c: ConceptObj = memLookupConceptByName(mem, iConceptName)
    if c == nil:
      # we need to create the concept
      c = createConcept(mem, iConceptName)
    
    #DBG  debug0(&"put() s={convSentenceToStr(s)} into concept={convTermToStr(c.name)}")
    c.put(s)




















type
  ParseOpResEnum = enum
    ParseOpRes
    NoneParseRes
  ParseOpRes1 = object
    case resType: ParseOpResEnum
    of ParseOpRes:
      name: string
      args: seq[TermObj]
    of NoneParseRes: null: int


proc tryParseOp(t: TermObj): ParseOpRes1 =
  case t.type0
  of inh:
    let inhSubj = t.subject
    let inhPred = t.predicate

    case inhPred.type0
    of name:
      let nameStr = inhPred.name
  
      case inhSubj.type0
      of TermTypeEnum.prod:
        let args = inhSubj.items0
  
        return ParseOpRes1(resType:ParseOpRes, name:nameStr, args:args)
      else:
        return ParseOpRes1(resType:NoneParseRes, null:0) # fail
    else:
      return ParseOpRes1(resType:NoneParseRes, null:0) # fail
  else:
    return ParseOpRes1(resType:NoneParseRes, null:0) # fail

proc checkIsOp(term: TermObj): bool =
  let parseOpResult = tryParseOp(term)
  case parseOpResult.resType
    of ParseOpRes:
      return true
    of NoneParseRes:
      return false



type OpFnType* = proc(args:seq[TermObj]){.closure.}

# type for a registered op
type RegisteredOpRef* = ref object
  callback*: OpFnType
  supportsLongCall*: bool # does the op support long calls over many cycles?

type
  OpRegistryObj* = ref OpRegistry
  OpRegistry* = object
    ops*: Table[string, RegisteredOpRef] # list with registered ops











type
  Task0 = ref Task0Obj
  Task0Obj = object
    sentence: SentenceObj
    prioCached: float # priority of the task (cached value)
    bestAnswer: SentenceObj # can be null if nothing found or if it is not a question

type
  Taskset0[T] = ref Taskset0Obj[T]
  Taskset0Obj[T] = object
    set0: seq[T]
    cmpFn: proc (a: T, b: T): int
    maxLen: int

# insert a task into the set of tasks
proc taskset0Insert[T](taskset: Taskset0[T], task: T) =
  taskset.set0.add(task)

  #proc cmpFn(a: Task0, b: Task0): int =
  #  return cmp(a.prioCached, b.prioCached)

  taskset.set0.sort(taskset.cmpFn)

  # keep under AIKR
  taskset.set0 = taskset.set0[0..min(taskSet.maxLen, taskset.set0.len-1)]


# return nil if nothing could be popped of the stack
proc taskset0TryPopTop[T](taskset: Taskset0[T]): T =
  if taskset.set0.len == 0:
    return nil

  let topItem = taskset.set0[0]
  taskset.set0.del(0)

  return topItem










type
  GoalObj* = object
    e*: EventObj
    

type
  GoalsWithSameDepthObj* = object
    goals*: seq[GoalObj]
    depthCached*: int









type
  EventRef* = ref EventObj

func convEventToStr(e: EventRef): string =
  return &"{convSentenceToStr(e.s)} occTime={e.occTime}"

# HELPER for the UNREFACTORED code which uses new EventRef
func convEventObjToRef(e: EventObj): EventRef =
  var res: EventRef = new (EventRef)
  res.s = e.s
  res.occTime = e.occTime
  return res




type
  Perception1TaskRef = ref Perception1Task
  Perception1Task = object
    prioCached: float64
    v: EventRef






# helper to sample
# /param rngVal random value between 0.0 and 1.0
func sampleHelper[T](items: seq[tuple[prio:float64,val:T]], rngVal: float): T =
  if items.len == 0:
    return T.default

  var prioSum: float64 = 0.0
  for iItem in items:
    prioSum += iItem.prio
  
  let selPrio: float64 = prioSum*rngVal

  var prioAcc: float64 = 0.0
  for iItem in items:
    prioAcc += iItem.prio
    if prioAcc >= selPrio:
      return iItem.val

  return items[items.len-1].val # fallback
  # ASK< is fallback ever reached? >



# datastructure which is bag like with bag like sampling
# usage: is usually used 
type
  SampledSetDsRef* = ref SampledSetDs
  SampledSetDs* = object
    set0*: seq[EventRef]
    maxLen*: int
    cmpFn*: proc (a: EventRef, b: EventRef): int

proc sampledSetDsMake(maxLen: int): SampledSetDsRef =
  var res: SampledSetDsRef = new (SampledSetDsRef)
  res.set0 = @[]
  res.maxLen = maxLen
  proc cmpFn(a: EventRef, b: EventRef): int =
    let aVal: float64 = calcExp(a.s.tv)
    let bVal: float64 = calcExp(b.s.tv)
    return cmp(aVal, bVal)
  res.cmpFn = cmpFn
  return res


# limit max number of entities to keep under AIKR
proc sampledSetDsLimit*(ds: SampledSetDsRef) =
  ds.set0.sort(ds.cmpFn)
  ds.set0 = ds.set0[0..min(ds.maxLen, ds.set0.len-1)]

proc sampledSetDsPut(ds: SampledSetDsRef, item: EventRef) =
  # check if it already exists (with same stamp and same term and same tv)
  for iEvent in ds.set0:
    if sentenceEq(iEvent.s, item.s) and iEvent.occTime == item.occTime:
      return # no need to do because event is the same
  
  ds.set0.add(item)
  sampledSetDsLimit(ds) # keep under AIKR

# sample by distribution
proc sampledSetDsSample(ds: SampledSetDsRef): EventRef =
  if ds.set0.len == 0:
    return nil # can't sample anything!
  
  # translate items
  var items: seq[tuple[prio:float64, val:EventRef]] = @[]
  for iItem in ds.set0:
    var item: tuple[prio:float64, val:EventRef]
    item.prio = calcExp(iItem.s.tv)
    item.val = iItem
  
  return sampleHelper(items, procRng.rand(0.0..1.0)) # do actual sampling

discard """
# global set of recently derived events
var narDerivedEventsSampledSetLevel1*: SampledSetDsRef
block:
  let maxLen: int = 20
  narDerivedEventsSampledSetLevel1 = sampledSetDsMake(maxLen)

  # override compare function of the sampled set because we need to consider the recency of the event too
  proc cmpFn(a: EventRef, b: EventRef): int =
    let decayFactor: float64 = 0.001
    let aVal: float64 = calcExp(a.s.tv) * exp(-float64(globalNarInstance.currentTime - a.occTime) * decayFactor)
    let bVal: float64 = calcExp(b.s.tv) * exp(-float64(globalNarInstance.currentTime - b.occTime) * decayFactor)
    return cmp(aVal, bVal)
  narDerivedEventsSampledSetLevel1.cmpFn = cmpFn
"""












# pointer to handler for Q&A
type ConclHandlerPtr = (proc(concl: SentenceObj):void)
type InvokeOpHandlerPtr = (proc(opTerm: TermObj):void)


func nullConclhandler(concl: SentenceObj) =
  discard

func nullOpHandler(opTerm: TermObj) =
  discard

type
  NarCtxRef* = ref NarCtx
  NarCtx* = object
    conclCallback*: ConclHandlerPtr # callback for done derivation
    invokeOpCallback*: InvokeOpHandlerPtr
    opRegistry*: OpRegistryObj

    mem*: MemObj
    goalMem*: MemObj

    # idea: * store indirection to belief in hashtable which is indexable by occurence time, this is a real alternative to the windowing approach
    # perceivable events by occurence time
    # value of the table is a sequence because the same time can have multiple events!
    eventsByOccTime*: Table[int64, seq[EventObj]]

    # PERCEPTION: set of recently derived events
    narDerivedEventsSampledSetLevel1*: SampledSetDsRef

    lastPerceivedEvent: EventObj # event which was last perceived
    perceptionLayer0lastPerceivedEvent: EventObj




    tasksetPerception1*: Taskset0[Perception1TaskRef] # set of tasks for perception1



    # goal system
    allGoalsByDepth*: seq[GoalsWithSameDepthObj]



    currentTime*: int64 # current absolute time

    decisionThreshold*: float64 # CONFIG


# global nar instance
# REFACTORME< refactor this into a non-global one once everything got refactored enough >
var globalNarInstance*: NarCtx







#[ commented because I don't know what episodic memory is supposed to be and how to implement it

# we selected the matching episodic memory, now we want to realize the operation of it
#
proc episodicMemRealizeOp(t: TermObj,  opRegistry: OpRegistryObj) =
  let parseOpResOpt = tryParseOp(t)
  if parseOpResOpt.resType == ParseOpRes:
    debug0("executive: HERE")
    opRegistry.ops[parseOpResOpt.name](parseOpResOpt.args)

# index and execute
proc episodicMemIdxAndInvokeOp(t: TermObj, selIdx: int,  opRegistry: OpRegistryObj) =
  case t.type0
  of inh:
    let inhSubj = t.subject
    case inhSubj.type0
    of `tuple`:
      let part0 = inhSubj
      let selItem = part0.items0[selIdx] # select by index
      episodicMemRealizeOp(selItem, opRegistry) # execute op
    of inh, prod, name, predImpl, sequence:
      let a=0
  of prod, name, `tuple`, predImpl, sequence:
    let a=0
]#


proc ruleNal4ProdToImg(aTerm: TermObj, aTv: Tv): seq[tuple[term: TermObj, tv: Tv]] =
  case aTerm.type0
  of inh:
    case aTerm.subject.type0
    of TermTypeEnum.prod:
      let prod = aTerm.subject

      if prod.items0.len == 2: # only implemented for 2 items
        let a = prod.items0[0]
        let b = prod.items0[1]

        var res: seq[tuple[term: TermObj, tv: Tv]] = @[]
        block:
          var r: tuple[term:TermObj, tv:Tv]
          r.term = termMkInh(termMkImg(0, aTerm.predicate, @[b]), a)
          r.tv = aTv
          res.add(r)
        block:
          var r: tuple[term:TermObj, tv:Tv]
          r.term = termMkInh(termMkImg(1, aTerm.predicate, @[a]), b)
          r.tv = aTv
          res.add(r)

        return res
      else:
        return @[]
    else:
      return @[]
  else:
    return @[]

proc ruleNal4ImgToProd(aTerm: TermObj, aTv: Tv): ref tuple[term:TermObj, tv:Tv] =
  case aTerm.type0
  of inh:
    let subj = aTerm.subject
    let pred = aTerm.predicate

    case subj.type0
    of img:
      let img = subj

      if img.content.len != 1:
        return nil

      var a: TermObj
      var b: TermObj
      if img.idx == 0:
        a = pred
        b = img.content[0]
      else:
        a = img.content[0]
        b = pred

      var res = new (tuple[term:TermObj, tv:Tv])
      res.term = termMkInh(termMkProd2(@[a, b]), img.base)
      res.tv = aTv
      return res
    else:
      return nil
  else:
    return nil




# A., A ==> B. |- B.
proc ruleNal6Ded(aTerm: TermObj, aTv: Tv, bTerm: TermObj, bTv: Tv): ref tuple[term:TermObj, tv:Tv] =
  case bTerm.type0
  of TermTypeEnum.impl:
    let subj = bTerm.subject
    let pred = bTerm.predicate

    # TODO< implement unification here! >
    if termEq(aTerm, subj):
      let c: ref tuple[term: TermObj, tv: Tv] = new (tuple[term: TermObj, tv: Tv])
      c.term = pred
      c.tv = tvDed(aTv, bTv) # FIXME< check if this is correct! >
      return c
    else:
      return nil
  else:
    return nil
      



# inference rule - derive <==> from two contingencies (RFT)
# (a,<(SELF * ...X...) --> x>) =/> c 
# (a,<(SELF * ...Y...) --> x>) =/> c
# |-
# X <==> Y
proc ruleRftExtractRftEquiv(aTerm: TermObj, bTerm: TermObj): TermObj =
  proc tryExtract(t: TermObj): ref tuple[predPred:TermObj, seqCondition:TermObj, opName:string, opArgs:seq[TermObj]] =
    case t.type0
    of predImpl:
      let predSubj = t.subject
      let predPred = t.predicate
      # predSubj must be a seq
      
      case predSubj.type0
        of sequence:
          # TODO LOW< FIXME<we restrict us here to the case when the sequence has a length of 2> >
          if predSubj.items0.len == 2:
            let seqCondition = predSubj.items0[0]
            
            let seqItem1 = predSubj.items0[0]
                  
            let parseOpResOpt = tryParseOp(seqItem1)
            if parseOpResOpt.resType == ParseOpRes:
              var res = new (tuple[predPred:TermObj, seqCondition:TermObj, opName:string, opArgs:seq[TermObj]])
              res.predPred=predPred
              res.seqCondition=seqCondition
              res.opName = parseOpResOpt.name
              res.opArgs = parseOpResOpt.args
              return res
            else:
              return nil
          else:
            return nil
        else:
          return nil
    else:
     return nil
    
    let x = tryExtract(aTerm)
    let y = tryExtract(bTerm)

    if x != nil and y != nil:
      debug0("ruleRftExtractRftEquiv(): both premises are contingencies!")
      # TODO< check if parts of x and y are the same and return the conclusion only if this is the case >
      return nil
      #return TermObj(type0:RftEquiv, subject:x, predicate:y)
    else:
      return nil






# mutual entailment as defined by RFT
# https://github.com/opennars/OpenNARS-for-Applications/blob/cef2b292aa29d5d7eed8ea739305191284fae62d/src/NAL.h#L249
# R2VarIntro( (A,Op1) =/> M, (B,Op2) =/> M |- ((A,Op1) =/> M) ==> ((B,Op2) =/> M)    tv-fn:Induction
# TODO MID< implement var intro rule exactly like done in ONA >
proc ruleMutualEntailmentA(aTerm: TermObj, aTv: Tv, bTerm: TermObj, bTv: Tv): ref tuple[term: TermObj, tv: Tv] =
  case aTerm.type0
  of predImpl:
    case bTerm.type0:
    of predImpl:
      #
      if termEq(aTerm.predicate, bTerm.predicate):
        let aSubj: TermObj = aTerm.subject
        let bSubj: TermObj = bTerm.subject

        case aSubj.type0
        of sequence:
          case bSubj.type0
          of sequence:
            #

            let lastSeqItemA: TermObj = aSubj.items0[aSubj.items0.len-1]
            let lastSeqItemB: TermObj = bSubj.items0[bSubj.items0.len-1]

            # last must be op!
            let parseOpAResult = tryParseOp(lastSeqItemA)
            case parseOpAResult.resType
              of ParseOpRes:

                # last must be op!
                let parseOpBResult = tryParseOp(lastSeqItemB)
                case parseOpAResult.resType
                  of ParseOpRes:
                    #

                    let c: ref tuple[term: TermObj, tv: Tv] = new (tuple[term: TermObj, tv: Tv])
                    c.term = termMkImpl(aTerm, bTerm)
                    c.tv = tvInd(aTv, bTv)
                    return c

                  of NoneParseRes:
                    return nil
              of NoneParseRes:
                return nil

          else:
            return nil
        else:
          return nil
    else:
      return nil
  else:
    return nil








# commented because not necessary anymore because it got superseeded by new RFT handling to build relations
discard """
#// R1:
#// rule to transfer between knowledge, HAS to be implemented in nature of the system
#//<<(#0, <(SELF*#rel) --> ^say>, #1) =/> #G> <=> <(#0*#1) --> #rel>>.
#
# this implements this rule from left side to right side
proc r1LeftToRight(termLeft: TermObj): TermObj =
  echo("a0")
  
  case termLeft.type0
  of predImpl:
    echo("a1")


    let predImplSubj = termLeft.subject

    case predImplSubj.type0
    of sequence:
      echo("a2")


      if predImplSubj.items0.len == 3:
        echo("a3")
  
        let itemAt1 = predImplSubj.items0[1]



        let parseOpResult = tryParseOp(itemAt1)
        case parseOpResult.resType
        of ParseOpRes:
          echo("a4")



          if parseOpResult.name == "^say" and parseOpResult.args.len == 2:

            echo("a5")

            # extract variables
            let var0 = predImplSubj.items0[0]
            let var1 = predImplSubj.items0[2]

            let varRel = parseOpResult.args[1]

            block: # build conclusion
              let res: TermObj = termMkInh(termMkProd(var0,var1), varRel)
              debug0(&"r1LeftToRight(): {convTermToStr(res)}")
              return res

          else:
            return nil
          

        of NoneParseRes:
          return nil

      else:
        return nil

    else:
      return nil # doesn't fit pattern
  else:
    return nil # doesn't fit pattern
"""










# type used to 'log' done derivations
type
  DoneDerivObj = ref DoneDeriv
  DoneDeriv = object
    premiseATerm: TermObj # is the term of the first premise
    premiseBTerm: TermObj # is the term of the second premise

    concl: SentenceObj # is the conclusion

# context for "goal driven control" control mechanism
type
  GoaldrivenCtrlCtxObj = ref GoaldrivenCtrlCtx
  GoaldrivenCtrlCtx = object
    conditionPremiseTerm: TermObj # is the term which is carried over from the condition of the contingency to the premise of the inference

    doneDerivs: seq[DoneDerivObj] # done derivations in the last step by the hardcoded deriver

    taskset: Taskset0[Task0]

    mem*: MemObj

# FIXME< global variable! >
var goaldrivenCtrlCtx*: GoaldrivenCtrlCtxObj = GoaldrivenCtrlCtxObj() # context for goal driven control
goaldrivenCtrlCtx.doneDerivs = @[]
goaldrivenCtrlCtx.taskset = new(Taskset0[Task0])
goaldrivenCtrlCtx.taskset.maxLen = 50
goaldrivenCtrlCtx.taskset.set0 = @[]
proc task0cmpFn(a: Task0, b: Task0): int =
  return cmp(a.prioCached, b.prioCached)
goaldrivenCtrlCtx.taskset.cmpFn = task0cmpFn


var questionTaskset: Taskset0[Task0] # taskset for questions to process
questionTaskset = new(Taskset0[Task0])
questionTaskset.set0 = @[]
questionTaskset.maxLen = 50
questionTaskset.cmpFn = task0cmpFn


# pointer to handler for Q&A
type QaHandlerPtr = (proc(question: SentenceObj, bestAnswer: SentenceObj):void)

var qaHandler: QaHandlerPtr = nil

var narRand: Rand = initRand(234)


var deriverTaskInsertThreshold: float64 = 0.002 # parameter

# PUBLIC interface
# add as input to NAR
# /param hintOnlyStore only store as belief if this flag is true
proc putInput*(mem: MemObj, s: SentenceObj, hintOnlyStore: bool) =
  if s.punct == judgement:
    put(mem, s) # store as belief
  
  if not hintOnlyStore:

    # add task
    if s.punct == judgement:
      let task0: Task0 = new (Task0)
      task0.sentence = s
      task0.prioCached = 1.0
      taskset0Insert(goaldrivenCtrlCtx.taskset, task0)
    elif s.punct == question:
      let task0: Task0 = new (Task0)
      task0.sentence = s
      task0.prioCached = 1.0
      taskset0Insert(questionTaskset, task0)






# commented because it is part of the executive for the episodic memory (or something)
#[
# executive: part of the interpreter
proc executiveIntrp(mem: MemObj, opRegistry: OpRegistryObj) =
  proc retLen(t:TermObj): int =
    case t.type0
    of inh:
      let inhSubj = t.subject
      case inhSubj.type0
      of part0:
        return inhSubj.items0.len
      of inh, name, prod, predImpl, sequence:
        return -1
    of prod, name, part0, predImpl, sequence:
      return -1
  
  let term51 = TermObj(type0:name, name:"EPI0")
  let selConcept: ConceptObj = memLookupConceptByName(mem, term51)
  if selConcept != nil: # was concept found
    echo(fmt"DBG: concept ""{convTermToStr(selConcept.name)}"" was found!")

  let selSentence = selConcept.content[0]

  # interpret the program just like an interpreter would
  for iidx in 1..retLen(selSentence.term)-1:
    episodicMemIdxAndInvokeOp(selSentence.term, iidx, opRegistry)
]#











import std/macros


# helper for deriver
proc retSubj(t: TermObj): TermObj =
  case t.type0
  of inh, predImpl, sim:
    return t.subject
  else:
    return nil

proc retPred(t: TermObj): TermObj =
  case t.type0
  of inh, predImpl, sim:
    return t.predicate
  else:
    return nil

# macro to generate code for check of preconditions of rule and derivation of conclusion if all preconditions succeed
macro z0(aAst: untyped, bAst: untyped, tvFn: string, conclAst: untyped): untyped =
  
  #let aCop = aAst[0]
  let aSubj = aAst[1]
  let aPred = aAst[2]

  #let bCop = aAst[0]
  let bSubj = bAst[1]
  let bPred = bAst[2]

  #let conclCop = conclAst[0]
  let conclSubj = conclAst[1]
  let conclPred = conclAst[2]
  

  result = nnkStmtList.newTree()


  # source of premise check for equality
  var subjSrcs = ("","")
  if aSubj == bSubj:
    subjSrcs = ("retSubj(a)", "retSubj(b)")
  elif aSubj == bPred:
    subjSrcs = ("retSubj(a)", "retPred(b)")
  elif aPred == bSubj:
    subjSrcs = ("retPred(a)", "retSubj(b)")
  else:
    subjSrcs = ("retPred(a)", "retPred(b)")




  var conclSubjSrc: string = "" # source of concl for subj
  if conclSubj == aSubj:
    conclSubjSrc = "retSubj(a)"
  elif conclSubj == aPred:
    conclSubjSrc = "retPred(a)"
  elif conclSubj == bSubj:
    conclSubjSrc = "retSubj(b)"
  elif conclSubj == bPred:
    conclSubjSrc = "retPred(b)"

  var conclPredSrc: string = "" # source of concl for pred
  if conclPred == aSubj:
    conclPredSrc = "retSubj(a)"
  elif conclPred == aPred:
    conclPredSrc = "retPred(a)"
  elif conclPred == bSubj:
    conclPredSrc = "retSubj(b)"
  elif conclPred == bPred:
    conclPredSrc = "retPred(b)"
  
  #result.add newCall("write", newIdentNode("stdout"), newLit(aAst[0].repr))
  #result.add newCall("write", newIdentNode("stdout"), newLit(aAst[1].repr))
  #result.add newCall("write", newIdentNode("stdout"), newLit(aAst[2].repr))
  
  result.add parseStmt(&"let tmpL={subjSrcs[0]}") # temp var for equal check of premise parts
  result.add parseStmt(&"let tmpR={subjSrcs[1]}") # temp var for equal check of premise parts


  # TODO< check for correct copula of premises! >
  let condition = parseStmt(&"tmpL != nil and tmpR != nil and termEq(tmpL, tmpR)  and  {conclSubjSrc} != nil and {conclPredSrc} != nil and not termEq({conclSubjSrc}, {conclPredSrc})")
  
  var body = nnkStmtList.newTree()
  body.add parseStmt("concl=termMkInh("&conclSubjSrc&","&conclPredSrc&")\n")
  body.add newAssignment(newIdentNode("conclTv"), newCall("tv"&tvFn.strVal, newIdentNode("aTv"), newIdentNode("bTv")))
  
  result.add newIfStmt((condition, body))

  # TODO< implement derivation of similarity! >





proc deriveSinglePremiseInternal(aTerm: TermObj, aTv: Tv, aStamp: seq[int64]): seq[DoneDerivObj] =
  var doneDerivs: seq[DoneDerivObj] = @[]
  
  block:
    for iConcl in ruleNal4ProdToImg(aTerm, aTv):
      let conclS: ref Sentence = new (Sentence)
      conclS.term = iConcl.term
      conclS.tv = iConcl.tv
      conclS.punct = judgement
      conclS.stamp = aStamp

      let doneDeriv: ref DoneDeriv = new (DoneDeriv)
      doneDeriv.premiseATerm = aTerm
      doneDeriv.premiseBTerm = nil
      doneDeriv.concl = conclS
      doneDerivs.add(doneDeriv)

  block:
    let x = ruleNal4ImgToProd(aTerm, aTv)
    if x!=nil:
      let conclS: ref Sentence = new (Sentence)
      conclS.term = x.term
      conclS.tv = x.tv
      conclS.punct = judgement
      conclS.stamp = aStamp

      let doneDeriv: ref DoneDeriv = new (DoneDeriv)
      doneDeriv.premiseATerm = aTerm
      doneDeriv.premiseBTerm = nil
      doneDeriv.concl = conclS
      doneDerivs.add(doneDeriv)


  # debug conclusions to output
  for iDoneDeriv in doneDerivs:
    debug0(fmt"deriver: {convTermToStr(aTerm)} |- concl={convSentenceToStr(iDoneDeriv.concl)}")
  
  # inform listener about conclusions
  for iDoneDeriv in doneDerivs:
    globalNarInstance.conclCallback(iDoneDeriv.concl)



  return doneDerivs




proc deriveInternal(mem: MemObj, a: TermObj, aTv: Tv, aStamp: seq[int64], b: TermObj, bTv: Tv, bStamp: seq[int64], premiseTaskPrio: float64, extendedTaskProcessing: bool = true): seq[DoneDerivObj] =
  var doneDerivs: seq[DoneDerivObj] = @[]

  block:
    proc x(a: TermObj, aTv: Tv, b: TermObj, bTv: Tv) =
      var concl: TermObj = nil
      var conclTv: Tv = makeTv(0.0, 0.0)
      z0(inh(A, B), inh(B, C), "Ded", inh(A, C))
      if concl!=nil:
        let conclS: ref Sentence = new (Sentence)
        conclS.term = concl
        conclS.tv = conclTv
        conclS.punct = judgement
        conclS.stamp = merge(aStamp, bStamp, STAMPMAXLEN)

        let doneDeriv: ref DoneDeriv = new (DoneDeriv)
        doneDeriv.premiseATerm = a
        doneDeriv.premiseBTerm = b
        doneDeriv.concl = conclS
        doneDerivs.add(doneDeriv)

    x(a, aTv, b, bTv)
    x(b, bTv, a, aTv)
  
  block:
    proc x(a: TermObj, aTv: Tv, b: TermObj, bTv: Tv) =
      var concl: TermObj = nil
      var conclTv: Tv = makeTv(0.0, 0.0)
      z0(inh(A, C), inh(B, C), "Abd", inh(B, A))
      if concl!=nil:
        let conclS: ref Sentence = new (Sentence)
        conclS.term = concl
        conclS.tv = conclTv
        conclS.punct = judgement
        conclS.stamp = merge(aStamp, bStamp, STAMPMAXLEN)

        let doneDeriv: ref DoneDeriv = new (DoneDeriv)
        doneDeriv.premiseATerm = a
        doneDeriv.premiseBTerm = b
        doneDeriv.concl = conclS
        doneDerivs.add(doneDeriv)

    x(a, aTv, b, bTv)
    x(b, bTv, a, aTv)

  block:
    proc x(a: TermObj, aTv: Tv, b: TermObj, bTv: Tv) =
      var concl: TermObj = nil
      var conclTv: Tv = makeTv(0.0, 0.0)
      z0(inh(A, B), inh(A, C), "Ind", inh(C, B))
      if concl!=nil:
        let conclS: ref Sentence = new (Sentence)
        conclS.term = concl
        conclS.tv = conclTv
        conclS.punct = judgement
        conclS.stamp = merge(aStamp, bStamp, STAMPMAXLEN)

        let doneDeriv: ref DoneDeriv = new (DoneDeriv)
        doneDeriv.premiseATerm = a
        doneDeriv.premiseBTerm = b
        doneDeriv.concl = conclS
        doneDerivs.add(doneDeriv)

    x(a, aTv, b, bTv)
    x(b, bTv, a, aTv)

  block:
    proc x(a: TermObj, aTv: Tv, b: TermObj, bTv: Tv) =
      var concl: TermObj = nil
      var conclTv: Tv = makeTv(0.0, 0.0)
      z0(inh(A, B), inh(A, C), "Comp", sim(A, C))
      if concl!=nil:
        let conclS: ref Sentence = new (Sentence)
        conclS.term = concl
        conclS.tv = conclTv
        conclS.punct = judgement
        conclS.stamp = merge(aStamp, bStamp, STAMPMAXLEN)

        let doneDeriv: ref DoneDeriv = new (DoneDeriv)
        doneDeriv.premiseATerm = a
        doneDeriv.premiseBTerm = b
        doneDeriv.concl = conclS
        doneDerivs.add(doneDeriv)

    x(a, aTv, b, bTv)
    x(b, bTv, a, aTv)
  
  block:
    proc x(a: TermObj, aTv: Tv, b: TermObj, bTv: Tv) =
      # debug0(&"I00: {convTermToStr(a)} + {convTermToStr(b)}") # DBG inference

      var conclOpt = ruleNal6Ded(a, aTv, b, bTv)
      if conclOpt!=nil:
        let conclS: ref Sentence = new (Sentence)
        conclS.term = conclOpt.term
        conclS.tv = conclOpt.tv
        conclS.punct = judgement
        conclS.stamp = merge(aStamp, bStamp, STAMPMAXLEN)

        let doneDeriv: ref DoneDeriv = new (DoneDeriv)
        doneDeriv.premiseATerm = a
        doneDeriv.premiseBTerm = b
        doneDeriv.concl = conclS
        doneDerivs.add(doneDeriv)

    x(a, aTv, b, bTv)
    x(b, bTv, a, aTv)
  







  # TODO< pass arguments and check result etc>
  let extractAbConcl = ruleRftExtractRftEquiv(a, b)
  if extractAbConcl != nil:
    debug0("AB1132")
    # TODO< implement! >
  # TODO< implement swizzled arguments! >



  # debug conclusions to output
  for iDoneDeriv in doneDerivs:
    debug0(fmt"deriver: {convTermToStr(a)} + {convTermToStr(b)} |- concl={convSentenceToStr(iDoneDeriv.concl)}")
  
  # inform listener about conclusions
  for iDoneDeriv in doneDerivs:
    globalNarInstance.conclCallback(iDoneDeriv.concl)



  if extendedTaskProcessing:

    # add task of conclusion(s)
    # TODO< filter for tasks we already added recently!!! by looking up the hash in a hashtable >
    for iDoneDeriv in doneDerivs:
      let task: Task0 = new (Task0)
      task.sentence = iDoneDeriv.concl
      task.prioCached = 0.9*premiseTaskPrio # compute priority
      if task.prioCached*retConf(task.sentence.tv) > deriverTaskInsertThreshold:
        debug0(fmt"deriver: add concl task sentence={convTermToStr(task.sentence.term)}")
        taskset0Insert(goaldrivenCtrlCtx.taskset, task)

    # add belief of conclusions
    for iDoneDeriv in doneDerivs:
      put(mem, iDoneDeriv.concl) # store as belief

  return doneDerivs


# unify for Q&A
proc checkUnifyQa(questionTerm: TermObj, judgementTerm: TermObj): bool =
  let unifyResult = termTryUnifyAndAssign3(questionTerm, judgementTerm, unifyModeQvar)
  return unifyResult.isSome()


# give one step to Q&A
proc ctrlQaStep*() =


  if questionTaskset.set0.len == 0:
    return # nothing to process
  
  block: # block for bag-like random sampling of processed question
    # select random question task
    # TODO LOW< select by priority distribution of question >

    let selTaskIdx = narRand.rand(questionTaskset.set0.len-1)
    let selQuestionTask: Task0 = questionTaskset.set0[selTaskIdx]

    # try to answer with better answer
    let relevantConceptTerms: seq[TermObj] = termRetConcepts(selQuestionTask.sentence.term)

    # NOTE< we use here a heavy expensive solution where we examine all beliefs of the relevant concept
    #       a cheaper way would be to limit it to the most active concepts by lookup of concept priority by term of belief
    #     >
    for iRelevantConceptTerm in relevantConceptTerms:
      
      let iRelevantConcept: ConceptObj = memLookupConceptByName(globalNarInstance.mem, iRelevantConceptTerm)
      if iRelevantConcept != nil: # was concept found

        for iBelief in iRelevantConcept.content.content:
          if checkUnifyQa(selQuestionTask.sentence.term, iBelief.term):
            var isBetterSolution: bool = false
            if selQuestionTask.bestAnswer == nil: # no answer was found yet?
              isBetterSolution = true # this is a better answer

            if selQuestionTask.bestAnswer != nil:
              isBetterSolution = retConf(iBelief.tv) > retConf(selQuestionTask.bestAnswer.tv) # choice rule: choose the one with highest confidence
            
            if isBetterSolution:
              # FIXME< do we need to deep copy the sentence here? >
              selQuestionTask.bestAnswer = iBelief

              # * call callback
              if qaHandler != nil:
                qaHandler(selQuestionTask.sentence, selQuestionTask.bestAnswer)

              # DEBUG
              debug0(fmt"Q&A: found better answer. q={convSentenceToStr(selQuestionTask.sentence)} a={convSentenceToStr(iBelief)}")



      # TODO


# do one inference step of the deriver
# control: part of the main loop
proc ctrlStep*() =

  debug0("cntr: entry()", 10)

  # take out task to work on
  let topTask: Task0 = taskset0TryPopTop(goaldrivenCtrlCtx.taskset)
  if topTask == nil:
    debug0(fmt"ctrl: info: nothing to work on in queue!", 5)
    # nothing to work on!
    return
  
  
  let term51 = termMkName("CTRL0") # term which names the concept where we store all control contingencies
  let selConcept: ConceptObj = memLookupConceptByName(globalNarInstance.mem, term51)
  if selConcept != nil: # was concept found
    debug0(fmt"ctrl: concept ""{convTermToStr(selConcept.name)}"" was found!")

    let premiseATerm: TermObj = topTask.sentence.term

    # lookup 'premiseATerm' as a precondition in the beliefs of "CTRL0"
    for iCtrlBeliefSentence in selConcept.content.content:

      # match premiseATerm to (premiseATerm, OP) --> CTRL0
      case iCtrlBeliefSentence.term.type0
      of inh:
        let inhSubj = iCtrlBeliefSentence.term.subject
        case inhSubj.type0
        of sequence:
          let seqPreconditionTerm: TermObj = inhSubj.items0[0]
          let seqPostconditionTerm: TermObj = inhSubj.items0[1]


          # now that we have the candidate precondition we need to match it
          if termEq(premiseATerm, seqPreconditionTerm):
            
            debug0(fmt"ctrl: found match in precondition of CTRL0. precondition.term={convTermToStr(premiseATerm)}")
            
            debug0("TODO TODO TODO TODO")


        else:
          discard
      else:
        discard

  else:
    if verbosityDbgA > 0:
      debug0(fmt"warn: concept ""{convTermToStr(term51)}"" was not found!")
  
  ## execute hardcoded deriver
  # we do this here to 'bootstrap' known derivations for the more flexible derivation path
  var doneDerivs: seq[DoneDerivObj] = @[]

  # * single premise inference
  block:
    let doneDerivs2: seq[DoneDerivObj] = deriveSinglePremiseInternal(topTask.sentence.term, topTask.sentence.tv, topTask.sentence.stamp)
    doneDerivs = doneDerivs & doneDerivs2
    

  # * we collect the 2nd premises
  var viable2ndPremises: seq[SentenceObj] = @[]
  for iName in termRetConcepts(topTask.sentence.term):
    let selConcept: ConceptObj = memLookupConceptByName(globalNarInstance.mem, iName)
    if selConcept != nil:
      viable2ndPremises = viable2ndPremises & selConcept.content.content

  # TODO< remove duplicates of sentences! >

  # TODO< sort premises by the priority of the concepts!, and limit the number of premises! >
  viable2ndPremises = viable2ndPremises[0..min(viable2ndPremises.len-1, 50-1)] # limit the number of premises!

  for iViable2ndPremise in viable2ndPremises:
    if not checkStampOverlap(topTask.sentence.stamp, iViable2ndPremise.stamp):
      let doneDerivs2: seq[DoneDerivObj] = deriveInternal(globalNarInstance.mem, topTask.sentence.term, topTask.sentence.tv, topTask.sentence.stamp, iViable2ndPremise.term, iViable2ndPremise.tv, iViable2ndPremise.stamp, topTask.prioCached)
      doneDerivs = doneDerivs & doneDerivs2


  ## translate done derivations to meta-knowledge and store under CTRL0
  for iDoneDeriv in doneDerivs:

    # construct pseudo-contigency to remember control path
    let term82: TermObj = termMkProd([termMkName("SELF"), iDoneDeriv.premiseBTerm])
    let term80: TermObj = termMkInh(term82, termMkName("infOp0"))
    let term81: TermObj = termMkProd(@[iDoneDeriv.premiseATerm, term80])
    let term83: TermObj = termMkInh(term81, termMkName("CTRL0"))

    let pseudoContingeny: ref Sentence = new (Sentence)
    pseudoContingeny.term = term83
    pseudoContingeny.punct = judgement


    let term51 = termMkName("CTRL0") # term which names the concept where we store all control contingencies
    let selConcept: ConceptObj = memLookupConceptByName(globalNarInstance.mem, term51)
    if selConcept != nil: # was concept found
      debug0(fmt"ctrl: concept ""{convTermToStr(selConcept.name)}"" was found!")

      # add belief to concept
      insert(selConcept.content, pseudoContingeny)

      debug0(fmt"ctrl: added CTL0 belief={convTermToStr(pseudoContingeny.term)}")
    else:
      debug0(fmt"warn: concept ""{convTermToStr(term51)}"" was not found!")










# op which is doing inference of the tasks on stack and the argument passed to it!
proc infOpable*(args:seq[TermObj]) =
  let argAt0: TermObj = args[1] # is the first "argument" which is the term

  debugEcho fmt"DBG: infOpable() called"
  debugEcho fmt"DBG:    premiseA={convTermToStr(goaldrivenCtrlCtx.conditionPremiseTerm)}"
  debugEcho fmt"DBG:    premiseB={convTermToStr(argAt0)}"
  
  # TODO< add code to search for premises in memory!!!/in the tasks >

  #let doneDerivs: seq[DoneDerivObj] = deriveInternal(goaldrivenCtrlCtx.mem, goaldrivenCtrlCtx.conditionPremiseTerm, argAt0, 1.0)
  #goaldrivenCtrlCtx.doneDerivs = doneDerivs # pass over the done derivations of this derivation













    



# compute depth of the tokens
proc parserCalcDepthOfTokens(tokens: seq[Token0Obj]) =
  var currentDepth: int = 0
  
  for iIdx in 0..<tokens.len:
    var selToken = tokens[iIdx]

    case selToken.type0
    of TokenTypeEnum.open, braceOpen:
      currentDepth += 1
    of TokenTypeEnum.close, braceClose:
      currentDepth -= 1
    else:
      discard
    
    selToken.depth = currentDepth






# TODO< dispatch question and judgement on input side of narInput() >


















#[ commented because it was for testing the macro
block:
  var concl: TermObj = nil
  var conclTv: Tv = makeTv(0.0, 0.0)
  let a: TermObj = termMkInh(termMkName("x"), termMkName("t")) # premise A
  let aTv: Tv = makeTv(1.0, 0.92)
  let b: TermObj = termMkInh(termMkName("t"), termMkName("e")) # premise B
  let bTv: Tv = makeTv(1.0, 0.92)
  z0(inh(A, B), inh(B, C), "Ded", inh(A, C))

  echo("")

  echo(concl != nil)
]#



# global stamp-id counter
var globalStampIdCnt: int64 = 1

# creates new unique stamp
proc makeStamp*(): seq[int64] =
  let res: seq[int64] = @[globalStampIdCnt]
  globalStampIdCnt+=1
  return res






















































###########################
# ANTICIPATION

type
  AnticipationInFlightRef* = ref AnticipationInFlight
  AnticipationInFlight* = object
    #anticipatedTermCached*: TermObj # term of the anticipated event
    
    predImplLink*: PredImplLinkObj # link to =/>

    removalOccTime*: int64 # time when the anticipation will be removed automatically

var anticipationsInFlight: seq[AnticipationInFlightRef] = @[]


# internal helper for pos/neg-confirm
proc anticipationConfirm(predImplLink: PredImplLinkObj, sign:int) =
  var c: float64 = 0.01
  if sign == -1:
    c*=0.8 # neg confirm is weaker than pos confirm

  let f: float64 = max(float64(sign), 0.0)
  predImplLink.tv = tvRev(predImplLink.tv, makeTv(f,c))

# add a anticipation and neg-confirm it (assumption of failure)
proc anticipationPutAndNegConfirm(predImplLink: PredImplLinkObj) =
  anticipationConfirm(predImplLink, -1) # neg confirm

  let removalOccTime: int64 = globalNarInstance.currentTime + 20
  var anticipation = AnticipationInFlightRef(predImplLink:predImplLink, removalOccTime:removalOccTime)
  anticipationsInFlight.add(anticipation)
  # TODO LOW< force to maintain AIKR >




# called when ever a event happend
# responsible for pos-confirm
proc anticipationObserve(t: TermObj) =
  var iidx: int = 0
  while iidx < anticipationsInFlight.len-1:
    let iAnticipation = anticipationsInFlight[iidx]
    
    if termEq(t, iAnticipation.predImplLink.pred):
      anticipationConfirm(iAnticipation.predImplLink, 1) # pos confirm
      
      # remove
      anticipationsInFlight.delete(iidx)
      iidx-=1
    
    iidx+=1


# called every cycle for maintaining
proc anticipationMaintain() =
  var iidx: int = 0
  while iidx < anticipationsInFlight.len-1:
    let iAnticipation = anticipationsInFlight[iidx]
    
    if globalNarInstance.currentTime >= iAnticipation.removalOccTime:
      # remove
      anticipationsInFlight.delete(iidx)
      iidx-=1
    
    iidx+=1



















#####
# PROJECTION layer

# this layer (projection layer) is used to update the projected tv of the event
proc projectionLayerUpdateProjectedTv(e: var EventObj) =
  # TODO LOW< implement projection!!! >
  e.tvProjected = e.s.tv















######
# PERCEPTION LAYER
#
# the task of the perception layer is to combine events into derived events, which are in turn used for derivation again

proc perceptionLayerInjectConclEvent(event: EventObj, enableEternalization: bool) =
  
  debug0(&"perception layer: injectConclEvent event.sentence={convSentenceToStr(event.s)}    enableEternalization={enableEternalization}")

  # * add derived event back as task
  # TODO LOW < implement me!!! >

  # * eternalize
  if enableEternalization:
    # TODO LOW< apply eternalization TV function >
    
    
    discard







# "GC" for procedural stuff
# implementation: function is called in every cycle
proc proceduralKeepUnderAikrCollector() =
  if (globalNarInstance.currentTime mod 50) == 0:
    discard
    # TODO< keep globalNarInstance.eventsByOccTime under bound >

    memGc(globalNarInstance.mem)
    memGc(globalNarInstance.goalMem)

# retrieve events in a time-range
proc collectEventsInOccRange*(minOccTime: int64, maxOccTime: int64): seq[EventObj] =
  var res: seq[EventObj] = @[]
  for iOccTime in minOccTime..maxOccTime:
    if iOccTime in globalNarInstance.eventsByOccTime:
      for iv in globalNarInstance.eventsByOccTime[iOccTime]:
        res.add(iv)
  return res

# helper
proc calcRandomIndices(n: int): seq[int] =
  var potential: seq[int] = @[]
  for iv in 0..n-1:
    potential.add(iv)
  
  var res: seq[int] = @[]
  for i in 0..n-1:
    let selIdx = procRng.rand(potential.len-1)
    res.add(potential[selIdx])
    potential.delete(selIdx)
  return res

# helper
proc selectRandomSubsetWithDifferentOccTime(candidateEvents: seq[EventObj], n: int): seq[EventObj] =
  var res: seq[EventObj] = @[]
  var idxArr: seq[int] = calcRandomIndices(min(n, candidateEvents.len))
  sort(idxArr, cmp)
  for iidx in idxArr:
    res.add(candidateEvents[iidx])
  return res

# helper to sample a contigency and put it into memory
proc proceduralSampleAndBuildContigency*(mem: MemObj) =
  if not enProceduralSampleAndBuildContigency:
    return # return if this deriver is disabled

  debug0("proceduralSampleAndBuildContigency(): ENTER", 10)
  
  let eventsInRange: seq[EventObj] = collectEventsInOccRange(globalNarInstance.currentTime-10, globalNarInstance.currentTime+1)

  # sample random events from that
  let selSequentialEvents: seq[EventObj] = selectRandomSubsetWithDifferentOccTime(eventsInRange, 3) # select random subset in order
  
  if selSequentialEvents.len != 3:
    return # can't build!

  # build contigency
  let selEvent0: EventObj = selSequentialEvents[0]
  let selEvent1: EventObj = selSequentialEvents[1]
  let selEvent2: EventObj = selSequentialEvents[2]

  let contigencySeqTerm: TermObj = termMkSeq(selEvent0.s.term, selEvent1.s.term)
  let contigencySeqTv: Tv = makeTv(1.0, 0.92) # HACK   TODO<fix me and calculate this correctly>
  let contigencySeqStamp: seq[int64] = merge(selEvent0.s.stamp, selEvent1.s.stamp, STAMPMAXLEN)

  let contingencySeqSentence: SentenceObj = SentenceObj(term: contigencySeqTerm, tv: contigencySeqTv, punct:judgement, stamp:contigencySeqStamp)
  debug0(&"proceduralSampleAndBuildContigency():    built seq={convSentenceToStr(contingencySeqSentence)}")
  # add seq to memory
  mem.put(contingencySeqSentence)
  
  # * add contigency into memory
  mem.put(selEvent2.s) # we need to make sure that the predicate of =/> is in memory before adding the link
  block: # add the link of =/> to subject
    let predImplPredConcept: ConceptObj = memLookupConceptByName(mem, selEvent2.s.term)
    if predImplPredConcept != nil:
      var createdLink: PredImplLinkObj = new (PredImplLinkObj)
      createdLink.target = contingencySeqSentence.term
      createdLink.tv = makeTv(1.0, 0.92) # HACK   TODO MID< compute TV >
      createdLink.stamp = merge(contingencySeqSentence.stamp, selEvent2.s.stamp, STAMPMAXLEN)
      createdLink.pred = selEvent2.s.term # we need to add the predicate
      
      # update all beliefs to point to the subject of =/>
      for iBelief in predImplPredConcept.content.content:
        if termEq(iBelief.term, selEvent2.s.term):
          sentenceUpdateLink(iBelief, createdLink)
      




# rule (A, B)! |- A!
proc ruleNal7SeqDetach2(aTerm: TermObj, aTv: Tv): ref tuple[term: TermObj, tv: Tv] =
  case aTerm.type0
  of sequence:
    let c: ref tuple[term: TermObj, tv: Tv] = new (tuple[term: TermObj, tv: Tv])
    c.term = aTerm.items0[0]
    c.tv = aTv
    return c      
  else:
    return nil



# rule (A, B)!, A |- B!
# rule (A0, A1, B)!, (A0, A1) |- B!
proc ruleNal7SeqDetach(aTerm: TermObj, aTv: Tv, bTerm: TermObj, bTv: Tv): ref tuple[term: TermObj, tv: Tv, unifiedPremiseTerm: TermObj] =
  case aTerm.type0
  of sequence:
    # (a, b, c) will return (a, b)
    # (a, b) will return a
    #debug0(&"NAL7 detach   {convTermToStr(aTerm)}")
    let aTermWithoutLastItem: TermObj = seqRemoveLastAndCastToTermIfNecessary(aTerm)
    #debug0(&"NAL7 detached {convTermToStr(aTermWithoutLastItem)}")

    var lenA: int = 1
    case aTermWithoutLastItem.type0
    of sequence:
      lenA = aTermWithoutLastItem.items0.len
    else:
      lenA = 1


    # try to unify
    debug0(&"rule00: try to unify {convTermToStr(aTermWithoutLastItem)} with {convTermToStr(bTerm)} ...")
    let unifyOpt = termTryUnifyAndAssign3(aTermWithoutLastItem, bTerm, unifyModeUvar)
    debug0(&"rule00: ... result={unifyOpt.isSome()}")
    
    if unifyOpt.isSome():
      let c: ref tuple[term: TermObj, tv: Tv, unifiedPremiseTerm: TermObj] = new (tuple[term: TermObj, tv: Tv, unifiedPremiseTerm: TermObj])

      if aTerm.items0.len - lenA > 1:
        c.term = TermObj(type0:sequence, items0:aTerm.items0[lenA..aTerm.items0.len-1])
      elif aTerm.items0.len - lenA == 1:
        c.term = aTerm.items0[lenA]
      else:
        return nil # either invalid case (in that case silently ignore) or not implemented case! 
      ###elif aTerm.items0.len < 2:
      ###  return nil # invalid case, silently ignore
      ###else:
      ###  # not implemented case!
      ###  return nil

      c.term = unifySubstitute(c.term, unifyOpt.get().vars)
      c.unifiedPremiseTerm = unifySubstitute(aTermWithoutLastItem, unifyOpt.get().vars)
      c.tv = tvGoalDed(aTv, bTv)
      return c      

    else:
      return nil
  else:
    return nil

# rule B!:|: A=/>B |- A!:|:
proc ruleNal7PredImplDetach(aTv: Tv, bTerm: TermObj, bTv: Tv): ref tuple[term: TermObj, tv: Tv] =
  case bTerm.type0
  of predImpl:
    let c: ref tuple[term: TermObj, tv: Tv] = new (tuple[term: TermObj, tv: Tv])
    c.term = bTerm.subject
    c.tv = tvGoalDed(aTv, bTv) # like in ONA
    return c
  else:
    return nil




# rule A.:|: B.:|: |- (A,B)
proc ruleNal7BuildSeq(aTerm: TermObj, aTv: Tv, bTerm: TermObj, bTv: Tv): ref tuple[term: TermObj, tv: Tv] =
  let c: ref tuple[term: TermObj, tv: Tv] = new (tuple[term: TermObj, tv: Tv])
  c.term = termMkSeq(aTerm, bTerm)
  c.tv = tvInt(aTv, bTv)
  return c

# rule A.:|: B.:|: |- <A=/>B>
proc ruleNal7BuildPredImpl(aTerm: TermObj, aTv: Tv, bTerm: TermObj, bTv: Tv): ref tuple[term: TermObj, tv: Tv] =
  let c: ref tuple[term: TermObj, tv: Tv] = new (tuple[term: TermObj, tv: Tv])
  c.term = termMkPredImpl(aTerm, bTerm)
  c.tv = tvInd(bTv, aTv)
  return c






# tries to convert sequence to relation
# ex:
#   converts (A-->a, B-->b) to (A*B)-->(a*b)
# /return nil if no relation can be derived
proc convSeqToRel(t: TermObj): TermObj =
  case t.type0
  of sequence:
    var resTuples: seq[tuple[s:TermObj, p:TermObj]] = @[]
    for iComponent in t.items0:
      case iComponent.type0
      of inh:
        resTuples.add((iComponent.subject, iComponent.predicate))
      else:
        return nil # can't convert component of sequence - give up
    
    var inhSubjSideContent: seq[TermObj] = @[]
    var inhPredSideContent: seq[TermObj] = @[]
    for iTuple in resTuples:
      inhSubjSideContent.add(iTuple.s)
      inhPredSideContent.add(iTuple.p)
    
    let conclTerm: TermObj = termMkInh(termMkProd2(inhSubjSideContent), termMkProd2(inhPredSideContent))
    return conclTerm

  else:
    return nil
































# must be <= 1.0
var kp: float = 1.0 # penality skew of positive goal for calc base priority of

# compute the base priority of a goal task
proc calcGoalBasePriority(tv: Tv): float64 =
  if tv.f > 0.5:
    return kp*calcExp(tv) # pos goal case
  else:
    let tvInv = makeTv(1.0-tv.f, tv.retConf()) # inverted TV
    return calcExp(tvInv) # neg goal case



type
  GoalTask0Obj = ref GoalTask0
  GoalTask0 = object
    goal: GoalObj
    prioCached: float # priority of the task (cached value)


# taskset for goals to process
var goalTaskset: Taskset0[GoalTask0Obj]
block:
  proc goaltask0cmpFn(a: GoalTask0Obj, b: GoalTask0Obj): int =
    return cmp(a.prioCached, b.prioCached)
  goalTaskset = new(Taskset0[GoalTask0Obj])
  goalTaskset.maxLen = 50
  goalTaskset.set0 = @[]
  goalTaskset.cmpFn = goaltask0cmpFn






# called when ever a goal was derived by the goal system or put into the system
# this function stores the goal
proc goalSystemPutGoal*(e: EventObj, goalMem: MemObj, wasDerived: bool) =
  debug0(&"goalSystemPutGoal(): called with g={convSentenceToStr(e.s)}")
  
  # * store the goal to active goals
  var g: GoalObj = GoalObj(e:e)


  globalNarInstance.allGoalsByDepth[0].goals.add(g)
  # TODO< try to apply choice/revise if term is already present >

  put(goalMem, g.e.s)



  # add goal as task to goal tasks
  block:
    let goalTask: GoalTask0Obj = new (GoalTask0Obj)
    goalTask.goal = g
    goalTask.prioCached = calcGoalBasePriority(goalTask.goal.e.s.tv)
    taskset0Insert(goalTaskset, goalTask)
  







discard """ # not needed anymore

type
  Adt0Obj = ref Adt0
  Adt0* = object
    mem: MemObj
    goalMem: MemObj # memory with goals
    #premiseB: SentenceObj # can be nil
    reactFn: proc(self: Adt0Obj, premiseA: EventObj) # function which is called when the Adt is triggered
    concls: seq[EventObj] # non-goal conclusions generated
    #conclsGoals: seq[GoalObj] # goal conclusions generated



# ADT to process (selected event from pending event tasks) to match it with a goal by looking up the goal in goal-system concepts
#
# example: event A.:|:    ,,find (A, B)!:|:,, do derivation
proc reactFnJudgementDetach(self: Adt0Obj, premiseA: EventObj) =
  self.concls = @[] # flush

  debug0("reactFnJudgementDetach(): ENTER")
  defer: debug0("reactFnJudgementDetach(): EXIT")

  debug0(&"reactFnJudgementDetach():    premiseA={convSentenceToStr(premiseA.s)}")

  debug0(&"reactFnJudgementDetach():    goalMem.nConcepts={self.goalMem.concepts.len}")

  let matchingGoalConcept: ConceptObj = self.goalMem.memLookupConceptByName(premiseA.s.term)
  if matchingGoalConcept == nil:
    return # no matching concept, can't derive anything!



  # * filter for sequences with matching first item
  var candidateGoals: seq[SentenceObj] = matchingGoalConcept.content.content
  debug0(&"{candidateGoals.len}")
  proc checkIsCandidateSeq(t: TermObj): bool =
    case t.type0
    of sequence:
      if t.items0.len > 0:
        return termCheckUnify(t.items0[0], premiseA.s.term)
      else:
        return false
    of TermTypeEnum.name, inh, predImpl, `tuple`, prod, uvar, qvar, impl:
      return false
  candidateGoals = filter(candidateGoals, proc(iv: SentenceObj): bool = checkIsCandidateSeq(iv.term))

  # * order candidates by score derived by priority!
  # TODO LOW
  
  # * select premise
  if candidateGoals.len == 0:
    return

  var selGoalPremise: SentenceObj = nil
  block:
    var selIdx = procRng.rand(candidateGoals.len-1)
    selGoalPremise = candidateGoals[selIdx]
  

  # * derive
  let conclOpt = ruleNal7SeqDetach(selGoalPremise.term, selGoalPremise.tv, premiseA.s.term, premiseA.tvProjected)
  
  # * store goals
  if conclOpt == nil:
    return


  let conclSentence = SentenceObj(term:conclOpt.term, tv:conclOpt.tv, punct:goal, stamp:merge(selGoalPremise.stamp, premiseA.s.stamp, STAMPMAXLEN), originContingency:selGoalPremise.originContingency)
  let conclEvent = EventObj(s:conclSentence, occTime:premiseA.occTime)

  debug0(&"reactFnJudgementDetach():    concl={convSentenceToStr(conclEvent.s)}")

  self.concls.add(conclEvent)







# ADT react function for detaching of goals
proc reactFnGoalDetach(self: Adt0Obj, premiseA: EventObj) =
  self.concls = @[] # flush



  let matchingBeliefConcept: ConceptObj = self.mem.memLookupConceptByName(premiseA.s.term)
  if matchingBeliefConcept == nil:
    return # no matching concept, can't derive anything!


  # * filter for sequences with matching first item
  var candidateBeliefs: seq[SentenceObj] = matchingBeliefConcept.contentProcedural.content
  proc checkIsCandidateSeq(t: TermObj): bool =
    case t.type0
    of sequence:
      if t.items0.len > 0:
        return termEq(t.items0[0], premiseA.s.term)
      else:
        return false
    of TermTypeEnum.name, inh, predImpl, `tuple`, prod, uvar, qvar, impl:
      return false
  candidateBeliefs = filter(candidateBeliefs, proc(iv: SentenceObj): bool = checkIsCandidateSeq(iv.term))

  # * order candidates by score derived by priority!
  # TODO LOW
  
  # * select premise
  if candidateBeliefs.len == 0:
    return

  var selBeliefPremise: SentenceObj = nil
  block:
    var selIdx = procRng.rand(candidateBeliefs.len)
    selBeliefPremise = candidateBeliefs[selIdx]
  

  # * derive
  let conclOpt = ruleNal7SeqDetach(selBeliefPremise.term, selBeliefPremise.tv, premiseA.s.term, premiseA.s.tv)
  
  # * store goals
  if conclOpt == nil:
    return


  let conclSentence = SentenceObj(term:conclOpt.term, tv:conclOpt.tv, punct:goal, stamp:premiseA.s.stamp, originContingency:premiseA.s.originContingency)
  let conclEvent = EventObj(s:conclSentence, occTime:premiseA.occTime)
  self.concls.add(conclEvent)










# ADT react function for B!:|:  A=/>B |- A!:|:
# see https://github.com/opennars/OpenNARS-for-Applications/blob/master/src/Inference.c#L99
proc reactFnGoalDeduction(self: Adt0Obj, premiseAArg: EventObj) =
  debug0("reactFnGoalDeduction(): ENTER")
  debug0(&"reactFnGoalDeduction():    goal={convSentenceToStr(premiseAArg.s)}")

  self.concls = @[] # flush

  # we need to fetch the goal by term
  # this is necessary because the sentence premiseAArg may contain outdated =/>links
  var selGoalConcept: ConceptObj = self.mem.memLookupConceptByName(premiseAArg.s.term)
  if selGoalConcept == nil:
    # doesn't exist
    # should exist, emit a warning
    debug0("reactFnGoalDeduction():    WANRINGDEV concept should exist in goalMem but wasnt found!")
    return
  
  var premiseGoalSentence: SentenceObj = nil
  for iGoal in selGoalConcept.content.content:
    if termEq(iGoal.term, premiseAArg.s.term):
      premiseGoalSentence = iGoal
      break
  
  if premiseGoalSentence == nil:
    # goal wasnt found in concept, this can happen if the goal falls out of the concept because of AIKR
    return


  # select random link
  if premiseGoalSentence.predImplLinks.len == 0:
    debug0("reactFnGoalDeduction(): HERE3")
    return # nothing to select/do

  debug0("reactFnGoalDeduction(): HERE1")

  var selPredImplLink: PredImplLinkObj = nil
  block:
    let selIdx = procRng.rand(premiseGoalSentence.predImplLinks.len-1)
    selPredImplLink = premiseGoalSentence.predImplLinks[selIdx]

  debug0("reactFnGoalDeduction(): HERE2")



  # * derive
  let conclOpt = ruleNal7PredImplDetach(premiseGoalSentence.tv,   termMkPredImpl(selPredImplLink.target, premiseGoalSentence.term), selPredImplLink.tv)
  if conclOpt == nil: # should never happen
    return

  # * build conclusion and add
  let conclSentence = SentenceObj(term:conclOpt.term, tv:conclOpt.tv, punct:goal, stamp:merge(premiseGoalSentence.stamp, selPredImplLink.stamp, STAMPMAXLEN), originContingency:selPredImplLink)
  let conclEvent = EventObj(s:conclSentence, occTime:premiseAArg.occTime)
  self.concls.add(conclEvent)
"""







# internal action to react to finishing of execution of op
# /param unifiedLinkSeqTerm the unified premise term ex: (a, <x -->y>)    from (a, %%0-->y)
proc wasExecutedInternalAction*(g: GoalObj, link: PredImplLinkObj, unifiedLinkSeqTerm: TermObj) =
  #return # HACK< we don't care about building the RFT relation!!! >

  debug0(&"WEIA00: {convTermToStr(g.e.s.term)}")
  debug0(&"WEIA02: {convTermToStr(link.target)}")

  #if g.e.s.originContingency == nil:
  if link == nil:
    # HACK because the contingency should be valid!
    fixme0("wasExecutedInternalAction(): originContingency is nil! RETURN!")
    return

  # derive the RFT relation by mapping the sequence of the (...,...)=/> to a RFT relation event
  let seqTerm: TermObj = unifiedLinkSeqTerm ##link.target
  let seqTerm2: TermObj = seqTerm ## seqRemoveLast(seqTerm) # seq without last component

  debug0(&"WEIA01: {convTermToStr(seqTerm2)}")

  let rftRelationTerm: TermObj = convSeqToRel(seqTerm2)
  


  if rftRelationTerm != nil: # must be valid!
    
    
    debug0(&"WEIA02: {convTermToStr(rftRelationTerm)}")

    # * build sentence with the right stamp with term "rftRelationTerm"
    let conclSentence = SentenceObj(term:rftRelationTerm, tv:link.tv, punct:judgement, stamp:link.stamp, originContingency:nil)
    debug0(&"WEIA03: RFT: built RFT relation sentence={convSentenceToStr(conclSentence)}")
    globalNarInstance.conclCallback(conclSentence) # call callback because we derived it

    # * derived sentence as event
    let conclEvent = EventObj(s:conclSentence, occTime:g.e.occTime)

    # * inject
    let enEternalization = true # we eternalize (is this wrong?)
    perceptionLayerInjectConclEvent(conclEvent, enEternalization)



# enable experimental support for long execution of ops (op is configured to be capable of long execution span)
var enExperimentalOpLongExec*: bool = false # CONFIG

# record to keep track of op exec in flight
type OpExecInFLightRef* = ref object
  name*: string # name of the op in flight
  # invokeTime*: int64 # NAR time when the op was invoked first

# list of pending ops
# AIKR< not bound under AIKR because there are not many ops in flight at any point in time! >
var opExecInFlight*: seq[OpExecInFlightRef] = @[]

# set of judgement events to get processed
# removal policy: items are not removed
var procEligableEventJudgements*: seq[EventObj] = @[]





# supprt for long exec ops - called from the outside when the exeuction of a long op was finished
proc callbackOpExecLongFinished*(opName: string) =
  var opExecInFlight2: seq[OpExecInFlightRef] = @[]
  # remove from in flight
  for z in opExecInFlight:
    if opName != z.name:
      opExecInFlight2.add(z)
  opExecInFlight = opExecInFlight2




proc processGoalInner*(mem: MemObj, goalMem: MemObj, selGoal: GoalObj, opRegistry: OpRegistryObj) =
  debug0("processGoalInner(): ENTER")
  defer: debug0("processGoalInner(): EXIT")
  debug0(&"processGoalInner(): called with goal g={convSentenceToStr(selGoal.e.s)}")
  debug0(&"processGoalInner():                  g={convSentenceToStr2(selGoal.e.s)}")




  let premiseGoalSentence: SentenceObj = selGoal.e.s

  #########
  # decision making algorithm as done in ONA as described in Patrick's thesis
  var subgoals: seq[SentenceObj] = @[]
  var bestDesire: float64 = 0.0
  var bestOp: TermObj = nil
  var bestSelLink: PredImplLinkObj = nil # link of best one
  var bestUnifiedPremiseTerm: TermObj = nil


  let matchingGoalConcept: ConceptObj = mem.memLookupConceptByName(premiseGoalSentence.term)
  if matchingGoalConcept == nil:
    debug0(&"PG9: warn: could not find a concept for {convTermToStr(premiseGoalSentence.term)}")
    return # no matching concept, can't derive anything!
  
  debug0(&"PG0 sentence={convSentenceToStr(premiseGoalSentence)}")


  # collect all implication links
  var allPredImplLinks: seq[PredImplLinkObj] = @[]

  for iSentence in matchingGoalConcept.content.content:
    debug0("PG2")
    debug0(&"PG3 a={convTermToStr(iSentence.term)}")
    debug0(&"PG4 b={convTermToStr(premiseGoalSentence.term)}")
    
    if termEq(iSentence.term, premiseGoalSentence.term):
      allPredImplLinks = iSentence.predImplLinks
  
  for iPredImplLink in allPredImplLinks:
    debug0("PG1")

    # derive (x_i, op_i)!
    let conclSeqOpt = ruleNal7PredImplDetach(premiseGoalSentence.tv,   termMkPredImpl(iPredImplLink.target, premiseGoalSentence.term), iPredImplLink.tv)
    if conclSeqOpt == nil: # should never happen
      continue

    # derive x_i!
    let conclCondOpt = ruleNal7SeqDetach2(conclSeqOpt.term, conclSeqOpt.tv)
    if conclCondOpt == nil: # should never happen
      continue

    # add subgoal to subgoals
    var subgoalSentence: SentenceObj = new (SentenceObj)
    subgoalSentence.term = conclCondOpt.term
    subgoalSentence.tv = conclCondOpt.tv
    subgoalSentence.punct = goal
    subgoalSentence.stamp = merge(premiseGoalSentence.stamp, iPredImplLink.stamp, STAMPMAXLEN)
    subgoalSentence.originContingency = iPredImplLink
    subgoals.add(subgoalSentence)



    # PERCEPTION: perceive a event as a current event
    var lastProcEligableEventJudgements: seq[EventObj] = @[]
    block:
      var nLast: int = 20
      
      var additionalJudgementEvents: seq[EventObj] = procEligableEventJudgements[max(procEligableEventJudgements.len-1-nLast, 0)..procEligableEventJudgements.len-1]

      lastProcEligableEventJudgements = concat(lastProcEligableEventJudgements, additionalJudgementEvents)

    # PERCEPTION: perceive built judgement events
    #             for example (a, b). :|:
    if true:
      var additionalJudgementEvents: seq[EventObj] = @[]

      for iEvent in globalNarInstance.narDerivedEventsSampledSetLevel1.set0:
        var iEvent2: EventObj
        iEvent2.s = iEvent.s
        iEvent2.occTime = iEvent.occTime
        additionalJudgementEvents.add(iEvent2)

      lastProcEligableEventJudgements = concat(lastProcEligableEventJudgements, additionalJudgementEvents)


    for iIdx in 0..<lastProcEligableEventJudgements.len:
      var iselPerceivedEvent = lastProcEligableEventJudgements[iIdx]
      #var iselPerceivedEvent: EventObj
      #block:
      #  debug0(&"PB7: len of procEligableEventJudgements={procEligableEventJudgements.len}", 5)
      #  if procEligableEventJudgements.len == 0:
      #    return
      #
      #  # (we use random sampling here for simplicity)
      #  let selIdx: int = procRng.rand(procEligableEventJudgements.len-1)
      #  iselPerceivedEvent = procEligableEventJudgements[selIdx]

      debug0(&"PG5: sel judgement premise event={convSentenceToStr(iselPerceivedEvent.s)}")
      # now we can derive something based on that as a premise 

      # update projected tv by current time
      projectionLayerUpdateProjectedTv(iselPerceivedEvent)    
      
      debug0(&"PG10 {convTermToStr(iselPerceivedEvent.s.term)} + {convTermToStr(conclSeqOpt.term)}")

      let conclOpOpt = ruleNal7SeqDetach(conclSeqOpt.term, conclSeqOpt.tv, iselPerceivedEvent.s.term, iselPerceivedEvent.s.tv)    
      if conclOpOpt == nil:
        debug0(&"PG8, detach concl is null! continue")
        
        continue

      debug0(&"PG7: term={convTermToStr(conclOpOpt.term)} exp={calcExp(conclOpOpt.tv)}")

      if calcExp(conclOpOpt.tv) > bestDesire:
        bestDesire = calcExp(conclOpOpt.tv)
        bestOp = conclOpOpt.term
        bestSelLink = iPredImplLink
        bestUnifiedPremiseTerm = conclOpOpt.unifiedPremiseTerm
      



  
  # motor babbling
  block:
    # TODO< implement! >
    discard


  # decision making / subgoal derivation
  if bestDesire > globalNarInstance.decisionThreshold:
    
    # * execute op
    let parseOpResult = tryParseOp(bestOp)
    case parseOpResult.resType
    of ParseOpRes:
      var enOpExec0: bool = true # enable op execution?


      # special handling for op which is handled with long execution
      # 
      # in that case we pretend that the op was executed if it's still pending
      # to avoid calling the same op again and again thus restarting a long process triggered by beginning of the op
      if enExperimentalOpLongExec:

        # check if op is already executing without confirmation of finishing, if so, pretend that it was executed by diabling execution
        for iOpExecInFLight in opExecInFlight:
          if iOpExecInFLight.name == parseOpResult.name:
            debug0(&"PG50 ignore exec of op={parseOpResult.name} because op execution is already in flight")
            enOpExec0 = false # disable execution of op because long execution is already in flight
            break # optimization


      if enOpExec0:
        # execute op
        debug0(&"PG20 invoke op ... term={convTermToStr(bestOp)}")
        opRegistry.ops[parseOpResult.name].callback(parseOpResult.args)
        debug0(&"PG20 ...done")

        globalNarInstance.invokeOpCallback(bestOp) # call callback
        
        # * PERCEPTION: anticipation
        discard """ # commented because buggy and not the right way
        echo "selGoal.e.s.originContingency is not nil=", selGoal.e.s.originContingency!=nil
        if selGoal.e.s.originContingency == nil:
          panic("selGoal.e.s.originContingency is nil!")
        anticipationPutAndNegConfirm(selGoal.e.s.originContingency)
        """

        echo "PG21 bestSelLink is not nil=", bestSelLink!=nil
        if bestSelLink == nil:
          panicDbg("PG22 bestSelLink is nil!")
        anticipationPutAndNegConfirm(bestSelLink)

        wasExecutedInternalAction(selGoal, bestSelLink, bestUnifiedPremiseTerm) # send action that we executed the goal

        if enExperimentalOpLongExec:

          # * check if op is enabled for long execution and add to "opExecInFlight"
          if globalNarInstance.opRegistry.ops[parseOpResult.name].supportsLongCall:
            var opExecRecord: OpExecInFLightRef = new (OpExecInFLightRef)
            opExecRecord.name = parseOpResult.name
            opExecInFlight.add(opExecRecord)


    of NoneParseRes:
      discard # not a op, so it's not executable

  else:
    for iSubgoal in subgoals:
      let goalAsEvent: EventObj = EventObj(s:iSubgoal, occTime:globalNarInstance.currentTime)

      # * put to buffer
      goalSystemPutGoal(goalAsEvent, globalNarInstance.goalMem, true)

  



































# pick a goal from the queue and try to derive conclusions
proc pickGoalFromQueueAndDerive(mem: MemObj, goalMem: MemObj, opRegistry: OpRegistryObj) =
  # take out task to work on
  let topGoalTask: GoalTask0Obj = taskset0TryPopTop(goalTaskset)
  if topGoalTask == nil:
    debug0(fmt"pickGoalFromQueuAndDerive: info: nothing to work on in queue!", 10)
    # nothing to work on!
    return

  processGoalInner(mem, goalMem, topGoalTask.goal, opRegistry)


























discard """ # not needed anymore
# this part selects a perceived judgement event and tries to derive conclusions from it
proc selectJudgementEventAndDerive(mem: MemObj, goalMem: MemObj) =
  # select premise judgement event
  var selPerceivedEvent: EventObj
  block:
    debug0(&"selectJudgementEventAndDerive(): len of procEligableEventJudgements={procEligableEventJudgements.len}", 5)
    if procEligableEventJudgements.len == 0:
      return

    # (we use random sampling here for simplicity)
    let selIdx: int = procRng.rand(procEligableEventJudgements.len-1)
    selPerceivedEvent = procEligableEventJudgements[selIdx]

  debug0(&"selectJudgementEventAndDerive(): sel judgement premise event={convSentenceToStr(selPerceivedEvent.s)}")
  # now we can derive something based on that as a premise 

  # update projected tv by current time
  projectionLayerUpdateProjectedTv(selPerceivedEvent)
  
  for iReactFn in @[reactFnJudgementDetach]: # iterate over derivation mechanisms
    # * derive
    var deriverAdt: Adt0Obj = new (Adt0Obj)
    deriverAdt.mem = mem
    deriverAdt.goalMem = goalMem
    deriverAdt.reactFn = iReactFn # wire up virtual function

    # ** do actual derivation
    deriverAdt.reactFn(deriverAdt, selPerceivedEvent)
    
    for iConcl in deriverAdt.concls:
      goalSystemPutGoal(iConcl, goalMem, true)
"""











# retrieve events in a time-range
proc collectEventsInOccRange2*(minOccTime: int64, maxOccTime: int64): seq[EventRef] =
  var res: seq[EventRef] = @[]
  for iOccTime in minOccTime..maxOccTime:
    if iOccTime in globalNarInstance.eventsByOccTime:
      for iv in globalNarInstance.eventsByOccTime[iOccTime]:
        res.add(EventRef(s:iv.s, occTime:iv.occTime))
  return res

# helper
proc selectRandomSubsetWithDifferentOccTime2(candidateEvents: seq[EventRef], n: int): seq[EventRef] =
  var res: seq[EventRef] = @[]
  var idxArr: seq[int] = calcRandomIndices(min(n, candidateEvents.len))
  sort(idxArr, cmp)
  for iidx in idxArr:
    res.add(candidateEvents[iidx])
  return res





# VM for my NAR implementation


type
  Vm0CtxRef* = ref Vm0Ctx
  Vm0Ctx* = object
    
    registers*: array[16, EventRef]

func vm0make(): Vm0CtxRef =
  var registers: array[16, EventRef]
  return Vm0CtxRef(registers: registers)


# store event in register
proc vm0Store(ctx: Vm0CtxRef, regIdx: int, val: EventRef) =
  ctx.registers[regIdx] = val

proc vm0SetNil(ctx: Vm0CtxRef, regIdx: int) =
  ctx.registers[regIdx] = nil

func vm0Ret(ctx: Vm0CtxRef, regIdx: int): EventRef =
  return ctx.registers[regIdx]


# try to apply seq rule and store conclusion in destRegIdx
proc vm0TryBuildSeq(ctx: Vm0CtxRef, srcARegIdx: int, srcBRegIdx: int, destRegIdx: int) =
  ctx.registers[destRegIdx] = nil

  var a: EventRef = ctx.registers[srcARegIdx]
  var b: EventRef = ctx.registers[srcBRegIdx]
  if a == nil or b == nil:
    return
  
  if a.occTime >= b.occTime:
    return # can't build seq!

  if checkStampOverlap(a.s.stamp, b.s.stamp):
    return # can't build because of stamp overlap!

  let conclTuple: ref tuple[term: TermObj, tv: Tv] = ruleNal7BuildSeq(a.s.term, a.s.tv, b.s.term, b.s.tv)
  var conclStamp: seq[int64] = merge(a.s.stamp, a.s.stamp, STAMPMAXLEN)

  let conclSentence: SentenceObj = SentenceObj(term:conclTuple.term, tv:conclTuple.tv, punct:judgement, stamp:conclStamp, originContingency:nil)
  
  let conclEvent = EventRef(s:conclSentence, occTime:b.occTime)

  ctx.registers[destRegIdx] = conclEvent


# try to apply pred impl rule and store conclusion in destRegIdx
proc vm0TryBuildPredImpl(ctx: Vm0CtxRef, srcARegIdx: int, srcBRegIdx: int, destRegIdx: int) =
  ctx.registers[destRegIdx] = nil

  var a: EventRef = ctx.registers[srcARegIdx]
  var b: EventRef = ctx.registers[srcBRegIdx]
  if a == nil or b == nil:
    return
  
  if a.occTime >= b.occTime:
    return # can't build seq!

  if checkStampOverlap(a.s.stamp, b.s.stamp):
    return # can't build because of stamp overlap!

  let conclTuple: ref tuple[term: TermObj, tv: Tv] = ruleNal7BuildPredImpl(a.s.term, a.s.tv, b.s.term, b.s.tv)
  var conclStamp: seq[int64] = merge(a.s.stamp, a.s.stamp, STAMPMAXLEN)

  let conclSentence: SentenceObj = SentenceObj(term:conclTuple.term, tv:conclTuple.tv, punct:judgement, stamp:conclStamp, originContingency:nil)
  
  let conclEvent = EventRef(s:conclSentence, occTime:b.occTime)

  ctx.registers[destRegIdx] = conclEvent



# try to fold seq (only for seq, doesn't handled seq in non-seq)
proc vm0TryFoldSeq(ctx: Vm0CtxRef, srcRegIdx: int, destRegIdx: int) =
  if ctx.registers[srcRegIdx] == nil:
    ctx.registers[destRegIdx] = nil
    return

  var res: EventRef = new (EventRef)
  res.s = ctx.registers[srcRegIdx].s
  res.occTime = ctx.registers[srcRegIdx].occTime
  
  res.s.term = termFoldSeq(res.s.term) # fold sequence

  ctx.registers[destRegIdx] = res



# try to apply inh rule and store conclusion in destRegIdx
proc vm0TryBuildInh(ctx: Vm0CtxRef, srcARegIdx: int, srcBRegIdx: int, destRegIdx: int) =
  # TODO
  discard



# sample two events to destination registers
proc vm0SampleFromFifo2(ctx: Vm0CtxRef, destARegIdx: int, destBRegIdx: int) =
  ctx.registers[destARegIdx] = nil
  ctx.registers[destBRegIdx] = nil
  
  let eventsInRange: seq[EventRef] = collectEventsInOccRange2(globalNarInstance.currentTime-100, globalNarInstance.currentTime)

  # filter for judgement events only!
  var eventsInRange2: seq[EventRef] = @[]
  for iEvent in eventsInRange:
    if iEvent.s.punct == judgement:
      eventsInRange2.add(iEvent)


  var selSequentialEvents: seq[EventRef] = selectRandomSubsetWithDifferentOccTime2(eventsInRange2, 2) # select random subset in order
  

  if selSequentialEvents.len >= 2:
    # * check for stamp overlap
    for aIdx in 0..selSequentialEvents.len-1:
      for bIdx in 0..selSequentialEvents.len-1:
        if aIdx!=bIdx:
          if checkStampOverlap(selSequentialEvents[aIdx].s.stamp, selSequentialEvents[bIdx].s.stamp):
            return # stamp overlap, can't derive anything!


    # * order by occ time, last items are latest occ time
    block:
      func cmpFn(a: EventRef, b: EventRef): int =
        if a.occTime > b.occTime:
          return 1
        if a.occTime < b.occTime:
          return -1
        return 0
      selSequentialEvents.sort(cmpFn)
    
    # commented because this doesn't merge/stamp overlap!
    #var conclStamp: seq[int64] = merge(premiseEvents[0].s.stamp, premiseEvents[1].s.stamp, STAMPMAXLEN)
    #for iIdx in 2..premiseEvents.len-1:
    #  conclStamp = merge(conclStamp, premiseEvents[iIdx].s.stamp, STAMPMAXLEN)


    # * assign results
    ctx.registers[destARegIdx] = selSequentialEvents[0]
    ctx.registers[destBRegIdx] = selSequentialEvents[1]

# sort the two events by time (in place)
proc vm0SortByTime2(ctx: Vm0CtxRef, srcARegIdx: int, srcBRegIdx: int) =
  var a: EventRef = ctx.registers[srcARegIdx]
  var b: EventRef = ctx.registers[srcBRegIdx]

  if a == nil or b == nil:
    # can't sort - set both to nil
    ctx.registers[srcARegIdx] = nil
    ctx.registers[srcBRegIdx] = nil
    return

  if a.occTime > b.occTime: # need to swap?
    ctx.registers[srcARegIdx] = b
    ctx.registers[srcBRegIdx] = a

# select last event from FIFO and store into register
proc vm0SelLastFromFifo(ctx: Vm0CtxRef, destRegIdx: int) =
  ctx.registers[destRegIdx] = nil

  let eventsInRange: seq[EventRef] = collectEventsInOccRange2(globalNarInstance.currentTime-100, globalNarInstance.currentTime)
  if eventsInRange.len > 0:
    let lastEvent: EventRef = eventsInRange[eventsInRange.len-1]
    ctx.registers[destRegIdx] = lastEvent
  







# helper
# FIXME< remove when everything got refactored to EventRef >
proc convEventObjToEventRefArr(arr: seq[EventObj]): seq[EventRef] =
  var res: seq[EventRef] = @[]
  for x in arr:
    res.add(convEventObjToRef(x))
  return res


# draft of algorithm to segment the last "frame" of events between the last op and the op before that
# /param events: events ordered by time
proc perceptionFindLastFrame(events: seq[EventRef]): ref tuple[innerEvents:seq[EventRef], lastOp:EventRef] =
  var lastOp: EventRef = nil
  var idx: int = events.len-1
  while idx >= 0:
    if checkIsOp(events[idx].s.term):
      lastOp = events[idx]
      break
    idx-=1

  if lastOp != nil:
    return nil

  idx-=1

  var res: seq[EventRef] = @[]
  while idx >= 0:
    if checkIsOp(events[idx].s.term):
      lastOp = events[idx]
      break
    res.add(events[idx])
    idx-=1
  
  if res.len == 0:
    return nil

  var res0: ref tuple[innerEvents:seq[EventRef], lastOp:EventRef] = new (tuple[innerEvents:seq[EventRef], lastOp:EventRef])
  res.reverse()
  res0.innerEvents = res
  res0.lastOp = lastOp
  return res0















##################################
### PERCEPTION - general













##################################
### PERCEPTION - PerceptionLayer0

# type for item which is inside of box
type
  ProcessingEventBoxItemRef* = ref ProcessingEventBoxItem
  ProcessingEventBoxItem* = object
    target*: EventRef

type
  ProcessingEventBoxRef* = ref ProcessingEventBox
  ProcessingEventBox* = object
    items*: seq[ProcessingEventBoxItemRef]


# task which does inference of two premises when execution is triggered.
# it "points" to the premises
type
  ProcessingQueuedTaskRef* = ref ProcessingQueuedTask
  ProcessingQueuedTask* = object
    premisesIndirection*: seq[ProcessingEventBoxItemRef]

# set of tasks
type
  ProcessingQueuedTasksBoxRef* = ref ProcessingQueuedTasksBox
  ProcessingQueuedTasksBox* = object
    queue*: seq[ProcessingQueuedTaskRef] # tasks ordered by priority
    # TODO< implement priority sorting!!! >



# processing of a ProcessingQueuedTaskRef
# /return conclusions
proc perceptionLayerProcessQueuedTask(task: ProcessingQueuedTaskRef): seq[EventRef] =
  debug0("")
  debug0( "percpetionLayer: (PA): processQueuedTask...")
  for iIdx in 0..task.premisesIndirection.len-1:
    let iSentence = task.premisesIndirection[iIdx].target.s
    debug0(&"                       + premise={convSentenceToStr(iSentence)}")
  
  var premiseEvents: seq[EventRef] = @[]
  for iPremiseIndirection in task.premisesIndirection:
    premiseEvents.add(iPremiseIndirection.target)
  
  for aIdx in 0..premiseEvents.len-1:
    for bIdx in 0..premiseEvents.len-1:
      if aIdx!=bIdx:
        if checkStampOverlap(premiseEvents[aIdx].s.stamp, premiseEvents[bIdx].s.stamp):
          return # stamp overlap, can't derive anything!

  # order by occ time, last items are latest occ time
  block:
    func cmpFn(a: EventRef, b: EventRef): int =
      if a.occTime > b.occTime:
        return 1
      if a.occTime < b.occTime:
        return -1
      return 0
    premiseEvents.sort(cmpFn)
  
  #var conclStamp: seq[int64] = merge(premiseEvents[0].s.stamp, premiseEvents[1].s.stamp, STAMPMAXLEN)
  #for iIdx in 2..premiseEvents.len-1:
  #  conclStamp = merge(conclStamp, premiseEvents[iIdx].s.stamp, STAMPMAXLEN)



  #var conclEvent: EventObj

  var vm0Ctx: Vm0CtxRef = vm0make()


  if premiseEvents.len>=2: # try to build seq
    
    #if premiseEvents[0].occTime != premiseEvents[1].occTime: # it doesn't make any sense to build the sequence if occTime is the same
    #  let conclTuple: ref tuple[term: TermObj, tv: Tv] = ruleNal7BuildSeq(premiseEvents[0].s.term, premiseEvents[0].s.tv, premiseEvents[1].s.term, premiseEvents[1].s.tv)
    #
    #  let conclSentence: SentenceObj = SentenceObj(term:conclTuple.term, tv:conclTuple.tv, punct:judgement, stamp:conclStamp, originContingency:nil)
    #  conclEvent = EventObj(s:conclSentence, occTime:premiseEvents[1].occTime)
    vm0Store(vm0Ctx, 0, premiseEvents[0])
    vm0Store(vm0Ctx, 1, premiseEvents[1])
    vm0TryBuildSeq(vm0Ctx, 0, 1, 2)

  if premiseEvents.len>=3: # try to build seq
    #if conclEvent.occTime != premiseEvents[2].occTime: # it doesn't make any sense to build the sequence if occTime is the same
    #  let conclTuple: ref tuple[term: TermObj, tv: Tv] = ruleNal7BuildSeq(conclEvent.s.term, conclEvent.s.tv, premiseEvents[2].s.term, premiseEvents[2].s.tv)
    #
    #  let conclSentence: SentenceObj = SentenceObj(term:conclTuple.term, tv:conclTuple.tv, punct:judgement, stamp:conclStamp, originContingency:nil)
    #  conclEvent = EventObj(s:conclSentence, occTime:premiseEvents[2].occTime)
    vm0Store(vm0Ctx, 1, premiseEvents[2])
    vm0TryBuildSeq(vm0Ctx, 2, 1, 2)

  # TODO LOW< generalize building of seq independent on length of seq! >

  vm0TryFoldSeq(vm0Ctx, 2, 2) # fold sequence

  var conclEvents: seq[EventRef] = @[]

  block:
    var conclEvent2: EventRef = vm0Ret(vm0Ctx, 2)

    if conclEvent2 != nil: # always true
      debug0(&"                       ... concl={convSentenceToStr(conclEvent2.s)}")

    if conclEvent2 != nil:
      conclEvents.add(conclEvent2)
  

  # do other possible derivations
  if premiseEvents.len == 2:
    if not checkStampOverlap(premiseEvents[0].s.stamp, premiseEvents[1].s.stamp):
      let doneDerivs: seq[DoneDerivObj] = deriveInternal(nil, premiseEvents[0].s.term, premiseEvents[0].s.tv, premiseEvents[0].s.stamp   , premiseEvents[1].s.term, premiseEvents[1].s.tv, premiseEvents[1].s.stamp, 0.0, false)
      for iDoneDeriv in doneDerivs:
        debug0(&"                       ... concl={convSentenceToStr(iDoneDeriv.concl)}")

        let occTime: int64 = max(premiseEvents[0].occTime, premiseEvents[1].occTime)
        var asEvent: EventRef = EventRef(s:iDoneDeriv.concl, occTime:occTime)
        conclEvents.add(asEvent)

  elif premiseEvents.len == 1:
    let doneDerivs: seq[DoneDerivObj] = deriveSinglePremiseInternal(premiseEvents[0].s.term, premiseEvents[0].s.tv, premiseEvents[0].s.stamp)
    for iDoneDeriv in doneDerivs:
      debug0(&"                       ... concl={convSentenceToStr(iDoneDeriv.concl)}")

      let occTime: int64 = premiseEvents[0].occTime
      var asEvent: EventRef = EventRef(s:iDoneDeriv.concl, occTime:occTime)
      conclEvents.add(asEvent)

  return conclEvents




# global datastructure to hold the datastructures for processing
type
  ProcessingCtxRef* = ref ProcessingCtx
  ProcessingCtx* = object
    tupleEventBoxAndQueueTaskBox: seq[ tuple[eventBox: ProcessingEventBoxRef, queueBox: ProcessingQueuedTasksBoxRef] ]
    
    ###eventBoxIdx0: ProcessingEventBoxRef # event box at index 0
    ###queuedTaskBoxIdx0: ProcessingQueuedTasksBoxRef # box with tasks to be processed at index 0
    ###
    ###eventBoxIdx1: ProcessingEventBoxRef # event box at index 1


proc perceptionLayerMake(): ProcessingCtxRef =
  var ctx: ProcessingCtxRef = ProcessingCtxRef(tupleEventBoxAndQueueTaskBox: @[])
  for i in 0..<4:
    var v: tuple[eventBox: ProcessingEventBoxRef, queueBox: ProcessingQueuedTasksBoxRef]
    v.eventBox = ProcessingEventBoxRef(items: @[])
    v.queueBox = ProcessingQueuedTasksBoxRef(queue: @[])
    ctx.tupleEventBoxAndQueueTaskBox.add(v)

  return ctx


# helper function to flush all items in the event boxes and all tasks in the queued tasks
proc perceptionLayerFlush(ctx: ProcessingCtxRef) =
  for iIdx in 0..ctx.tupleEventBoxAndQueueTaskBox.len-1:
    ctx.tupleEventBoxAndQueueTaskBox[iIdx].eventBox.items = @[]
    ctx.tupleEventBoxAndQueueTaskBox[iIdx].queueBox.queue = @[]




# adds item and tasks for a new entity in the perception laper
proc perceptionLayerPut(event: EventRef, atLevel: int, ctx: ProcessingCtxRef) =
  if atLevel >= ctx.tupleEventBoxAndQueueTaskBox.len:
    return # can't add tasks because it is outside of maximum derivation depth

  var createdItem: ProcessingEventBoxItemRef = ProcessingEventBoxItemRef(target:event)

  # generate single premise task
  block:
    var createdTask: ProcessingQueuedTaskRef = ProcessingQueuedTaskRef(premisesIndirection: @[createdItem])
    ctx.tupleEventBoxAndQueueTaskBox[atLevel].queueBox.queue.add(createdTask) # add task to queue directly   HACKYYY!!!


  # combine with lower levels
  for iLowerLevelIdx in 0..<atLevel:
    for iItem in ctx.tupleEventBoxAndQueueTaskBox[iLowerLevelIdx].eventBox.items:
      # compose premises of task
      var createdTask: ProcessingQueuedTaskRef = ProcessingQueuedTaskRef(premisesIndirection: @[])
      createdTask.premisesIndirection.add(createdItem)
      createdTask.premisesIndirection.add(iItem)

      # check for stamp here to avoid a lot of unnecessary work
      if not checkStampOverlap(createdTask.premisesIndirection[0].target.s.stamp, createdTask.premisesIndirection[1].target.s.stamp):
        ctx.tupleEventBoxAndQueueTaskBox[atLevel].queueBox.queue.add(createdTask) # add task to queue directly   HACKYYY!!!

        block:
          let s0: string = convSentenceToStr(createdTask.premisesIndirection[0].target.s)
          let s1: string = convSentenceToStr(createdTask.premisesIndirection[1].target.s)
          debug0(&"perceptionLayerPut(): add task for {s0}+{s1}")


  ctx.tupleEventBoxAndQueueTaskBox[atLevel].eventBox.items.add(createdItem)


# called when a set of events is perceived
# /param perceivedEvents events to 'bootstrap' the processing - events have to be sorted by occTime
proc perceptionLayerBootstrap(perceivedEvents: seq[EventRef],  ctx: ProcessingCtxRef) =
  
  # transfer events to box as "ProcessingEventBoxItem"
  for iEvent in perceivedEvents:
    var createdItem: ProcessingEventBoxItemRef = ProcessingEventBoxItemRef(target:iEvent)
    ctx.tupleEventBoxAndQueueTaskBox[0].eventBox.items.add(createdItem)
  
  # generate tasks to primaryly build sequences between last events
  block:
    for iLen in 2..3: # iterate over lengths of to be built sequence
      if perceivedEvents.len >= iLen:
        for iIdxBegin in 0..perceivedEvents.len-iLen:
          
          # compose premises of task
          var createdTask: ProcessingQueuedTaskRef = ProcessingQueuedTaskRef(premisesIndirection: @[])
          
          for iIdx in iIdxBegin..iIdxBegin+iLen-1:
            createdTask.premisesIndirection.add(ctx.tupleEventBoxAndQueueTaskBox[0].eventBox.items[iIdx])

          ctx.tupleEventBoxAndQueueTaskBox[0].queueBox.queue.add(createdTask) # add task to queue directly   HACKYYY!!!

  # generate single premise tasks
  block:
    for iIdx in 0..<ctx.tupleEventBoxAndQueueTaskBox[0].eventBox.items.len:
      var createdTask: ProcessingQueuedTaskRef = ProcessingQueuedTaskRef(premisesIndirection: @[])
      createdTask.premisesIndirection.add(ctx.tupleEventBoxAndQueueTaskBox[0].eventBox.items[iIdx])

      ctx.tupleEventBoxAndQueueTaskBox[0].queueBox.queue.add(createdTask) # add task to queue directly   HACKYYY!!!


  # generate tasks by pairs of closest events next to each other
  # TODO LOW

  # generate tasks by pairs of events
  # TODO LOW




type
  PerceptionLayerCtxRef* = ref PerceptionLayerCtx
  PerceptionLayerCtx* = object
    
    # selected op event and event after op events which are used to build conclusions

    selOpEvent*: EventObj
    selEventAfterOpEvent*: EventObj

    mem: MemObj



# internal react callback for the system_event when a derivation took place with a conclusion in the perceptionLayer
proc perceptionLayerQQreactCallbackQQderived(inEvent: EventRef, ctx: PerceptionLayerCtxRef) =
  debug0(&"perceptionLayer: derived conlusion event={convSentenceToStr(inEvent.s)}")
  
  

  # combine this event with other events of the op and the event after the op, then inform system about event of that
  
  
  var opEvent: EventObj = ctx.selOpEvent
  var selEventAfterOpEvent: EventObj = ctx.selEventAfterOpEvent # selected event for derivation after the op event

  if inEvent.occTime != opEvent.occTime: # it doesn't make any sense to build the sequence if occTime is the same
    var seqEvent: EventObj
    block:
      let conclTuple: ref tuple[term: TermObj, tv: Tv] = ruleNal7BuildSeq(inEvent.s.term, inEvent.s.tv, opEvent.s.term, opEvent.s.tv)
      var conclStamp: seq[int64] = merge(inEvent.s.stamp, opEvent.s.stamp, STAMPMAXLEN)

      let conclSentence: SentenceObj = SentenceObj(term:conclTuple.term, tv:conclTuple.tv, punct:judgement, stamp:conclStamp, originContingency:nil)
      
      seqEvent = EventObj(s:conclSentence, occTime:opEvent.occTime)

      seqEvent.s.term = termFoldSeq(seqEvent.s.term) # fold sequence


    # combine the 'seqEvent' with 'selEventAfterOpEvent'
    if seqEvent.occTime != selEventAfterOpEvent.occTime:

      var conclEvent: EventObj
      block:
        let conclTuple: ref tuple[term: TermObj, tv: Tv] = ruleNal7BuildPredImpl(seqEvent.s.term, seqEvent.s.tv, selEventAfterOpEvent.s.term, selEventAfterOpEvent.s.tv)
        var conclStamp: seq[int64] = merge(seqEvent.s.stamp, selEventAfterOpEvent.s.stamp, STAMPMAXLEN)

        let conclSentence: SentenceObj = SentenceObj(term:conclTuple.term, tv:conclTuple.tv, punct:judgement, stamp:conclStamp, originContingency:nil)
        conclEvent = EventObj(s:conclSentence, occTime:selEventAfterOpEvent.occTime)

        # * inform system about derived conclusion (put into memory but don't perceive it!)
        debug0(&"perceptionLayer derived |- {convSentenceToStr(conclEvent.s)}")
        globalNarInstance.conclCallback(conclEvent.s) # TODO< call callback for derived event! >
        putInput(ctx.mem, conclEvent.s, true) # store as belief
        
  




# entry for control of inference
proc perceptionLayerControlEntry(ctx: ProcessingCtxRef, ctx2: PerceptionLayerCtxRef) =
  if not enPerceptionLayer:
    return # disabled

  debug0("perceptionLayerControlEntry(): ENTER")
  defer: debug0("perceptionLayerControlEntry(): EXIT")


  var selTupleEventBoxAndQueueBoxIdx: int = narRand.rand(0..ctx.tupleEventBoxAndQueueTaskBox.len-1)
  block:
    let rngVal: float = narRand.rand(0.0..1.0)
    if rngVal < 0.15:
      selTupleEventBoxAndQueueBoxIdx = 0
    if rngVal < 0.5:
      selTupleEventBoxAndQueueBoxIdx = 1
  

  # select queue from which we seltect the task to be processed
  var selQueue: ProcessingQueuedTasksBoxRef = ctx.tupleEventBoxAndQueueTaskBox[selTupleEventBoxAndQueueBoxIdx].queueBox

  # * take task out
  var selTask: ProcessingQueuedTaskRef = nil
  if selQueue.queue.len > 0:
    selTask = selQueue.queue[0]
    selQueue.queue = selQueue.queue[1..selQueue.queue.len-1]
  
  if selTask == nil:
    debug0("perceptionLayerControlEntry(): info: no task was selected")

    return # no task to process here, just return
  
  # * process
  let conclEvents: seq[EventRef] = perceptionLayerProcessQueuedTask(selTask)

  for iConclEvent in conclEvents:
    debug0(&"PL0: conclEvent={convSentenceToStr(iConclEvent.s)}")
  

  # * add new tasks to process newly derived conclusions with alread existing premises
  for iConclEvent in conclEvents:
    # create task at higher level to process the conclusion!
    perceptionLayerPut(iConclEvent, selTupleEventBoxAndQueueBoxIdx+1, ctx)

  # commented because already done by perceptionLayerPut()
  ## * put conclEvents into next eventBox
  #var selDestinationQueueBox = ctx.tupleEventBoxAndQueueTaskBox[selTupleEventBoxAndQueueBoxIdx+1].queueBox
  #
  #for iConclEvent in conclEvents:
  #  var createdItem: ProcessingEventBoxItemRef = ProcessingEventBoxItemRef(target:iConclEvent)
  #  ctx.tupleEventBoxAndQueueTaskBox[0].eventBox.items.add(createdItem)



  for iConclEvent in conclEvents:
    # call internal callback to inform system that we derived a event
    perceptionLayerQQreactCallbackQQderived(iConclEvent, ctx2)






var perceptionLayer0ProcessingCtx: ProcessingCtxRef
var perceptionLayer0Ctx: PerceptionLayerCtxRef


# perceive and process events with 'perceptionLayer0'
proc processPerceptionLayer0(mem: MemObj) =
  if not enPerceptionLayer:
    return # disabled

  if globalNarInstance.lastPerceivedEvent != globalNarInstance.perceptionLayer0lastPerceivedEvent:
    globalNarInstance.perceptionLayer0lastPerceivedEvent = globalNarInstance.lastPerceivedEvent
    
    # * we need to reset perception

    let perceivedEvents: seq[EventObj] = collectEventsInOccRange(globalNarInstance.currentTime-1000, globalNarInstance.currentTime)

    if perceivedEvents.len >= 3:
      for iEvent in perceivedEvents:
        echo &"D843 {convSentenceToStr(iEvent.s)} {iEvent.occTime}"
        


      let eventLastMinus0: EventObj = perceivedEvents[perceivedEvents.len-1-0]
      let eventLastMinus1: EventObj = perceivedEvents[perceivedEvents.len-1-1]
      
      
      echo &"D844 {convSentenceToStr(eventLastMinus1.s)} {eventLastMinus1.occTime}"

      if checkIsOp(eventLastMinus1.s.term): # only consider if op is followed by some other event!

        perceptionLayer0ProcessingCtx = perceptionLayerMake()

        perceptionLayer0Ctx = PerceptionLayerCtxRef()
        perceptionLayer0Ctx.mem = mem
        perceptionLayer0Ctx.selEventAfterOpEvent = eventLastMinus0
        perceptionLayer0Ctx.selOpEvent = eventLastMinus1

        var perceivedEventsBeforeOp: seq[EventRef]
        #perceivedEventsBeforeOp = perceivedEvents[0..perceivedEvents.len-1-2]

        # commented because TOTRY
        let h: seq[EventRef] = convEventObjToEventRefArr(perceivedEvents)
        let perceivedInnerEventsInfo = perceptionFindLastFrame(h)
        if perceivedInnerEventsInfo != nil:
          perceivedEventsBeforeOp = perceivedInnerEventsInfo.innerEvents
          # FIXME< limit number of perceived eventsBeforeOp by taking a subsequence from the end >

        perceptionLayerBootstrap(perceivedEventsBeforeOp,  perceptionLayer0ProcessingCtx)
  
  else: # last perceived event is the same
    # so we can continue with the inference of the other derived events
    discard

  # give compute resources to perception
  debug0(&"PP00 {perceptionLayer0ProcessingCtx != nil}")
  
  if perceptionLayer0ProcessingCtx != nil: # check for nil because it can be nil if it is not initalized
    perceptionLayerControlEntry(perceptionLayer0ProcessingCtx, perceptionLayer0Ctx)




























































# SECTION: perception1
# prototype code for sampling of seq for perception of seq as precondition
proc infSampleFromFifoAndDeriveSeq() =
  if not enPerception1:
    return # return because perception engine is disabled
  
  var vmCtx: Vm0CtxRef = vm0make()
  # * sample two events from FIFO and builds seq if possible
  vm0SampleFromFifo2(vmCtx, 0, 1) # sample from fifo two events into registers 0 and 1
  vm0SortByTime2(vmCtx, 0, 1) # sort them
  vm0TryBuildSeq(vmCtx, 0, 1, 2) # build seq into register 2
  vm0TryFoldSeq(vmCtx, 2, 2) # fold - not necessary here at this point but still done to prevent bugs of future changes

  let conclEvent: EventRef = vm0Ret(vmCtx, 2)
  if conclEvent != nil:
    debug0(&"D45 derived: {convEventToStr(conclEvent)}")

    # TODO LOW< call callback for derived event! >
    globalNarInstance.conclCallback(conclEvent.s)

    # add to recently derived events
    sampledSetDsPut(globalNarInstance.narDerivedEventsSampledSetLevel1, conclEvent)

    # add to queue
    var task: Perception1TaskRef = Perception1TaskRef(prioCached:0.999, v: conclEvent)
    task.prioCached = 0.999 # TODO< implement computation of task priority! >
    taskset0Insert(globalNarInstance.tasksetPerception1, task)


type InfPremiseSrcEnum* = enum
  perceptionPq, # take premise from "tasksetPerception1" PQ
  sampleFromSampledSet # take premise from "narDerivedEventsSampledSetLevel1" sampled set



# SECTION: perception1
# * take task from perception1 taskset or sampled set
# * combine it with last event to hopefully build (a, ^op).:|:
proc infTakeAndCombineWithLastEvent(src: InfPremiseSrcEnum) =
  if not enPerception1:
    return # return because perception engine is disabled


  var vmCtx: Vm0CtxRef = vm0make()
  case src
  of perceptionPq:
    var selTask: Perception1TaskRef = taskset0TryPopTop(globalNarInstance.tasksetPerception1)
    if selTask == nil:
      return
    vm0Store(vmCtx, 0, selTask.v)
  of sampleFromSampledSet:
    var item: EventRef = sampledSetDsSample(globalNarInstance.narDerivedEventsSampledSetLevel1)
    if item == nil:
      return
    vm0Store(vmCtx, 0, item)
    
  vm0SelLastFromFifo(vmCtx, 1) # select last event from FIFO and store into register 1
  vm0SortByTime2(vmCtx, 0, 1) # sort them
  vm0TryBuildSeq(vmCtx, 0, 1, 2) # build seq into register 2
  vm0TryFoldSeq(vmCtx, 2, 2) # fold - is necessary because premise can be seq itself

  # put seq back into sampled set
  # ASK< should the sampled set be decided by the length of the seq???, this looks like a good idea >
  block:
    if true:
      let conclEvent: EventRef = vm0Ret(vmCtx, 2)
      if conclEvent != nil:
        debug0(&"D45 derived: {convEventToStr(conclEvent)}")

        # TODO LOW< call callback for derived event! >
        globalNarInstance.conclCallback(conclEvent.s)

        # add to recently derived events
        sampledSetDsPut(globalNarInstance.narDerivedEventsSampledSetLevel1, conclEvent)


  
  # commented because it should put it into another sampledSet!
  #block:
  #  let conclEvent: EventRef = vm0Ret(vmCtx, 2)
  #  if conclEvent != nil:
  #    debug0(&"D46 derived: {convEventToStr(conclEvent)}")
  #
  #    # TODO LOW< call callback for derived event! >
  #    globalNarInstance.conclCallback(conclEvent.s)
  #
  #    # add to recently derived events
  #    sampledSetDsPut(narDerivedEventsSampledSetLevel1b, conclEvent)
  #
  #    # add to queue
  #    #var task: Perception1TaskRef = Perception1TaskRef(prioCached:0.999, v: conclEvent)
  #    #task.prioCached = 0.999 # TODO< implement computation of task priority! >
  #    #taskset0Insert(tasksetPerception1, task)

  vm0TryBuildPredImpl(vmCtx, 0, 1, 3) # build predImpl into register 2
  block:
    let conclEvent: EventRef = vm0Ret(vmCtx, 3)
    if conclEvent != nil:
      debug0(&"D47 derived: {convEventToStr(conclEvent)}")
  
      # TODO LOW< call callback for derived event! >
      globalNarInstance.conclCallback(conclEvent.s)
  
      # add to beliefs
      putInput(globalNarInstance.mem, conclEvent.s, true)


# TODO< do the same with sampling! >












  









# PUBLIC interface
# gives compute resource to procedural reasoning
proc proceduralStep*() =
  # * perception
  processPerceptionLayer0(globalNarInstance.mem)

  # * perception
  infSampleFromFifoAndDeriveSeq()
  infTakeAndCombineWithLastEvent(perceptionPq)
  infTakeAndCombineWithLastEvent(sampleFromSampledSet) # EXPERIMENTAL


  # * goal derivation
  # commented because we dont do sampling
  #if true:
  #  sampleGoalAndDerive(mem, goalMem, opRegistry)
  pickGoalFromQueueAndDerive(globalNarInstance.mem, globalNarInstance.goalMem, globalNarInstance.opRegistry)

  # (goal system)
  #sampleAndExecOp(opRegistry) # commented because we don't do sampling


  # * perception
  proceduralSampleAndBuildContigency(globalNarInstance.mem)

  #selectJudgementEventAndDerive(globalNarInstance.mem, globalNarInstance.goalMem) # commented because we don't do this seperatly anymore
  
  # * house keeping
  proceduralKeepUnderAikrCollector() # GC
  anticipationMaintain() # anticipation+GC



# PUBLIC interface
# procedural: input a event which is perceived at the current time
# /param mem non-goal memory
proc proceduralInputPerceiveAtCurrentTime*(s:SentenceObj, mem: MemObj) =
  var event0:EventObj = EventObj(s:s, occTime:globalNarInstance.currentTime)

  globalNarInstance.lastPerceivedEvent = event0 # set this event as last perceived event

  procEligableEventJudgements.add(event0)


  echo(&"proceduralInputPerceiveAtCurrentTime(): arg={convSentenceToStr(s)}")


  anticipationObserve(event0.s.term) # force anticipation to "perceive" it

  discard """
  block: # try to match it for NLU rule to convert it to NAL-2 relation if possible
    let r1Concl: TermObj = r1LeftToRight(event0.s.term)
    if r1Concl != nil:
      
      # store belief etc.
      let s: SentenceObj = SentenceObj(term:r1Concl, punct:s.punct, stamp:s.stamp, tv:s.tv)

      putInput(mem, s, false)
  """


  block: # add event to "eventsByOccTime"
    if event0.occTime in globalNarInstance.eventsByOccTime:
      globalNarInstance.eventsByOccTime[event0.occTime].add(event0)
      return
    
    # not in table if we are here
    globalNarInstance.eventsByOccTime[event0.occTime] = @[event0]
  




# PUBLIC interface
proc proceduralAdvanceTime*(dt:int64) =
  if dt<0:
    return
  globalNarInstance.currentTime+=dt






# PUBLIC interface
# used for debugging
proc proceduralShowAllBeliefs*(memoryTypeTxt: string) =
  echo(&"concepts of {memoryTypeTxt}:")
  for iConceptName in globalNarInstance.mem.conceptsByName.keys:
    let iConcept: ConceptObj = globalNarInstance.mem.conceptsByName[iConceptName]
    echo(&"concept name={convTermToStr(iConcept.name)}")
    for iBelief in iConcept.content.content:
      echo(&"   content={convSentenceToStr(iBelief)}")
      for iPredImplLink in iBelief.predImplLinks:
        echo(&"      link to term={convTermToStr(iPredImplLink.target)}")

    for iBelief in iConcept.contentProcedural.content:
      echo(&"   procContent={convSentenceToStr(iBelief)}")
      for iPredImplLink in iBelief.predImplLinks:
        echo(&"      link to term={convTermToStr(iPredImplLink.target)}")

  echo("")


# PUBLIC interface
proc narInit*() =



  var ops0 = initTable[string, RegisteredOpRef]()
  let opRegistry: OpRegistryObj = OpRegistryObj(ops:ops0)

  globalNarInstance = NarCtx(conclCallback: nullConclhandler, invokeOpCallback: nullOpHandler, opRegistry: opRegistry, currentTime:0)
  globalNarInstance.decisionThreshold = 0.501

  block:
    var opInfOp: RegisteredOpRef = new (RegisteredOpRef)
    opInfOp.callback = infOpable
    opInfOp.supportsLongCall = false # is not a long callable op

    globalNarInstance.opRegistry.ops["^infOp0"] = opInfOp

  globalNarInstance.eventsByOccTime = initTable[int64, seq[EventObj]]()

  let capacityConcepts: int = 300
  let mem = MemObj(conceptsByName: initTable[TermObj, ConceptObj](), capacityConcepts:capacityConcepts)
  globalNarInstance.mem = mem

  goaldrivenCtrlCtx.mem = mem


  globalNarInstance.goalMem = MemObj(conceptsByName: initTable[TermObj, ConceptObj](), capacityConcepts:capacityConcepts)

  globalNarInstance.allGoalsByDepth = @[]
  globalNarInstance.allGoalsByDepth.add(GoalsWithSameDepthObj())


  let maxLen: int = 20
  globalNarInstance.narDerivedEventsSampledSetLevel1 = sampledSetDsMake(maxLen)

  # override compare function of the sampled set because we need to consider the recency of the event too
  proc cmpFn(a: EventRef, b: EventRef): int =
    let decayFactor: float64 = 0.001
    let aVal: float64 = calcExp(a.s.tv) * exp(-float64(globalNarInstance.currentTime - a.occTime) * decayFactor)
    let bVal: float64 = calcExp(b.s.tv) * exp(-float64(globalNarInstance.currentTime - b.occTime) * decayFactor)
    return cmp(aVal, bVal)
  globalNarInstance.narDerivedEventsSampledSetLevel1.cmpFn = cmpFn



  globalNarInstance.tasksetPerception1 = new(Taskset0[Perception1TaskRef])
  globalNarInstance.tasksetPerception1.maxLen = 50
  globalNarInstance.tasksetPerception1.set0 = @[]
  proc task0cmpFn(a: Perception1TaskRef, b: Perception1TaskRef): int =
    return cmp(a.prioCached, b.prioCached)
  globalNarInstance.tasksetPerception1.cmpFn = task0cmpFn

  



discard """
# PUBLIC interface
proc narReset*() =
  
  goalTaskset.set0 = @[]


  procEligableEventJudgements = @[]

  globalNarInstance.mem.reset()
  

  globalNarInstance.eventsByOccTime = initTable[int64, seq[EventObj]]()

  globalNarInstance.currentTime = 0

  globalNarInstance.allGoalsByDepth = @[]
  globalNarInstance.allGoalsByDepth.add(GoalsWithSameDepthObj())
"""


import std/strutils

# /return
proc parseNarsese*(narseseIn: string): tuple[term: TermObj, success: bool, punct: PunctEnum, isEvent: bool] =
  var narsese: string = narseseIn

  if narsese.len == 0:
    return (term:nil, success:false, punct:judgement, isEvent: false)

  var isEvent: bool = false
  if narsese.endsWith(":|:"):
    isEvent = true
    narsese = narsese[0..narsese.len-1-3] # cut away
  
  removeSuffix(narsese, ' ') 


  #echo("here52525")
  #echo(narsese)

  if not (narsese[narsese.len-1] in ['.','?','!']):
    # '.' is optional, add it
    narsese = &"{narsese}."

  # try to parse as narsese
  if narsese.len == 0:
    return (term:nil, success:false, punct:judgement, isEvent: false)

  var punct = judgement
  if narsese[narsese.len-1] == '.': # judgement
    punct = judgement
    narsese = narsese[0..narsese.len-1-1]
  elif narsese[narsese.len-1] == '!': # goal
    punct = goal
    narsese = narsese[0..narsese.len-1-1]  
  elif narsese[narsese.len-1] == '?': # question
    punct = question
    narsese = narsese[0..narsese.len-1-1]  
  else: # nothing matched!
    return (term:nil, success:false, punct:judgement, isEvent: false)
  
  
  let tokens: seq[Token0Obj] = tokenize(narsese)
  parserCalcDepthOfTokens(tokens)
  if false:
    dbgTokens(tokens)
  let term: TermObj = parse(tokens)
  
  return (term: term, success: term != nil, punct: punct, isEvent: isEvent)

# PUBLIC interface
proc parseNarInputAndPut*(narseseIn: string) =
  
  let resParse = parseNarsese(narseseIn)
  if not resParse.success:
    return # ASK< maybe we should throw error? >


  echo fmt"in:term={convTermToStr(resParse.term)}"
  echo &"in:punct={resParse.punct}"

  var inSentence: ref Sentence = new (Sentence)
  inSentence.term = resParse.term
  inSentence.punct = resParse.punct
  inSentence.tv = makeTv(1.0, 0.92)
  inSentence.stamp = makeStamp()
  
  if resParse.isEvent:
    if inSentence.punct == judgement:
      proceduralInputPerceiveAtCurrentTime(inSentence, globalNarInstance.mem)
    elif inSentence.punct == goal:
      var inEvent: EventObj = EventObj(s:inSentence)
      goalSystemPutGoal(inEvent, globalNarInstance.goalMem, false)
  else:
    putInput(globalNarInstance.mem, inSentence, false)





































# op for testing
func dummyOpA(args: seq[TermObj]) =
  debug0("dummyOpA() called!")

# NAL-9 op to call ops and to inject a event as perceived event after that
proc opLibNal9ExecAndInj*(args: seq[TermObj]) =
  debug0("^opLibNal9ExecAndInj(): ENTER")
  defer: debug0("^opLibNal9ExecAndInj(): EXIT")

  
  
  let arg0: TermObj = args[0] # {SELF} - ignore
  let arg1: TermObj = args[1] # term or sequence of terms of ops to get executed
  let arg2: TermObj = args[2] # event to get injected

  block:
    var opsToCallTerms: seq[TermObj] = @[]

    case arg1.type0
      of sequence: # multiple ops to call
        opsToCallTerms = arg1.items0
      else:
        opsToCallTerms = @[arg1]
    
    # execute ops
    for iOpTerm in opsToCallTerms:
      let parseOpRes: ParseOpRes1 = tryParseOp(iOpTerm)
      case parseOpRes.resType
      of ParseOpRes:
        # invoke op
        debug0(&"invoke op ... term={convTermToStr(iOpTerm)}")
        globalNarInstance.opRegistry.ops[parseOpRes.name].callback(parseOpRes.args)
        debug0(&"...done", 4)
        
      of NoneParseRes:
        # ignore
        discard


  # * inject event (perceive at current time)
  block:
    let perceivedSentence: SentenceObj = new (SentenceObj)
    #    var inSentence: ref Sentence = new (Sentence)
    perceivedSentence.term = arg2
    perceivedSentence.punct = judgement
    perceivedSentence.tv = makeTv(1.0, 0.92)
    perceivedSentence.stamp = makeStamp()
    proceduralInputPerceiveAtCurrentTime(perceivedSentence, globalNarInstance.mem)















############################
# init global

block:
  narInit()
  





















# commented because not used
discard """

# manual test
proc manualTestqqPerceptionLayer0() =
  var ctx: ProcessingCtxRef = perceptionLayerMake()

  var ctx2: PerceptionLayerCtxRef
  ctx2 = PerceptionLayerCtxRef()
  ctx2.mem = MemObj(concepts: @[])
  




  var perceivedEvents: seq[EventObj] = @[]




  block:
    var e0: EventObj
    let resParse = parseNarsese("op. :|:")
    if not resParse.success:
      return # ASK< maybe we should throw error? >

    var inSentence: ref Sentence = new (Sentence)
    inSentence.term = resParse.term
    inSentence.punct = resParse.punct
    inSentence.tv = makeTv(1.0, 0.92)
    inSentence.stamp = makeStamp()
    
    if resParse.isEvent:
      var inEvent: EventObj = EventObj(s:inSentence)
      inEvent.occTime = 20
      ctx2.selOpEvent = inEvent
    
  block:
    var e0: EventObj
    let resParse = parseNarsese("z. :|:")
    if not resParse.success:
      return # ASK< maybe we should throw error? >

    var inSentence: ref Sentence = new (Sentence)
    inSentence.term = resParse.term
    inSentence.punct = resParse.punct
    inSentence.tv = makeTv(1.0, 0.92)
    inSentence.stamp = makeStamp()
    
    if resParse.isEvent:
      var inEvent: EventObj = EventObj(s:inSentence)
      inEvent.occTime = 21
      ctx2.selEventAfterOpEvent = inEvent









  block:
    var e0: EventObj
    let resParse = parseNarsese("a. :|:")
    if not resParse.success:
      return # ASK< maybe we should throw error? >


    echo fmt"in:term:{convTermToStr(resParse.term)}"

    var inSentence: ref Sentence = new (Sentence)
    inSentence.term = resParse.term
    inSentence.punct = resParse.punct
    inSentence.tv = makeTv(1.0, 0.92)
    inSentence.stamp = makeStamp()
    
    if resParse.isEvent:
      var inEvent: EventObj = EventObj(s:inSentence)
      e0 = inEvent
    
    perceivedEvents.add(e0)

  block:
    var e0: EventObj
    let resParse = parseNarsese("b. :|:")
    if not resParse.success:
      return # ASK< maybe we should throw error? >


    echo fmt"in:term:{convTermToStr(resParse.term)}"

    var inSentence: ref Sentence = new (Sentence)
    inSentence.term = resParse.term
    inSentence.punct = resParse.punct
    inSentence.tv = makeTv(1.0, 0.92)
    inSentence.stamp = makeStamp()
    
    if resParse.isEvent:
      var inEvent: EventObj = EventObj(s:inSentence)
      e0 = inEvent
    
    e0.occTime = 5
    
    perceivedEvents.add(e0)



  block:
    var e0: EventObj
    let resParse = parseNarsese("c. :|:")
    if not resParse.success:
      return # ASK< maybe we should throw error? >


    echo fmt"in:term:{convTermToStr(resParse.term)}"

    var inSentence: ref Sentence = new (Sentence)
    inSentence.term = resParse.term
    inSentence.punct = resParse.punct
    inSentence.tv = makeTv(1.0, 0.92)
    inSentence.stamp = makeStamp()
    
    if resParse.isEvent:
      var inEvent: EventObj = EventObj(s:inSentence)
      e0 = inEvent
    
    e0.occTime = 10
    
    perceivedEvents.add(e0)



  for iEvent in perceivedEvents:
    debug0(&"{convSentenceToStr(iEvent.s)}")


  perceptionLayerBootstrap(perceivedEvents,  ctx)
  
  # give compute resources to perception
  perceptionLayerControlEntry(ctx, ctx2)









if false: # manual test for 'perception layer'
  manualTestqqPerceptionLayer0()
  quit(0) # force exit of program
"""














# TODO MEDIUM< implement sampling of events to create conclusions to put into memory >




# DONE TEST< derive goal from goal and seq >











# DONE HIGH< implement+use predictiveImplication links >
# SUB DONE < implement inference using predictiveImplication links >
# SUB DONE < test predictiveImplication links! >




# DONE TESTING< derivation of (A,B)=/>C  , we just need to insert events into the array >




# DONE MID decision making+op exec
# SUB DONE      < implement/check calling of op >
# SUB DONE      < add op to ops in test >
# SUB DONE      < implement priority queue for goals (because it's probably more efficient than sampling) >
# SUB DONE      < implement handling for realizing goal that is called in the goal processing from the queue! >
# SUB DONE      < test it if it calls the op >


# DONE MID implement projection layer which doesnt do anything



# DONE MID implement anticipation
# SUB DONE      < implement set of anticipated events in flight >
# SUB DONE      < implement   call   anticipationPutAndNegConfirm()   when calling op >
# SUB DONE      < implement   call   anticipationObserve()  pos-confirm logic when event happened >






# DONE 4.1.2023: implemented basic adding of =/> belief




# DONE MID implement question variable unification and use it to answer questions!





# DONE MID parser: implement uvar in parser
# TODO MID inference: use term unifier termTryUnifyAndAssign2() in procedural stuff where useful



# TODO LOW perception implement composing of sequence of more than 2 items by composing a sequence with a non-sequence



# HALFDONE high: implement unification in   ruleNal7SeqDetach()








# DONE LOW add arguments to ops
# ex:
#   ^choose([l])
#   ^choose([r])

# DONE LOW< fix wrong parsing of single term with dot >
#    example: 
#    "b. :|:" is parsed incorrectly
#    "b.:|:"  is parsed correctly



# TODO HIGH use ruleMutualEntailmentA()
# SUB TODO    implement declarative procedural inference engine with a own queue
# SUB TODO    add call to ruleMutualEntailmentA()
# SUB TODO    add task to declarative procedural inference when ever it was derived in perception



# TODO LOW (for language channel) - add explicitCnt evidence count for language channel for Patrick's way to count evidence





# HALFDONE HIGH (RFT relation event) - build RFT relation event and inject it when op was called
#  DONE< derive RFT relation as event after op was invoked >
#  TODO< (if not already implemented) implement detachment rule of seq for seq of more than 2 items  >
#  TODO< test building of RFT relation as event when the contingency with the seq of len 3 is used!!! >
#  TODO perception layer< implement priority queue and inject task which points at event in the inject function of the "perception layer" >



# DONE MID deriver < perceptionLayer: add code to add tasks with one premise! >
#      * DONE MID testing nal : check if derivations are done from product to image and back





# TODO deriver< use narDerivedEventsSampledSetLevel1 for deriving predImpl with op! >
# DONE deriver< use narDerivedEventsSampledSetLevel1 for precondition in decision making! >






# DONE HIGH deriver< RFT: use convSeqToRel(t: TermObj) in decision making after removing the op of the executed decision! >
#                 DONE< fix bug!     FIXME: wasExecutedInternalAction(): originContingency is nil! RETURN!    >
#                 DONE< make sure that percpetion of decision making interacts in a good way with the perception deriver and that it considers the active events >






# HALFDONE interface< integrate/use moduleNlp3 in shell with >> prefix   >


# FIXME BUG deriver decision making < substitute variables in conclusion !!!!! >









# DONE 15.1.2023  inference: add A., A==>B. |- B. rule  and call rule in deriver
#      DONE< test it with nal test file! >







