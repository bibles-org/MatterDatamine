from "%ui/ui_library.nut" import *

let {sound_set_volume=@(...) null} = require_optional("sound")

if (sound_set_volume==null)
  return

foreach (opt in ["MASTER","effects","voices","interface","music"]) {
  let capOpt = opt
  console_register_command(function(val) {sound_set_volume(capOpt, val)}, $"snd.set_volume_{opt}")
}
console_register_command(function(val) {sound_set_volume("MASTER", val)}, "snd.set_volume")
