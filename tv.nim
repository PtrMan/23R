import std/streams

type
  Tv* = object
    f*: float64
    evi*: float64

func convEviToConf(evi: float64): float64 =
    let k = 1.0
    return evi / (evi + k)

func convConfToEvi(conf: float64): float64 =
    let k = 1.0
    return k * conf / (1.0 - conf)

func makeTv*(f: float64, c: float64): Tv =
    return Tv(f:f, evi:convConfToEvi(c))

func retConf*(tv: Tv): float64 =
    return convEviToConf(tv.evi)


func calcExp*(tv: Tv): float64 =
    return tv.retConf() * (tv.f - 0.5) + 0.5


func `or`(a: float64, b: float64): float64 =
    var product = 1.0;
    product *= (1.0 - a);
    product *= (1.0 - b);    
    return 1.0 - product



func tvDed*(a: Tv, b: Tv): Tv =
    let f = a.f*b.f
    let c = retConf(a)*retConf(b)*f
    return Tv(f:f, evi:convConfToEvi(c))


func tvAbd*(a: Tv, b: Tv): Tv =
    return Tv(f:b.f, evi: a.f*retConf(a)*retConf(b));


func tvInd*(a: Tv, b: Tv): Tv =
    return tvAbd(b, a);

func tvInt*(a: Tv, b: Tv): Tv =
    let aConf: float64 = convEviToConf(a.evi)
    let bConf: float64 = convEviToConf(b.evi)
    let conclConf: float64 = aConf*bConf
    let conclEvi: float64 = convConfToEvi(conclConf)
    return Tv(f:a.f*b.f, evi:conclEvi)


func tvComp*(a: Tv, b: Tv): Tv =
    let f0 = `or`(a.f, b.f);
    var f = 0.0
    if (f0 > 0.0):
        f = ((a.f*b.f) / f0);
    let w = retConf(a)*retConf(b)*f0
    let c = convEviToConf(w)
    return Tv(f:f, evi:convConfToEvi(c))

func tvRev*(a: Tv, b: Tv): Tv =
    let eviSum: float64 = a.evi+b.evi
    let f: float64 = (a.f*a.evi + b.f*b.evi) / eviSum
    return Tv(f:f, evi:eviSum)


func tvNeg(a: Tv): Tv =
    return Tv(f:1.0-a.f, evi:a.evi)

func tvGoalDed*(a: Tv, b: Tv): Tv =
    let res1: Tv = tvDed(a, b)
    let res2: Tv = tvNeg(tvDed(tvNeg(a), b))

    let resC1: float64 = convEviToConf(res1.evi)
    let resC2: float64 = convEviToConf(res2.evi)

    if resC1 >= resC2:
        return res1
    return res2



# marshal to raw data
proc marshalTvAsRaw(self: Tv, dest: StringStream) =
  dest.write(self.f)
  dest.write(self.evi)

# marshal from raw data
proc marshalTvFromRaw(src: StringStream): Tv =
  let f: float64 = src.readFloat64()
  let evi: float64 = src.readFloat64()
  return Tv(f:f, evi:evi)
