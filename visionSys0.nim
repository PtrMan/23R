# combined vision system
#
# combining motion extractor and siamese NN and classifier


# compile to C++ module
#   nim cpp --noMain --noLinking visionSys0.nim

import strutils
import strformat
import math

import motion1
import protoBp0
import vision0
import visionUtils
import matrixArr
import MatrixArrUtils


const WIDTHCATEGORY = 12 # width of the category vector in scalar values used for classification
const layer0StimulusWidth = 16*16
const nUnitsPerLayer: seq[int] = @[12, WIDTHCATEGORY]


type
  ClassificationWithRectRef* = ref ClassificationWithRect
  ClassificationWithRect* = object
    rect*: ChangedAreaObj
    class*: int


type
  VisionSys0Obj* {.exportc.} = ref VisionSys0
  VisionSys0* = object
    classifier0*: Classifier0[WIDTHCATEGORY]

    layer0: Layer[layer0StimulusWidth]
    layer1: Layer[nUnitsPerLayer[0]]

    # scratchpad of classifications of last frame
    scratchpadClassificationsLastFrame: seq[ClassificationWithRectRef]

# PUBLIC interface    
proc visionSys0Create*(): VisionSys0Obj {.exportcpp.} =
  var classifier0: Classifier0[WIDTHCATEGORY] = createClassifier0[WIDTHCATEGORY]()
  classifier0.classifierSimThreshold = 0.92
  classifier0.distMode = 1 # set to L2-norm based similarity



  var weightsAndBiases: seq[float64] = @[]
  block: # load file and parse numbers from it
    let fContent: string = readFile("snnweights_12_12__0.txt")
    
    let numbersStrs: seq[string] = fContent.split(',')
    for iNumberStr in numbersStrs:
      weightsAndBiases.add(parseFloat(iNumberStr))

  #const layer0StimulusWidth = 16*16
  #const nUnitsPerLayer: seq[int] = @[12, WIDTHCATEGORY]

  var layer0: Layer[layer0StimulusWidth]
  var layer1: Layer[nUnitsPerLayer[0]]

  # create units

  for i in 0..nUnitsPerLayer[0]-1:
    var u0: Unit[layer0StimulusWidth] = Unit[layer0StimulusWidth]()
    layer0.units.add(u0)

  for i in 0..nUnitsPerLayer[1]-1:
    var u0: Unit[nUnitsPerLayer[0]] = Unit[nUnitsPerLayer[0]]()
    layer1.units.add(u0)
  
  ## load weights and biases into units
  block:
    var iidx: int = 0
    for iUnitIdx in 0..layer0.units.len-1:
      layer0.units[iUnitIdx].biasR = weightsAndBiases[iidx]
      iidx+=1
      for iidx2 in 0..layer0.units[iUnitIdx].r.len-1:
        layer0.units[iUnitIdx].r[iidx2] = weightsAndBiases[iidx]
        iidx+=1
    for iUnitIdx in 0..layer1.units.len-1:
      layer1.units[iUnitIdx].biasR = weightsAndBiases[iidx]
      iidx+=1
      for iidx2 in 0..layer1.units[iUnitIdx].r.len-1:
        layer1.units[iUnitIdx].r[iidx2] = weightsAndBiases[iidx]
        iidx+=1
  
  return VisionSys0Obj(classifier0:classifier0,  layer0:layer0, layer1:layer1)


# helper
# classify a image of the right size
proc visionSys0classifyAndAdd*(self: VisionSys0Obj, rawDat:seq[float64]) =
  let rawImg: seq[float64] = convRawImgDatToRawDat(rawDat)

  var nnOutRealAArr: array[WIDTHCATEGORY, float64]
  for iidx in 0..nnOutRealAArr.len-1:
    nnOutRealAArr[iidx] = rawImg[iidx]

  self.classifier0.classify0AndAdd(nnOutRealAArr)

# PUBLIC interface
# processes a new image girven the old image
proc visionSys0process0*(self: VisionSys0Obj, am: MatrixArr[float64], bm: MatrixArr[float64]) =
  let a=0

  var changedAreas: seq[ChangedAreaObj] = processA(am, bm)

  echo("")
  echo("")
  echo("")
  echo("DBG: changeAreas")
  for iArea in changedAreas:
    echo(&"min=<{iArea.min.x} {iArea.min.y}> max=<{iArea.max.x} {iArea.max.y}>")
  

  # now we crop the areas, scale the cropped areas to the right fixed size, and stuff these into the classifier
  self.scratchpadClassificationsLastFrame = @[]
  for iArea in changedAreas:
    let croppedImg: MatrixArr[float64] = crop(bm, 0.0, iArea.min, iArea.max)
    let croppedImg2: MatrixArr[float64] = toSize(croppedImg, 0.0, 16)
    

    # convert from Matrix to array
    var arr: seq[float64] = @[]
    for iy in 0..16-1:
      for ix in 0..16-1:
        let v: float64 = croppedImg2.atSafe(iy,ix,0.0)
        arr.add(v)
    
    # classify
    visionSys0classifyAndAdd(self, arr)

    var classification0: ClassificationWithRectRef = ClassificationWithRectRef(rect: iArea, class: 0)
    self.scratchpadClassificationsLastFrame.add(classification0)





# C++ binding of vision processing
# takes flat C arrays of the images
proc visionSys0process0Cpp*(self: VisionSys0Obj, aArr: ptr UncheckedArray[float64], bArr: ptr UncheckedArray[float64]) {.exportc.} =
  # convert array back to matrix
  var am: MatrixArr[float64] = makeMatrixArr(128, 80, 0.0)
  block:
    var iidx: int = 0
    for iy in 0..am.h-1:
      for ix in 0..am.w-1:
        let v: float64 = aArr[iidx]
        am.writeAtSafe(iy,ix,v)
        iidx+=1
  
  var bm: MatrixArr[float64] = makeMatrixArr(128, 80, 0.0)
  block:
    var iidx: int = 0
    for iy in 0..bm.h-1:
      for ix in 0..bm.w-1:
        let v: float64 = bArr[iidx]
        bm.writeAtSafe(iy,ix,v)
        iidx+=1
  
  visionSys0process0(self, am, bm)

var outResStr0*: cstring


proc convClassnWithRectsToStrCpp*(self: VisionSys0Obj) {.exportc.} =
  var resStr: string = ""
  
  for iClassnWithRect in self.scratchpadClassificationsLastFrame:
    resStr = resStr & &"{iClassnWithRect.rect.min.x},{iClassnWithRect.rect.min.y},{iClassnWithRect.rect.max.x},{iClassnWithRect.rect.max.y},{iClassnWithRect.class}\n"
  
  outResStr0 = resStr # set global variable
