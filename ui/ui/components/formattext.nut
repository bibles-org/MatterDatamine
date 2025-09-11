from "%dngscripts/platform.nut" import isPlatformRelevant

from "%sqstd/string.nut" import split

from "%ui/ui_library.nut" import *

let formatters = require("%ui/components/textFormatters.nut")
let mkFormatAst = require("%darg/helpers/mkFormatAst.nut")
let { defStyle } = formatters

#allow-auto-freeze

let filter = @(object) ("platform" in object) && !isPlatformRelevant(split(object.platform, ","))
let defParams = { formatters, style = defStyle, filter }
let formatText = mkFormatAst(defParams)

function mkFormatText(style, overrides = null) {
  let params = clone defParams
  params.style = params.style.__merge(style)
  if (typeof formatters == "table")
    params.formatters = params.formatters.__merge(overrides)
  return mkFormatAst(params)
}

return {
  mkFormatText
  formatText
  defStyle
}
