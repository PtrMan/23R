# run with
#    nim compile --run -d:release protoBp0.nim 

import std/strformat
import std/random
import math

proc adAdd*(ar: float64, ad: float64, br: float64, bd: float64): tuple[r:float64, d:float64] =
  return (r:ar+br,d:ad+bd)

proc adSub*(ar: float64, ad: float64, br: float64, bd: float64): tuple[r:float64, d:float64] =
  return (r:ar-br,d:ad-bd)

proc adMul*(ar: float64, ad: float64, br: float64, bd: float64): tuple[r:float64, d:float64] =
  return (r:ar*br,d:ad*br+bd*ar)

proc adDiv*(ar: float64, ad: float64, br: float64, bd: float64): tuple[r:float64, d:float64] =
  return (r:ar/br,d:(ad*br+bd*ar) / (br*br))


proc adSqrt*(r: float64, d: float64): tuple[r:float64, d:float64] =
  # DEBUG
  if r < 0.0 or r != r:
    echo(&"invalid input to adSqrt() r={r}")
    quit(1)
    
  if d != d:
    echo(&"invalid input to adSqrt() d={d}")
    quit(1)

  let resR: float64 = sqrt(r)
  let resD: float64 = d*0.5*pow(max(r, 1e-10), 0.5-1.0)

  # DEBUG
  if resD != resD:
    echo(&"result D adSqrt() is NaN")
    echo(&"in  r={r} d={d}")
    quit(1)
  
  
  return (r:resR, d:resD)




# activation function
proc adActRelu(r: float64, d: float64): tuple[r:float64, d:float64] =
  if r > 0.0:
    return (r:r,d:d)
  return (r:0.0,d:0.0)


type
  Unit*[s: static int] = object
    r*: array[s, float64]
    d*: array[s, float64]
    
    biasR*: float64
    biasD*: float64


# generator for training data
type DatGenerator* = object
  dat*: seq[tuple[inArrays:seq[seq[float64]], target:seq[float64], gradientStrength: float64]] # gradient strength: how strong is the gradient? usually 1.0 for :normal: supervised learning, equal to reward for policy gradient training
  rng*: Rand

proc retSample(this: var DatGenerator): tuple[inArrays:seq[seq[float64]], target:seq[float64], gradientStrength: float64] =
  let idx=this.rng.rand(this.dat.len-1)
  return this.dat[idx]





type
  NnOptimizerConfig* = object
    searchEpochs*: int64 # number of epochs for search
    lr*: float32 # learning rate


type CalcErrorPtr = (proc(nnOuts: seq[seq[tuple[r:float64,d:float64]]], target: seq[float64], selTargetIdx: int):tuple[r:float64,d:float64])

type
  Layer*[s: static int] = object
    units*: seq[Unit[s]]


# forward pass in NN
proc nnForward*[layer0StimulusWidth: static int, nUnitsPerLayer: static seq[int], nUnitsPerLayer0: static int](layer0: Layer[layer0StimulusWidth], layer1: Layer[nUnitsPerLayer0], inArray: seq[float64]): seq[tuple[r:float64,d:float64]] =
  proc calcUnitsOut[unitsPerLayer: static int, s: static int](layerIdx: int, units: seq[Unit[s]], br: var array[s, float64], bd: var array[s, float64], res0R: var array[unitsPerLayer, float64], res0D: var array[unitsPerLayer, float64]) =
    
    for iUnitIdx in 0..units.len-1:
      
      # implementation of dot-product
      var sumR: float64 = 0.0
      var sumD: float64 = 0.0
      
      for iidx in 0..units[iUnitIdx].r.len-1:
        let r0 = adMul(units[iUnitIdx].r[iidx], units[iUnitIdx].d[iidx], br[iidx], bd[iidx])
        #echo &"{r0.r} {r0.d}" # DBG
        
        let r1 = adAdd(sumR, sumD, r0.r, r0.d)
        sumR = r1.r
        sumD = r1.d
    
      # add bias  
      block:
        let r1 = adAdd(sumR, sumD, units[iUnitIdx].biasR, units[iUnitIdx].biasD)
        sumR = r1.r
        sumD = r1.d
      
      # compute activation function
      var actFnRes: tuple[r:float64,d:float64] = (sumR,sumD) # set to id
      if layerIdx == 0:
        actFnRes = adActRelu(sumR, sumD)


      res0R[iUnitIdx] = actFnRes.r
      res0D[iUnitIdx] = actFnRes.d

    
      #echo &"{sumR} {sumD}"
        

  # set stimulus
  var br: array[layer0StimulusWidth, float64]
  var bd: array[layer0StimulusWidth, float64]

  for iidx in 0..br.len-1:
    br[iidx] = inArray[iidx]


  # array for results of units
  var res0R: array[nUnitsPerLayer[0], float64]
  var res0D: array[nUnitsPerLayer[0], float64]
  calcUnitsOut(0, layer0.units, br,bd,  res0R,res0D)

  var res1R: array[nUnitsPerLayer[1], float64]
  var res1D: array[nUnitsPerLayer[1], float64]
  calcUnitsOut(1, layer1.units, res0R,res0D, res1R,res1D)
  

  # translate output of NN to seq
  var nnOut: seq[tuple[r:float64,d:float64]] = @[]
  for iidx in 0..res1R.len-1:
    nnOut.add((res1R[iidx],res1D[iidx]))
  
  return nnOut



type
  TrainingConfig* = object
    ticksOutProgress*: int # numer of ticks to debug next training progress to terminal
    latestWeights: seq[float64] # gets filled with the latest weights which were learned


# const layer0StimulusWidth: int = 5*(19) # count of stimulus real values
# nUnitsLayer0 = 5 #  how many units in layer 0

# optimization algorithm for training
proc z*[
  layer0StimulusWidth: static int,
  nUnitsPerLayer: static seq[int],
  targetLen: static int
  ](gen: var DatGenerator, calcErrorFn: CalcErrorPtr, searchConfig: NnOptimizerConfig, trainingConfig: var TrainingConfig) =
  
  var r = initRand(234)

  echo("start training...")

  var layer0: Layer[layer0StimulusWidth]
  var layer1: Layer[nUnitsPerLayer[0]]

  
  #var units: seq[Unit[layer0StimulusWidth]] = @[]
  

  for i in 0..nUnitsPerLayer[0]-1:
    var u0: Unit[layer0StimulusWidth] = Unit[layer0StimulusWidth]()
    u0.biasR = (1.0-r.rand(2.0))*0.8
    for iidx in 0..u0.r.len-1:
      u0.r[iidx] = (1.0-r.rand(2.0))*0.8
    
    layer0.units.add(u0)

  for i in 0..nUnitsPerLayer[1]-1:
    var u0: Unit[nUnitsPerLayer[0]] = Unit[nUnitsPerLayer[0]]()
    u0.biasR = (1.0-r.rand(2.0))*0.8
    for iidx in 0..u0.r.len-1:
      u0.r[iidx] = (1.0-r.rand(2.0))*0.8
    
    layer1.units.add(u0)

  
  var avgMse: float64 = 1.0
  
  for it in 0..layer0StimulusWidth*nUnitsPerLayer[0]*gen.dat.len*searchConfig.searchEpochs-1:
    let selSample = gen.retSample()

    # target to optimize for
    var target: array[targetLen, float64]
    for iidx in 0..targetLen-1:
        target[iidx] = selSample.target[iidx]




    let selLayerIdx: int = r.rand(2-1)

    var selUnitIdx: int
    if selLayerIdx == 0:
      selUnitIdx = r.rand(layer0.units.len-1)
    elif selLayerIdx == 1:
      selUnitIdx = r.rand(layer1.units.len-1)
    
    # -1 indicates adaption of bias
    var selWeightIdx: int
    if selLayerIdx == 0:
      selWeightIdx = r.rand(layer0StimulusWidth-1 + 1)-1
    elif selLayerIdx == 1:
      selWeightIdx = r.rand(layer0.units.len-1 + 1)-1

    # index of target to omptimize for
    let selTargetIdx: int = r.rand(target.len-1)






    if selWeightIdx == -1:
      if selLayerIdx == 0:
        layer0.units[selUnitIdx].biasD = selSample.gradientStrength
      elif selLayerIdx == 1:
        layer1.units[selUnitIdx].biasD = selSample.gradientStrength
      
    else:
      if selLayerIdx == 0:
        layer0.units[selUnitIdx].d[selWeightIdx] = selSample.gradientStrength
      elif selLayerIdx == 1:
        layer1.units[selUnitIdx].d[selWeightIdx] = selSample.gradientStrength
    

    
    var nnOuts: seq[seq[tuple[r:float64,d:float64]]] = @[]
    
    
    for iParNnIdx in 0..selSample.inArrays.len-1: # iterator to iterate over parallel instantiations of the same network with different stimulus but same weights
      

      # TODO REFACTORME< use the forward function! >
      
      proc calcUnitsOut[unitsPerLayer: static int, s: static int](layerIdx: int, units: seq[Unit[s]], br: var array[s, float64], bd: var array[s, float64], res0R: var array[unitsPerLayer, float64], res0D: var array[unitsPerLayer, float64]) =
        
        for iUnitIdx in 0..units.len-1:
          
          # implementation of dot-product
          var sumR: float64 = 0.0
          var sumD: float64 = 0.0
          
          for iidx in 0..units[iUnitIdx].r.len-1:
            let r0 = adMul(units[iUnitIdx].r[iidx], units[iUnitIdx].d[iidx], br[iidx], bd[iidx])
            #echo &"{r0.r} {r0.d}" # DBG
            
            let r1 = adAdd(sumR, sumD, r0.r, r0.d)
            sumR = r1.r
            sumD = r1.d
        
          # add bias  
          block:
            let r1 = adAdd(sumR, sumD, units[iUnitIdx].biasR, units[iUnitIdx].biasD)
            sumR = r1.r
            sumD = r1.d
          
          # compute activation function
          var actFnRes: tuple[r:float64,d:float64] = (sumR,sumD) # set to id
          if layerIdx == 0:
            actFnRes = adActRelu(sumR, sumD)


          res0R[iUnitIdx] = actFnRes.r
          res0D[iUnitIdx] = actFnRes.d

      
        #echo &"{sumR} {sumD}"
          

      # set stimulus
      var br: array[layer0StimulusWidth, float64]
      var bd: array[layer0StimulusWidth, float64]

      for iidx in 0..br.len-1:
        br[iidx] = selSample.inArrays[iParNnIdx][iidx]


      # array for results of units
      var res0R: array[nUnitsPerLayer[0], float64]
      var res0D: array[nUnitsPerLayer[0], float64]
      calcUnitsOut(0, layer0.units, br,bd,  res0R,res0D)

      var res1R: array[nUnitsPerLayer[1], float64]
      var res1D: array[nUnitsPerLayer[1], float64]
      calcUnitsOut(1, layer1.units, res0R,res0D, res1R,res1D)
      

      # translate output of NN to seq
      var nnOut: seq[tuple[r:float64,d:float64]] = @[]
      for iidx in 0..res1R.len-1:
        nnOut.add((res1R[iidx],res1D[iidx]))
      nnOuts.add(nnOut)


    # function to calculate error
    #
    # is in a function to allow for flexible computation with a mathematical function between the output of the network and the output of the function to be optimized for
    #proc calcError(nnOuts: seq[seq[float64]], target: seq[float64], selTargetIdx: int): float64 =
    #  return  Ad(r:target[selTargetIdx] - nnOuts[0][selTargetIdx], d:res0D[selTargetIdx]) # compute error

    
    

    var nnTarget: seq[float64] = @[]
    block:
      for iv in target:
        nnTarget.add(iv)

    var err1 = calcErrorFn(nnOuts, nnTarget,  selTargetIdx)

    # DEBUG
    if err1.r != err1.r: # encountered NaN
      echo("error - encountered NaN (err1.r)")
      quit(1)
    
    if err1.d != err1.d: # encountered NaN
      echo("error - encountered NaN (err1.d)")
      quit(1)


    if it == 0:
      avgMse = (err1.r*err1.r)

    if (it mod 1000) == 0 and selSample.gradientStrength > 0.0:
      let adaptFactor = 0.001
      avgMse = avgMse*(1.0-adaptFactor) + (err1.r*err1.r)*adaptFactor

    if (it mod trainingConfig.ticksOutProgress) == 0:
      echo &"avgMse={avgMse}\tmse={err1.r*err1.r}         errR[{selTargetIdx}]={err1.r}"

    
    if (it mod (20000*150)) == 0:
      echo "store..."

      var wb: seq[float64] = @[]
      
      for iUnit in layer0.units:
        wb.add(iUnit.biasR)
        for iv in iUnit.r:
          wb.add(iv)
      for iUnit in layer1.units:
        wb.add(iUnit.biasR)
        for iv in iUnit.r:
          wb.add(iv)
      
      echo(wb)

      trainingConfig.latestWeights = wb

    let deltaR: float = err1.r*err1.d*searchConfig.lr
    
    # DEBUG
    if deltaR != deltaR: # encountered NaN
      echo("error - encountered NaN (deltaR)")
      quit(1)

    if selWeightIdx == -1:
      if selLayerIdx == 0:
        layer0.units[selUnitIdx].biasR += deltaR
        layer0.units[selUnitIdx].biasD = 0.0
      elif selLayerIdx == 1:
        layer1.units[selUnitIdx].biasR += deltaR
        layer1.units[selUnitIdx].biasD = 0.0

    else:
      if selLayerIdx == 0:
        layer0.units[selUnitIdx].r[selWeightIdx] += deltaR
        layer0.units[selUnitIdx].d[selWeightIdx] = 0.0
      elif selLayerIdx == 1:
        layer1.units[selUnitIdx].r[selWeightIdx] += deltaR
        layer1.units[selUnitIdx].d[selWeightIdx] = 0.0







# TODO REFACTOR<move out of this file>
# generate random vector
proc vecGenRng*(rng: var Rand, len:int): seq[float64] =
    var temp0: seq[float64] = @[]
    for i in 1..len:
        temp0 = temp0 & @[(1.0-rng.rand(2.0))]
    return temp0
