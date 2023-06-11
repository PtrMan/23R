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
    class*: int64


type
  VisionSys0Obj* {.exportc.} = ref VisionSys0
  VisionSys0* = object
    classifier0*: Classifier0[WIDTHCATEGORY]

    layer0: Layer[layer0StimulusWidth]
    layer1: Layer[nUnitsPerLayer[0]]

    # scratchpad of classifications of last frame
    scratchpadClassificationsLastFrame: seq[ClassificationWithRectRef]

    # statistics
    statsCreatedNewCategory*: int64
    statsRecognized*: int64

# PUBLIC interface    
proc visionSys0Create*(): VisionSys0Obj {.exportcpp.} =
  var classifier0: Classifier0[WIDTHCATEGORY] = createClassifier0[WIDTHCATEGORY]()
  classifier0.classifierSimThreshold = 0.65
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
proc visionSys0classifyAndAdd*(self: VisionSys0Obj, rawDat:seq[float64]): Prototype0Obj[WIDTHCATEGORY] =
  let rawImg: seq[float64] = convRawImgDatToRawDat(rawDat)

  var nnOutRealAArr: array[WIDTHCATEGORY, float64]
  for iidx in 0..nnOutRealAArr.len-1:
    nnOutRealAArr[iidx] = rawImg[iidx]

  let res0 = self.classifier0.classify0AndAdd(nnOutRealAArr)

  # statistics
  if res0.createdNewCategory:
    self.statsCreatedNewCategory+=1
  else:
    self.statsRecognized+=1

  return res0.proto

# PUBLIC interface
# processes a new image girven the old image
proc visionSys0process0*(self: VisionSys0Obj, am: MatrixArr[float64], bm: MatrixArr[float64],   ar: MatrixArr[float64], ag: MatrixArr[float64], ab: MatrixArr[float64],   br: MatrixArr[float64], bg: MatrixArr[float64], bb: MatrixArr[float64]) =
  let a=0

  var changedAreas: seq[ChangedAreaObj] = processA(am, bm)

  echo("")
  echo("")
  echo("")
  echo("DBG: changeAreas")
  for iArea in changedAreas:
    echo(&"min=<{iArea.min.x} {iArea.min.y}> max=<{iArea.max.x} {iArea.max.y}>")
  
  # filter by minimum extend
  # 2.3.2023
  block:
    var changedAreas2: seq[ChangedAreaObj] = @[]
    for iArea in changedAreas:
      let extendWidth = iArea.max.x - iArea.min.x
      let extendHeight = iArea.max.y - iArea.min.y
      let extend = min(extendWidth, extendHeight)
      if extend > 10:
        changedAreas2.add(iArea)
    
    changedAreas = changedAreas2


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
    let classifiedProto = visionSys0classifyAndAdd(self, arr)

    var classification0: ClassificationWithRectRef = ClassificationWithRectRef(rect: iArea, class: classifiedProto.uniqueId)
    self.scratchpadClassificationsLastFrame.add(classification0)



var outStatsCreatedNewCategory*: int64
var outStatsRecognized*: int64

# C++ binding of vision processing
# takes flat C arrays of the images
proc visionSys0process0Cpp*(self: VisionSys0Obj, aArr: ptr UncheckedArray[float64], bArr: ptr UncheckedArray[float64],  arArr: ptr UncheckedArray[float64], agArr: ptr UncheckedArray[float64], abArr: ptr UncheckedArray[float64],   brArr: ptr UncheckedArray[float64], bgArr: ptr UncheckedArray[float64], bbArr: ptr UncheckedArray[float64]) {.exportc.} =
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
  

  var ar: MatrixArr[float64] = makeMatrixArr(128, 80, 0.0)
  var ag: MatrixArr[float64] = makeMatrixArr(128, 80, 0.0)
  var ab: MatrixArr[float64] = makeMatrixArr(128, 80, 0.0)
  block:
    var iidx: int = 0
    for iy in 0..bm.h-1:
      for ix in 0..bm.w-1:
        let r: float64 = arArr[iidx]
        let g: float64 = agArr[iidx]
        let b: float64 = abArr[iidx]
        ar.writeAtSafe(iy,ix,r)
        ag.writeAtSafe(iy,ix,g)
        ab.writeAtSafe(iy,ix,b)
        iidx+=1
  
  var br: MatrixArr[float64] = makeMatrixArr(128, 80, 0.0)
  var bg: MatrixArr[float64] = makeMatrixArr(128, 80, 0.0)
  var bb: MatrixArr[float64] = makeMatrixArr(128, 80, 0.0)
  block:
    var iidx: int = 0
    for iy in 0..bm.h-1:
      for ix in 0..bm.w-1:
        let r: float64 = arArr[iidx]
        let g: float64 = arArr[iidx]
        let b: float64 = arArr[iidx]
        br.writeAtSafe(iy,ix,r)
        bg.writeAtSafe(iy,ix,g)
        bb.writeAtSafe(iy,ix,b)
        iidx+=1

  
  visionSys0process0(self, am, bm,   ar, ag, ab,  br, bg, bb)

  # update global vars for statistics
  outStatsCreatedNewCategory = self.statsCreatedNewCategory
  outStatsRecognized = self.statsRecognized

var outResStr0*: cstring


proc convClassnWithRectsToStrCpp*(self: VisionSys0Obj) {.exportc.} =
  var resStr: string = ""
  
  for iClassnWithRect in self.scratchpadClassificationsLastFrame:
    resStr = resStr & &"{iClassnWithRect.rect.min.x},{iClassnWithRect.rect.min.y},{iClassnWithRect.rect.max.x},{iClassnWithRect.rect.max.y},{iClassnWithRect.class}\n"
  
  outResStr0 = resStr # set global variable
