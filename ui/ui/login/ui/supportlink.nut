import "%ui/components/urlText.nut" as urlText

from "%ui/ui_library.nut" import *

let { gaijinSupportUrl } = require("%ui/login/ui/supportUrls.nut")

return {
  hplace=ALIGN_LEFT
  vplace=ALIGN_BOTTOM
  margin = hdpx(20)
  children = gaijinSupportUrl == "" ? null : urlText(loc("support"), gaijinSupportUrl, {opacity=0.7})
}