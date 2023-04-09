# general utilities for vision (both for training of NN and testing of NN)

# helper to convert image to convoluted representation which is given into the NN as stimulus
proc convRawImgDatToRawDat*(inImg: seq[float64]): seq[float64] =
  var rawDat: seq[float64] = @[]
  for iy in 0..16-1:
    for ix in 0..16-1:
      var outVal: float64 = 0.0
      if ix < 16-1-1:
        var a: float64 = inImg[ix + iy*16]
        var b: float64 = inImg[(ix+1) + iy*16]
        outVal = b-a # extremely simple edge detector in x-direction
      rawDat.add(outVal)

  return rawDat

