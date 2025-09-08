let { deep_clone, isEqual } = require("%sqstd/underscore.nut")
let { floor, ceil, min, max } = require("math")


let scrollHandlerDataTemplate = {
  handler = null
  prevData = {
    fullHeight=0,
    visibleHeight=0,
    currentYOffset=0
  }
}

let mkScrollHandlerData = @() deep_clone(scrollHandlerDataTemplate)

let resetScrollHandlerDataCommon = function(handlerData) {
  handlerData.prevData = {
    fullHeight=0,
    visibleHeight=0,
    currentYOffset=0
    numPanels=0
  }
}

let updatePanelsVisibilityDataCommon = function(scrollHandlerData,
                                                numberOfPanels,
                                                itemsPanelData,
                                                itemsInRow) {
  let scrollHandler = scrollHandlerData.handler
  if (scrollHandler == null) {
    return
  }
  let elem = scrollHandler.elem
  if (elem == null) {
    return
  }
  let fullHeight = elem.getContentHeight()
  let visibleHeight = elem.getHeight()
  let currentYOffset = elem.getScrollOffsY()
  let numPanels = numberOfPanels.get()
  if (isEqual(scrollHandlerData.prevData, {fullHeight, visibleHeight, currentYOffset, numPanels})) {
    return
  }
  if (fullHeight == 0 || visibleHeight == 0) {
    return
  }
  scrollHandlerData.prevData = {fullHeight, visibleHeight, currentYOffset, numPanels}

  let numRows = numPanels / itemsInRow + 1
  let rowHeight = fullHeight / numRows

  local minVisibleRow = floor(currentYOffset / rowHeight).tointeger()
  minVisibleRow = max(0, minVisibleRow - 1) 
  local maxVisibleRow = minVisibleRow + ceil(visibleHeight / rowHeight).tointeger()
  maxVisibleRow = min(numRows, maxVisibleRow + 1) 
  for (local i = 0; i < itemsPanelData.len(); i++) {
    let row = i / itemsInRow
    let isVisible = row >= minVisibleRow && row <= maxVisibleRow
    itemsPanelData[i].isVisible.set(isVisible)
  }
}

return {
  mkScrollHandlerData
  resetScrollHandlerDataCommon
  updatePanelsVisibilityDataCommon
}
