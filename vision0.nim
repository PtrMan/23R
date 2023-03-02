#experimenting with matrix



import Matrix0
import math



# subpatch of matrix by rect
proc matrixSubpatch(m: Matrix0[64, 64, float64], dest: var Matrix0[64, 64, float64], rectX: int, rectY: int, rectW: int, rectH: int) =
  for iy in 0..rectH:
    for ix in 0..rectW:
      let idxX = ix+rectX
      let idxY = iy+rectY
      let val: float64 = m.atSafe(idxY, idxX, 0.0)
      dest.writeAtSafe(iy, ix, val)


import vec

type
  Prototype0*[s: static int] = object
    v*: array[s, float64]
    uniqueId*: int64

type
  Prototype0Obj*[s: static int] = ref Prototype0[s]



# prototype based classifier which uses a similarity callback
#
# prototypes are NOT necessarily stored as raw pixel values, can be anything preprocessed
type
  Classifier0*[s: static int] = object
    prototypes*: seq[Prototype0Obj[s]]

    classifierSimThreshold*: float64
    distMode*: int

    uniqueIdCounter: int64

proc createClassifier0*[s: static int](): Classifier0[s] =
  var res: Classifier0[s]
  res.prototypes = @[]
  return res

# classify by computing similarity of all prototypes
proc classify0*[s: static int](classifier: Classifier0, stimulus: array[s, float64]): tuple[sim: float64, bestProto: Prototype0Obj[s]] =
  var best: tuple[sim: float64, bestProto: Prototype0Obj[s]] = (-1.0, nil)
  for iProto in classifier.prototypes:
    var sim: float64 = -1.0
    if classifier.distMode == 0:
      sim = simCos(iProto.v, stimulus)
    elif classifier.distMode == 1:
      var dist = 0.0
      for iidx in 0..stimulus.len-1:
        let d = iProto.v[iidx]-stimulus[iidx]
        dist += (d*d)

      dist = sqrt(dist)
      echo &"classify0() dist={dist}"
      dist = min(dist, 1.0) # only allow distance of 1.0 (for maximum distance)
      sim = min(1.0 - dist, 1.0) # convert distance to similarity

    echo &"classify0() sim={sim}" # DBG

    if sim > best.sim:
      best = (sim, iProto)
  return best

# classify and add if below threshold
proc classify0AndAdd*[s: static int](classifier: var Classifier0, stimulus: array[s, float64]): Prototype0Obj[s] =
  let classifyResult = classifier.classify0(stimulus)

  echo(&"classify0AndAdd: cmp {classifyResult.sim} < {classifier.classifierSimThreshold}")
  #echo(&"classify0AndAdd: ")

  if classifyResult.sim < classifier.classifierSimThreshold:
    # we need to create a new class and add it
    echo("create new class because below threshold")

    var createdProto: Prototype0Obj[s] = new (Prototype0[s])
    createdProto.v = stimulus
    createdProto.uniqueId = classifier.uniqueIdCounter
    classifier.uniqueIdCounter = classifier.uniqueIdCounter+1
    classifier.prototypes.add(createdProto)

    # sort by priority
    # TODO

    # limit memory to n prototypes
    let nMaxPrototypes: int = 100
    if classifier.prototypes.len > nMaxPrototypes:
      classifier.prototypes = classifier.prototypes[0..nMaxPrototypes]
    
    return createdProto
  
  return classifyResult.bestProto



import std/strformat

import times

when isMainModule: # main
  var mz: Matrix0[64, 64, float64]


  var m0: Matrix0[64, 64, float64]
  matrixSubpatch(mz, m0, 0, 0, 32, 32) # compute subpatch of matrix

  var m1: Matrix0[64, 64, float64]
  matrixSubpatch(mz, m1, 0, 32, 32, 32) # compute subpatch of matrix

  proc convSubToArr(m: Matrix0[64, 64, float64]): array[32*32, float64] =
    var res: array[32*32, float64]
    for iy in 0..32-1:
      for ix in 0..32-1:
        res[ix + iy*32] = m.atUnsafe(iy, ix)
    return res


  # small experiment similar to the core of the comparison function for Roberts experiments
  block:
    let temp0Arr: array[32*32, float64] = convSubToArr(m0)
    let temp1Arr: array[32*32, float64] = convSubToArr(m1)

    var m0Arr: array[temp0Arr.len*2, float64]
    for iidx in 0..temp0Arr.len-1:
      m0Arr[iidx] = temp0Arr[iidx]
      m0Arr[temp0Arr.len+iidx] = 1.0-temp0Arr[iidx]

    var m1Arr: array[temp1Arr.len*2, float64]
    for iidx in 0..temp1Arr.len-1:
      m1Arr[iidx] = temp1Arr[iidx]
      m1Arr[temp1Arr.len+iidx] = 1.0-temp1Arr[iidx]

    let sim: float64 = simCos(m0Arr, m1Arr)

    echo(&"sim={sim}")




  echo("")
  echo("")
  echo("")
  echo("")
  echo("")

  var classifier0: Classifier0[32*32*2] = createClassifier0[32*32*2]()
  classifier0.classifierSimThreshold = 0.8

  


  let temp0Arr: array[32*32, float64] = convSubToArr(m0)

  var m0Arr: array[temp0Arr.len*2, float64]
  for iidx in 0..temp0Arr.len-1:
    m0Arr[iidx] = temp0Arr[iidx]
    m0Arr[temp0Arr.len+iidx] = 1.0-temp0Arr[iidx]


  # test to check if class is added
  block:
    classifier0.classify0AndAdd(m0Arr)



    let time = cpuTime()
    classifier0.classify0AndAdd(m0Arr)
    echo "Time taken: ", cpuTime() - time






