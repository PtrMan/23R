import sequtils
import sets
import std/streams

proc merge*(s1, s2: seq[int64], maxLen: int): seq[int64] =
  # prompt to chatGPT to generate most of the code:
  # "A stamp is a seq of integers. A stamp merge is the interleaving of two stamps. Implement stamp merge in Nim"

  var result: seq[int64] = @[]

  # Set up counters for each input list
  var i = 0
  var j = 0

  # While both input lists have elements remaining
  while i < s1.len and j < s2.len:
    # If the current element of s1 is smaller than the current element of s2
    if s1[i] < s2[j]:
      result.add(s1[i]) # Append the current element of s1 to the result list
      i += 1 # Increment the counter for s1
    else:
      result.add(s2[j]) # Otherwise, append the current element of s2 to the result list
      j += 1 # Increment the counter for s2

  # If one of the input lists has elements remaining, append them to the result list
  result = result&(s1[i..s1.len-1])
  result = result&(s2[j..s2.len-1])

  result = result[0..min(result.len-1, maxLen-1)]

  return result

proc checkStampOverlap*(a, b: seq[int64]): bool =
  if a.len*b.len < 70:
    for ia in a:
      for ib in b:
        if ia == ib:
          return true
    return false
  else:
    let aSet = toHashSet(a)
    let bSet = toHashSet(b)
    return intersection(aSet,bSet).len != 0




# marshal to raw data
proc marshalStampAsRaw(self: seq[int64], dest: StringStream) =
  dest.write(self)

# marshal from raw data
proc marshalStampFromRaw(src: StringStream): seq[int64] =
  var result: seq[int64]
  src.read(result)
  return result
