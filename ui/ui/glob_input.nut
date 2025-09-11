from "screencap" import take_screenshot_nogui, take_screenshot

from "%ui/ui_library.nut" import *

let voiceHotkeys = require("%ui/voiceChat/voiceControl.nut")

let eventHandlers = {
    ["Global.Screenshot"] = @(...) take_screenshot(),
    ["Global.ScreenshotNoGUI"] = @(...) take_screenshot_nogui()
  }
foreach (k, v in voiceHotkeys.eventHandlers)
  eventHandlers[k] <- v

return { eventHandlers = eventHandlers }
