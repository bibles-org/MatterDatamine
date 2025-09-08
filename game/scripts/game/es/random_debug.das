options no_aot
require ecs
require ecs.safe
require daslib/strings_boost
require DagorConsole
require game.es.level_common
require game.es.random_common
require DagorTime


[console_cmd(name="random.generate_non_duplicate_sequence")]
def cmd_generate_non_duplicate_sequence(seed : int = 0)
  let indicesCount = 5
  let chainSegments = 3
  let chainLength = indicesCount * chainSegments
  let chainsCount = 5
  let logStr = build_string() <| $(str)
    for chainIndex in range(0, chainsCount)
      str |> write("[")
      for index in range(0, chainLength)
        let value = generate_non_duplicate_sequence_index(chainIndex * chainLength + index, indicesCount, chainSegments, seed)
        str |> write("{value}")
        if index != chainLength - 1
          str |> write(" ")
      str |> write("]")
      if chainIndex != chainsCount - 1
        str |> write(" ")
  console_print(logStr)


[console_cmd(name="random.generate_non_duplicate_alternated_sequence")]
def cmd_generate_non_duplicate_alternated_sequence(seed : int = 0)
  let indicesCount = 8
  let chainsCount = 10
  let logStr = build_string() <| $(str)
    for chainIndex in range(0, chainsCount)
      str |> write("[")
      for index in range(0, indicesCount)
        let value = generate_non_duplicate_alternated_sequence_index(chainIndex * indicesCount + index, indicesCount, seed)
        str |> write("{value}")
        if index != indicesCount - 1
          str |> write(" ")
      str |> write("]")
      if chainIndex != chainsCount - 1
        str |> write(" ")
  console_print(logStr)