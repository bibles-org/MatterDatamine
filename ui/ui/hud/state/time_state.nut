from "net" import get_sync_time

from "%ui/ui_library.nut" import *

let curTime = Watched(0.0)

gui_scene.setInterval(1.0/60.0, @() curTime.set(get_sync_time()))
let curTimePerSec = Computed(@() (curTime.get()+0.5).tointeger())

return {
  curTime
  curTimePerSec
}
