from "%ui/hud/subtitles/subtitles_common.nut" import clearTextSubtitlesTags

from "%ui/ui_library.nut" import *


function get_paragraph_loc(id, i) {
  let paragraph = loc($"notes/{id}/paragraph/{i}", "")
  if (paragraph != "")
    return clearTextSubtitlesTags(paragraph)

  return paragraph
}

return {
  get_paragraph_loc
}