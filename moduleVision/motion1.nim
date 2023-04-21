import std/tables
import std/strformat
from std/math import sqrt, sgn

import motion0
import matrixArr
import vec2

func abs(v: int): int =
  if v<0:
    return -v
  return v


# this file implements a service to retrieve areas where proto-object may be located by analyzing the motion between images


type
  ChangedAreaObj* = ref ChangedArea
  ChangedArea* = object
    min*: Vec2[int]
    max*: Vec2[int]

proc areaAdd(self: ChangedAreaObj, p: Vec2[int]) =
  self.min.x = min(p.x, self.min.x)
  self.min.y = min(p.y, self.min.y)
  self.max.x = max(p.x, self.max.x)
  self.max.y = max(p.y, self.max.y)


# facade for motion matrix calculation, this is the entry point for motion calculation
proc calcMotionMatrix2*(am: MatrixArr[float64], bm: MatrixArr[float64]): MatrixArr[Vec2[int]] =
  return calcMotionMatrix(am, bm)


# helper
proc push[X](arr: var seq[X], v: X) =
  arr.add(v)


# helper
func scale(v: Vec2[float], s: float): Vec2[float] =
  return Vec2[float](x:v.x*s,y:v.y*s)
func add(a: Vec2[float], b: Vec2[float]): Vec2[float] =
  return Vec2[float](x:a.x+b.x,y:a.y+b.y)

# groups pixels which have roughtly the same motion to the same groups (called "ChangedAreaObj")
proc calcChangedAreas*(motionMap: var MatrixArr[Vec2[int]]): seq[ChangedAreaObj] =
  # TODO SCIFI LATER< use a NN to compute set of "ChangedAreaObj" we return. This has the advantage that it can take care of parallax motion and other "weird" motion types which are either hard or impossible to handle with handcrafted code >
  

  # new spinglass/firefly inspired algorithm to even out motion
  var selSpinglassAlgorithm: string = "spinglass" # which algorithm is selected as the spinglass algoirthm? "spinglass" for spinglass-inspired algorthm, "" for doing nothing in this step
  if selSpinglassAlgorithm == "spinglass":
    # compute how much the two motion vectors are "coupled"
    func calcCouplingFactor(a: Vec2[float], b: Vec2[float]): float =
      # calc dot product
      let dotRes: float = a.x*b.x + a.y*b.y

      let dirCouplingVal: float = (dotRes - 0.8) * (1.0 / (1.0 - 0.8))

      if dirCouplingVal < 0.0:
        return 0.0 # not the same direction thus they are not coupled

      # calculate same velocity-ness
      let diffX: float = a.x - b.x
      let diffY: float = a.y - b.y
      let len2: float = sqrt(diffX*diffX + diffY*diffY)

      let velCoupling: float = max(1.0 - len2, 0.0)

      return dirCouplingVal*velCoupling


    var m: MatrixArr[Vec2[float]] = makeMatrixArr(motionMap.w, motionMap.h, Vec2[float](x:0.0,y:0.0)) # matrix with field of motion vectors
    # fill
    for iy in 0..<motionMap.h:
      for ix in 0..<motionMap.w:
        let zx: float = float(motionMap.atUnsafe(iy, ix).x)
        let zy: float = float(motionMap.atUnsafe(iy, ix).y)
        m.writeAtSafe(iy, ix, Vec2[float](x:zx,y:zy))

    for iStep in 0..<5:
      var m2: MatrixArr[Vec2[float]] = makeMatrixArr(motionMap.w, motionMap.h, Vec2[float](x:0.0,y:0.0)) # next matrix

      for iy in 1..<m.h-1:
        for ix in 1..<m.w-1:
          let thisDir: Vec2[float] = atUnsafe(m, iy, ix)
        
          let l: Vec2[float] = atUnsafe(m, iy, ix-1) # left
          let r: Vec2[float] = atUnsafe(m, iy, ix+1) # right
          let t: Vec2[float] = atUnsafe(m, iy-1, ix) # top
          let b: Vec2[float] = atUnsafe(m, iy+1, ix) # bottom
        
          # compute couplings, inspired by spinglass / firefly algorithm
          let couplingFactorL: float = calcCouplingFactor(thisDir, l)
          let couplingFactorR: float = calcCouplingFactor(thisDir, r)
          let couplingFactorT: float = calcCouplingFactor(thisDir, t)
          let couplingFactorB: float = calcCouplingFactor(thisDir, b)
        
          # transfer by coupling
          var thisAccu: Vec2[float] = thisDir
          thisAccu = add(thisAccu, scale(l, couplingFactorL))
          thisAccu = add(thisAccu, scale(r, couplingFactorR))
          thisAccu = add(thisAccu, scale(t, couplingFactorT))
          thisAccu = add(thisAccu, scale(b, couplingFactorB))
          thisAccu = scale(thisAccu, 1.0/(1.0+couplingFactorL+couplingFactorR+couplingFactorT+couplingFactorB)) # 'normalize' while preserving scale
          m2.writeAtSafe(iy, ix, thisAccu)

      m = m2 # swap
    
    # convert back to integer motion vectors
    # FIXME< this is unnecessary, the algorithm to find equal motion should work with floating point vectors anyways! >
    for iy in 0..<motionMap.h:
      for ix in 0..<motionMap.w:
        let zx: int = int(m.atUnsafe(iy, ix).x)
        let zy: int = int(m.atUnsafe(iy, ix).y)
        motionMap.writeAtSafe(iy, ix, Vec2[int](x:zx,y:zy))




  

  # * classify motion based on vector

  let nDimBuckets: int = 3 # how many buckets for each motion component?
  let hysteresisMinMotionMag: int = 2 # minimal magnitude of motion

  # * classify motion based on vector
  var motionBuckets: seq[MatrixArr[int]] = @[]
  for z in 0..<(nDimBuckets*2+1):
    motionBuckets.add( makeMatrixArr[int](motionMap.w, motionMap.h, 0) )
  
  block: # algorithm to put each vector of the velocity field into the right bucket
    
    for iy in 0..motionMap.h-1:
      for ix in 0..motionMap.w-1:
        
        let vel: Vec2[int] = motionMap.atUnsafe(iy,ix)
        if abs(vel.x) <= hysteresisMinMotionMag and abs(vel.y) <= hysteresisMinMotionMag: # hysteresis
          continue # not fast enough, ignore
        
        # compute index of velocity by dimension
        var bucketIdxX: int = sgn(vel.x)*abs(int(vel.x/3)) + nDimBuckets + 1
        bucketIdxX = max(bucketIdxX, 0)
        bucketIdxX = min(bucketIdxX, nDimBuckets*2+1-1)

        var bucketIdxY: int = sgn(vel.y)*abs(int(vel.y/3)) + nDimBuckets + 1
        bucketIdxY = max(bucketIdxY, 0)
        bucketIdxY = min(bucketIdxY, nDimBuckets*2+1-1)


        # iterate over quadrants to figure out in which quadrant to store
        var iBucketIdx = bucketIdxX + bucketIdxY*(nDimBuckets*2+1)
        motionBuckets[iBucketIdx].writeAtSafe(iy,ix,1)








  # * group by coloring algorithm
  proc boundaryFill(posX: int, posY: int, boundaryColor: int, fillColor: int, img: var MatrixArr[int]) =
    # https://www.freecodecamp.org/news/boundary-fill-algorithm-pixel-filling-squares/
    var stack: seq[Vec2[int]] = @[] # stack of invocations to fill
    stack.push(Vec2[int](x:posX, y:posY))
    
    while stack.len > 0:
      let top: Vec2[int] = stack.pop()
      let col: int = img.atSafe(top.y, top.x, 0)
      if col != fillColor and col != boundaryColor: # if pixel not already filled or part of the boundary
        img.writeAtSafe(top.y, top.x, fillcolor)
        stack.push(Vec2[int](x:top.x + 1, y:top.y))
        stack.push(Vec2[int](x:top.x - 1, y:top.y))
        stack.push(Vec2[int](x:top.x, y:top.y + 1))
        stack.push(Vec2[int](x:top.x, y:top.y - 1))

  # FIXME< extremely inefficient hacky algorithm to get unique colors! >
  for iy in 0..motionMap.h-1:
    for ix in 0..motionMap.w-1:

      if motionMap.atSafe(iy,ix,Vec2[int](x:0,y:0)) != Vec2[int](x:0,y:0): # if there is something, then fill it!
        let itcol:int = ix + iy*motionMap.w + 1
        for idx in 0..<motionBuckets.len:
          boundaryFill(ix,iy,0,itcol,motionBuckets[idx])




  # * compose groups
  var regionByColor: Table[int, ChangedAreaObj] = initTable[int, ChangedAreaObj]()

  for iQuadrantIdx in 0..<motionBuckets.len:
    #

    for iy in 0..motionMap.h:
      for ix in 0..motionMap.w:
        let selQuadrantMap: MatrixArr[int] = motionBuckets[iQuadrantIdx]
        let v: int = selQuadrantMap.atSafe(iy,ix,0)
        if v != 0: # is it a pixel which has a value?
          if v in regionByColor:
            areaAdd(regionByColor[v], Vec2[int](x:ix,y:iy))
          else:
            regionByColor[v] = ChangedAreaObj(min:Vec2[int](x:ix,y:iy), max:Vec2[int](x:ix,y:iy))
  
  # * translate groups to flat list of groups
  var groups: seq[ChangedAreaObj] = @[]

  for iRegionId, iChangeArea in regionByColor.mpairs:
    groups.add(iChangeArea)
  
  return groups

# process motion from two frames and compute the changedArea rect's where to look for objects
proc processA*(am: MatrixArr[float64], bm: MatrixArr[float64]): seq[ChangedAreaObj] =
  var motionMatrix: MatrixArr[Vec2[int]] = calcMotionMatrix2(am, bm)
  

  if false:# debug motion matrix
    for iy in 0..motionMatrix.h-1:
      var iLine = ""

      for ix in 0..motionMatrix.w-1:
        let v = motionMatrix.atUnsafe(iy,ix)
        iLine = &"{iLine}<{v.x} {v.y}>,"
      
      echo(iLine)


  # * group
  let changedAreas: seq[ChangedAreaObj] = calcChangedAreas(motionMatrix)

  return changedAreas






if isMainModule:
  let a=0

  block: # testing if it computes the right motion vector
    let b=0

    var am: MatrixArr[float64] = makeMatrixArr(8, 8, 0.0)
    var bm: MatrixArr[float64] = makeMatrixArr(8, 8, 0.0)

    # first moving point
    am.writeAtSafe(2, 2, 1.0)
    bm.writeAtSafe(3, 2, 1.0)


    # second moving point
    am.writeAtSafe(7, 7, 1.0)
    am.writeAtSafe(7, 6, 1.0)
    bm.writeAtSafe(7, 5, 1.0)
    bm.writeAtSafe(7, 4, 1.0)

    var changedAreas: seq[ChangedAreaObj] = processA(am, bm)

    echo("")
    echo("")
    echo("")
    echo("DBG: changeAreas")
    for iArea in changedAreas:
      echo(&"min=<{iArea.min.x} {iArea.min.y}> max=<{iArea.max.x} {iArea.max.y}>")



