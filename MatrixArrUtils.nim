# MatrixArrUtils

import matrixArr
import vec2

proc crop*[T](m: MatrixArr[T], default: T, minP: Vec2[int], maxP: Vec2[int]): MatrixArr[T] =
  let w = maxP.y-minP.y
  let h = maxP.x-minP.x

  var res: MatrixArr[T] = makeMatrixArr[T](w,h, default)

  for iy in 0..h-1:
    for ix in 0..w-1:
      let v = atSafe(m, minP.y+iy, minP.x+ix, default)
      res.writeAtSafe(iy,ix,v)
  
  return res


proc toSize*[T](m: MatrixArr[T], default: T, size: int): MatrixArr[T] =
  var res: MatrixArr[T] = makeMatrixArr[T](size,size, default)

  var c0x: float64 = float64(m.w)/2.0
  var c0y: float64 = float64(m.h)/2.0

  var maxSizeSrc: float64 = float64(max(m.w,m.h))

  for iy in 0..size-1:
    for ix in 0..size-1:
      var relX: float64 = float64(ix)/float64(size)
      var relY: float64 = float64(iy)/float64(size)

      var relX2: float64 = relX*2.0-1.0
      var relY2: float64 = relY*2.0-1.0

      var px: int = int(c0x + relX2*maxSizeSrc*0.5)
      var py: int = int(c0y + relY2*maxSizeSrc*0.5)

      let v = m.atSafe(py,px,default)
      res.writeAtSafe(iy,ix,v)
  
  return res
