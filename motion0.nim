# simple motion estimation algorithm

import std/math

import matrixArr
import vec2

var motionVecSearchRectWidth*: int = 3 
var motionVecSearchDistPenality*: float64 = 0.001

proc calcDiff*(am: MatrixArr[float64], bm: MatrixArr[float64], center: Vec2[int], delta: Vec2[int], rectWidth: int): float64 =
  var diffSum: float64 = 0.0
  
  for iy in -int(rectWidth/2)..int(rectWidth/2)-1:
    for ix in -int(rectWidth/2)..int(rectWidth/2)-1:
      let a: float64 = atSafe(am, iy+center.y, ix+center.x, 0.0)
      let b: float64 = atSafe(bm, iy+delta.y+center.y, ix+delta.x+center.x, 0.0)
      let diff: float64 = a-b
      diffSum += (diff*diff) # compute MSE because it has nice properties
  
  return diffSum

proc calcBestMotionVector*(am: MatrixArr[float64], bm: MatrixArr[float64], center: Vec2[int]): tuple[v: Vec2[int], val: float64] =
  # find best spot with the smallest difference which is the closest to the origin
  
  var best: tuple[v: Vec2[int], val: float64] = (Vec2[int](x:0,y:0), 1.0e12)

  let searchWidth: int = 10 # how many pixels are searched in each direction?
  let rectWidth: int = motionVecSearchRectWidth
  for dy in -int(searchWidth/2)..int(searchWidth/2)-1:
    for dx in -int(searchWidth/2)..int(searchWidth/2)-1:
      let deltaVec: Vec2[int] = Vec2[int](x:dx, y:dy)
      let dist: float64 = sqrt(float(deltaVec.x*deltaVec.x + deltaVec.y*deltaVec.y))
      let distCost: float64 = motionVecSearchDistPenality*dist

      let diff: float64 = calcDiff(am, bm, center, deltaVec, rectWidth)

      let val: float64 = diff + distCost
      if val < best.val:
        best = (deltaVec, val)
  
  return best


proc calcMotionMatrix*(am: MatrixArr[float64], bm: MatrixArr[float64]): MatrixArr[Vec2[int]] =
  var res: MatrixArr[Vec2[int]] = makeMatrixArr[Vec2[int]](am.w, am.h, Vec2[int](x:0,y:0))
  
  for iy in 0..am.h-1:
    for ix in 0..am.w-1:
      let motionWithEstimation = calcBestMotionVector(am, bm, Vec2[int](x:ix,y:iy))
      res.writeAtSafe(iy,ix,motionWithEstimation.v)
  
  return res
