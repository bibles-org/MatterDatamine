module random_common shared
require DagorMath
require DagorRandom
require math
require math.base
require math.random


def generate_non_duplicate_sequence_index(index : int;
                                          indices_count : int;
                                          chain_segments : int;
                                          seed : int = 0)
  if indices_count == 0
    return -1
  elif indices_count == 1
    return 0
  elif indices_count == 2
    return index % 2

  let chainLength = chain_segments * indices_count

  let chainIndex = index / chainLength
  let valueIndex = index % chainLength

  var currentChain : array<int>
  currentChain |> resize(chainLength)
  for i in iter_range(currentChain)
    currentChain[i] = (chainIndex + i + seed) % indices_count

  var rndSeed = chainIndex + seed

  // Shuffle values in the middle of the chain
  for curIndex in range(1, chainLength - 1)
    let curValue = currentChain[curIndex]
    let leftFromCurValue = currentChain[curIndex - 1]
    let rightFromCurValue = currentChain[curIndex + 1]

    var tries = 5
    var swapIndex : int
    while true
      swapIndex = _rnd_int(rndSeed, 1, chainLength - 1 - 1)
      let swapValue = currentChain[swapIndex]
      let leftFromSwapValue = currentChain[swapIndex - 1]
      let rightFromSwapValue = currentChain[swapIndex + 1]

      if (curValue == swapValue ||
        (swapIndex - 1 != curIndex && leftFromSwapValue == curValue) ||
        (swapIndex + 1 != curIndex && rightFromSwapValue == curValue) ||
        (curIndex - 1 != swapIndex && leftFromCurValue == swapValue) ||
        (curIndex + 1 != swapIndex && rightFromCurValue == swapValue))
        if --tries >= 0
          continue
        else
          break
      break
    if tries >= 0
      swap(currentChain[curIndex], currentChain[swapIndex])

  return currentChain[valueIndex]


def shuffle_seeded_range(var list;
                         var seed : int&;
                         from : int = 0;
                         to : int = -1)
  let maxSize = _::length(list)
  let size = to >= 0 ? min(to, maxSize) : maxSize
  for i in range(from, size)
    let idx = _rnd_int(seed, from, size - 1)
    swap(list[i], list[idx])


def generate_non_duplicate_alternated_sequence_index(index : int;
                                                     indices_count : int;
                                                     seed : int)
  if indices_count <= 0
    return -1

  var indices <- [for idx in range(indices_count); idx]
  var rndSeed = seed
  shuffle_seeded_range(indices, rndSeed, 0, indices_count)

  let chainIndex = index / indices_count
  let valueIndex = index % indices_count

  let midPoint = indices_count / 2

  rndSeed += ((chainIndex * 11035152 + 12345) % 42949672)
  if valueIndex < midPoint
    shuffle_seeded_range(indices, rndSeed, 0, midPoint)
  else
    shuffle_seeded_range(indices, rndSeed, midPoint, indices_count)

  return indices[valueIndex]


