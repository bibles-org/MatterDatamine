from "videomode" import get_available_monitors, get_monitor_info
from "%ui/ui_library.nut" import *

let monitorValue = Watched(get_available_monitors().current)

let get_friendly_monitor_name = function(v) {
  let monitor_info = get_monitor_info(v)
  if (!monitor_info)
    return v

  let hdr_string = monitor_info?[2]
    ? (" ({0})".subst(loc("option/hdravailable", "HDR is available")))
    : ""
  return $"{monitor_info[0]} [#{monitor_info[1] + 1}]{hdr_string}"
}

return {
  get_available_monitors
  monitorValue
  get_friendly_monitor_name
}