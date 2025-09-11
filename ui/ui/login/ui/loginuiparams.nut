from "settings" import get_setting_by_blk_path
import "auth" as auth

from "%ui/ui_library.nut" import *


function addQueryParam(url, name, value) {
  let delimiter = url.contains("?") ? "&" : "?"
  return "".concat(url,delimiter, name, "=", value)
}


let distrStr = auth?.get_distr() ?? ""
let defRegUrl = get_setting_by_blk_path("registerUrl") ?? "https://login.gaijin.net/profile/register"
let registerUrl = distrStr != "" ? addQueryParam(defRegUrl, "distr", distrStr) : defRegUrl

return {
  registerUrl
}