from "%ui/ui_library.nut" import *

let { clearTextSubtitlesTags } = require("%ui/hud/subtitles/subtitles_common.nut")

function get_paragraph_loc(id, i) {
  let paragraph = loc($"notes/{id}/paragraph/{i}", "")
  if (paragraph != "")
    return clearTextSubtitlesTags(paragraph)

  return paragraph
}

return {
  get_paragraph_loc
}