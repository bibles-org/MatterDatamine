from "%ui/ui_library.nut" import *
let regexp2 = require("regexp2")

function clearValueTags(text, brackets) {
  local ret = text ?? ""
  foreach (bracket in brackets) {
    let pattern = regexp2($"{bracket.opening}.*?{bracket.closing}")
    ret = pattern.replace("", ret)
  }

  return ret
}


function clearTextTags(text) {
  return clearValueTags(text, [
    {
      opening = "<color="
      closing = ">"
    }
    {
      opening = "</color"
      closing = ">"
    }
  ])
}

function clearTextSubtitlesTags(text) {
  return clearValueTags(text, [
    {
      opening = "\\[\\[\\[SubtitlesDivider"
      closing = "\\]\\]\\]"
    }
  ])
}

return {
  clearTextTags
  clearTextSubtitlesTags
}