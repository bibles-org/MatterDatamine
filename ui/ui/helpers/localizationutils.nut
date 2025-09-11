from "%ui/ui_library.nut" import *
from "%ui/state/clientState.nut" import isChineseLanguage, isJapaneseLanguage

let { processHypenationsCN = @(v) v, processHypenationsJP = @(v) v } = require("dagor.localize")


let typeHyphenations = freeze(["paragraph", "h1", "h2", "h3", "text"].totable())

function applyHandlers(data, handler) {
  foreach (block in data) {
    let blockType = block?.t
    if (blockType in typeHyphenations)
      block.v = handler(block.v)
    else if (blockType == "list")
      foreach (idx, item in block.v) {
        if (typeof item == "string")
          block.v[idx] = handler(item)
        else
          applyHandlers(item, handler)
      }
  }
}

function processHyphenations(data) {
  if (isChineseLanguage())
    applyHandlers(data, processHypenationsCN)
  else if (isJapaneseLanguage())
    applyHandlers(data, processHypenationsJP)
  return data
}


return {
  processHyphenations
}
