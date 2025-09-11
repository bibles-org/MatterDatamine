from "videomode" import get_video_modes
from "dagor.system" import get_primary_screen_info

from "%ui/ui_library.nut" import *

let { monitorValue } = require("%ui/mainMenu/menus/options/monitor_state.nut")
let platform = require("%dngscripts/platform.nut")

function getResolutions(monitor) {
  let res = get_video_modes(monitor)

  
  if (platform.is_windows && res.list.len() <= 2) {
    let newList = res.list.filter(@(v) type(v) == "array")
    local maxRes = newList?[newList.len() - 1]
    if (maxRes == null) {
      try {
        let { pixelsWidth, pixelsHeight } = get_primary_screen_info()
        maxRes = [ pixelsWidth, pixelsHeight ]
      }
      catch(e) { 
        return res
      }
    }
    let resolutions = [ [1024,768], [1280,720], [1280,1024], [1920,1080], [1920,1200],
      [2520,1080], [2560,1440], [3840,1080], [3840,2160] ]
        .filter(@(v) newList.findvalue(@(r) r[0] == v[0] && r[1] == v[1]) == null
          && v[0] <= maxRes[0] && v[1] <= maxRes[1])
    newList.extend(resolutions)
    newList.sort(@(a, b) a[0] <=> b[0]  || a[1] <=> b[1])
    newList.insert(0, "auto")
    res.list = newList
  }

  return res
}


local availableResolutions = getResolutions(monitorValue.get())

let resolutionList = Watched(availableResolutions.list)
let resolutionValue = Watched(availableResolutions.current)

function overrideAvalilableResolutions(monitor) {
  availableResolutions = getResolutions(monitor)
}

return {
  resolutionList
  resolutionValue
  overrideAvalilableResolutions
  availableResolutions
  getResolutions
}