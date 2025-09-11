from "settings" import get_setting_by_blk_path
from "videomode" import get_dlss_state, is_dlss_quality_available_at_resolution, get_current_window_resolution, get_dlssg_support_state, get_dlssg_maximum_number_of_frames_generated

from "%ui/ui_library.nut" import *

let { resolutionValue } = require("%ui/mainMenu/menus/options/resolution_state.nut")

const DLSS_BLK_PATH = "video/dlssQuality"
const DLSS_OFF = -1
const DLSS_PERFORMANCE = 0
const DLSS_BALANCED = 1
const DLSS_QUALITY = 2
const DLSS_ULTRA_PERFORMANCE = 3
const DLSS_ULTRA_QUALITY = 4
const DLSS_DLAA = 5
const DLSSG_BLK_PATH = "video/dlssFrameGenerationCount"


const NOT_IMPLEMENTED = 0
const NOT_CHECKED = 1
const NGX_INIT_ERROR_NO_APP_ID = 2
const NGX_INIT_ERROR_UNKNOWN = 3
const NOT_SUPPORTED_OUTDATED_VGA_DRIVER = 4
const NOT_SUPPORTED_INCOMPATIBLE_HARDWARE = 5
const NOT_SUPPORTED_32BIT = 6
const DISABLED = 7
const SUPPORTED = 8
const READY = 9

let dlssToString = static {
  [DLSS_OFF] = "option/off",
  [DLSS_PERFORMANCE] = "option/performance",
  [DLSS_BALANCED] = "option/balanced",
  [DLSS_QUALITY]  = "option/quality",
  [DLSS_ULTRA_PERFORMANCE]  = "option/ultraperformance",
  [DLSS_ULTRA_QUALITY]  = "option/ultraquality",
  [DLSS_DLAA] = "option/dlaa",
}

let dlssSupportLocId = static {
  
  
  [NOT_IMPLEMENTED] = "NOT_IMPLEMENTED",
  [NOT_CHECKED] = "NOT_CHECKED",
  [DISABLED] = "DISABLED",
  [NGX_INIT_ERROR_NO_APP_ID] = "NGX_INIT_ERROR_NO_APP_ID",
  [NGX_INIT_ERROR_UNKNOWN] = "NGX_INIT_ERROR_UNKNOWN",
  
  [NOT_SUPPORTED_OUTDATED_VGA_DRIVER] = "dlss/updateDrivers",
  [NOT_SUPPORTED_INCOMPATIBLE_HARDWARE] = "dlss/incompatibleHardware",
  [NOT_SUPPORTED_32BIT] = "dlss/notSupported32bit"
}

let curDlssSupportStateLocId = dlssSupportLocId?[get_dlss_state()]

let dlssNotAllowLocId = WatchedRo(curDlssSupportStateLocId)


const DLSSG_OS_OUF_OF_DATE = 1
const DLSSG_DRIVER_OUT_OF_DATE = 2
const DLSSG_HW_NOT_SUPPORTED = 3
const DLSSG_DISABLED_HWS = 4
const DLSSG_NOT_SUPPORTED = 5

const DLSSG_OFF = 0
const DLSSG_2X = 1
const DLSSG_3X = 2
const DLSSG_4X = 3

let dlssGSupportLocId = static {
  
  [DLSSG_NOT_SUPPORTED] = "NOT_SUPPORTED",

  
  [DLSSG_OS_OUF_OF_DATE] = "dlss/updateDrivers",
  [DLSSG_DRIVER_OUT_OF_DATE] = "dlss/updateOS",
  [DLSSG_HW_NOT_SUPPORTED] = "dlss/incompatibleHardware",
  [DLSSG_DISABLED_HWS] = "dlss/enableHWS",
}

let dlssgToString = static {
  [DLSSG_OFF] = "option/off",
  [DLSSG_2X] = "option/2x",
  [DLSSG_3X] = "option/3x",
  [DLSSG_4X] = "option/4x",
}

let curDlssGSupportStateLocId = dlssGSupportLocId?[get_dlssg_support_state()]


let dlssgNotAllowLocId = Watched(curDlssGSupportStateLocId)

let dlssAllQualityModes = [DLSS_ULTRA_PERFORMANCE, DLSS_PERFORMANCE, DLSS_BALANCED, DLSS_QUALITY, DLSS_ULTRA_QUALITY, DLSS_DLAA]

let dlssAvailable = Computed(function() {
  let dlssState = get_dlss_state()
  if (dlssState != SUPPORTED && dlssState != READY)
    return [DLSS_OFF] 
  local res = resolutionValue.get()
  if (type(res) != "array")
    res = get_current_window_resolution()
  return dlssAllQualityModes.filter(@(q) is_dlss_quality_available_at_resolution(res[0], res[1], q))
})

let dlssgAllModes = [DLSSG_OFF, DLSSG_2X, DLSSG_3X, DLSSG_4X]

let dlssgAvailable = WatchedRo(dlssgAllModes.filter(@(q) q <= get_dlssg_maximum_number_of_frames_generated()))

let dlssValueChosen = Watched(get_setting_by_blk_path(DLSS_BLK_PATH) ?? DLSS_QUALITY)

let dlssSetValue = @(v) dlssValueChosen.set(v)

let dlssValue = Computed(@() dlssNotAllowLocId.get() != null ? DLSS_OFF
  : dlssAvailable.get().indexof(dlssValueChosen.get()) != null ? dlssValueChosen.get()
  : DLSS_OFF)

let dlssgValueChosen = Watched(get_setting_by_blk_path(DLSSG_BLK_PATH) ?? DLSSG_OFF)

let dlssgSetValue = @(v) dlssgValueChosen.set(v)

let dlssgValue = Computed(@() dlssgNotAllowLocId.get() != null ? DLSSG_OFF
  : dlssgAvailable.get().indexof(dlssgValueChosen.get()) != null ? dlssgValueChosen.get()
  : DLSSG_OFF)


return freeze({
  DLSS_BLK_PATH
  DLSS_OFF
  dlssAvailable
  dlssValue
  dlssSetValue
  dlssToString
  dlssNotAllowLocId
  DLSSG_BLK_PATH
  dlssgAvailable
  dlssgValue
  dlssgSetValue
  dlssgNotAllowLocId
  dlssgToString
  DLSSG_OFF
})