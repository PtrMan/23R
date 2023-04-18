import std/tables
import std/strformat

import motion0
import matrixArr
import vec2

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


# groups pixels which have roughtly the same motion to the same groups (called "ChangedAreaObj")
proc calcChangedAreas*(motionMap: MatrixArr[Vec2[int]]): seq[ChangedAreaObj] =
  # TODO SCIFI LATER< use a NN to compute set of "ChangedAreaObj" we return. This has the advantage that it can take care of parallax motion and other "weird" motion types which are either hard or impossible to handle with handcrafted code >
  
  

  # * classify motion based on vector
  var quadrants: seq[MatrixArr[int]] = @[]
  quadrants.add( makeMatrixArr[int](motionMap.w, motionMap.h, 0) )
  quadrants.add( makeMatrixArr[int](motionMap.w, motionMap.h, 0) )
  quadrants.add( makeMatrixArr[int](motionMap.w, motionMap.h, 0) )
  quadrants.add( makeMatrixArr[int](motionMap.w, motionMap.h, 0) )
  
  block:
    
    for iy in 0..motionMap.h-1:
      for ix in 0..motionMap.w-1:
        
        let dir: Vec2[int] = motionMap.atUnsafe(iy,ix)
        if abs(dir.x) <= 0 and abs(dir.y) <= 0:
          continue # not fast enough, ignore

        # iterate over quadrants to figure out in which quadrant to store
        var iQuadrantIdx = 0
        for idir in [(0,1),(0,-1),(1,0),(-1,0)]:
          let a: int = ix*idir[0] + iy*idir[1]
          let b: int = ix*idir[1] + iy*idir[0] # 90 degree rotated axis
          if a >= 0 and abs(a) <= abs(b): # is inside quadrant?
            quadrants[iQuadrantIdx].writeAtSafe(iy,ix,1)
          
          iQuadrantIdx+=1



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
        boundaryFill(ix,iy,0,itcol,quadrants[0])
        boundaryFill(ix,iy,0,itcol,quadrants[1])
        boundaryFill(ix,iy,0,itcol,quadrants[2])
        boundaryFill(ix,iy,0,itcol,quadrants[3])

  

  # * compose groups
  var regionByColor: Table[int, ChangedAreaObj] = initTable[int, ChangedAreaObj]()

  for iQuadrantIdx in 0..quadrants.len-1:
    #

    for iy in 0..motionMap.h:
      for ix in 0..motionMap.w:
        let selQuadrantMap: MatrixArr[int] = quadrants[iQuadrantIdx]
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
  let motionMatrix: MatrixArr[Vec2[int]] = calcMotionMatrix2(am, bm)
  

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



