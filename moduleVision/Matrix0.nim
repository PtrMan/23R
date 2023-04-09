
type
  Matrix0*[w: static int, h: static int, T] = object
    v*: array[w*h, T]


proc atUnsafe*[w: static int, h: static int, T](this: Matrix0[w,h,T], y: int, x:int): T =
  return this.v[x + y*w]

proc atSafe*[w, h, T](this: Matrix0[w,h,T], y:int, x:int, default: T): T =
  if x < 0 or x >= w or y < 0 or y >= h:
    return default
  return atUnsafe(this, y, x)


proc writeAtSafe*[w, h, T](this: var Matrix0[w,h,T], y:int, x:int, val:T) =
  if x < 0 or x >= w or y < 0 or y >= h:
    return
  this.v[x + y*w] = val
  




