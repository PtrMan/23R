# variable sized matrix
type
  MatrixArr*[T] = object
    v*: seq[T]
    w*: int
    h*: int

proc makeMatrixArr*[T](w: int, h: int, val: T): MatrixArr[T] =
  var res: MatrixArr[T] = MatrixArr[T](v: @[],w:w,h:h)
  for ix in 0..w-1:
    for iy in 0..h-1:
      res.v.add(val)
  return res
      

proc atUnsafe*[T](this: MatrixArr[T], y: int, x:int): T =
  return this.v[x + y*this.w]

proc atSafe*[T](this: MatrixArr[T], y:int, x:int, default: T): T =
  if x < 0 or x >= this.w or y < 0 or y >= this.h:
    return default
  return atUnsafe(this, y, x)


proc writeAtSafe*[T](this: var MatrixArr[T], y:int, x:int, val:T) =
  if x < 0 or x >= this.w or y < 0 or y >= this.h:
    return
  this.v[x + y*this.w] = val
  

