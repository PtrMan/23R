
import std/math

proc vecDot*[s: static int, T](a: array[s, T], b: array[s, T]): T =
    var res: T = 0.0
    for idx in 0..s-1:
      res += (a[idx]*b[idx])
    return res

proc vecL2norm*[s: static int, T](v: array[s, T]): T =
  return sqrt(vecDot(v,v))

  

# cosine similarity
proc simCos*[s: static int, T](a: array[s, T], b: array[s, T]): T =
  return vecDot(a, b) / (vecL2norm(a)*vecL2norm(b))
