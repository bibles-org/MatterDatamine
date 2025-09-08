require app
require strings

def get_bots_num_from_cmdline()
  let arg = dgs_get_argv("botpop")
  if arg == ""
    return 0

  var res : ConversionResult
  var ofs : int
  let input = int(arg, res, ofs)
  if res == ConversionResult.ok && ofs == length(arg)
    print("bots population from commandline: {input}")
    return input
  return 0

