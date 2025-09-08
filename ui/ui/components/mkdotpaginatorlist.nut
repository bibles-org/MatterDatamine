from "%ui/ui_library.nut" import *
from "%ui/components/colors.nut" import BtnBdNormal, BtnBdHover, BtnBdSelected


let faComp = require("%ui/components/faComp.nut")
let { ceil } = require("math")

let defDotSize = hdpx(18)

let mkPaginators = @(pagesCount, pageWatch, style, flow) {
  flow
  children = array(pagesCount).map(function(_v, idx) {
    let isSelected = Computed(@() pageWatch.get() == idx)
    return watchElemState(@(sf) {
      behavior = Behaviors.Button
      onClick = @() pageWatch.set(idx)
      children = @() {
        watch = isSelected
        children = faComp(isSelected.get() ? "circle" : "circle-o", {
          padding = hdpx(5)
          fontSize = defDotSize
          color = isSelected.get() ? BtnBdNormal
            : sf & S_HOVER ? BtnBdHover
            : BtnBdNormal
        }.__update(style))
      }
    })
  })
}

function mkHorizPaginatorList(list, itemsPerPage, pageWatch, contentStyle = {}, listStyle = {}) {
  let { style = {}, paginatorStyle = {} } = listStyle
  let pagesCount = max(ceil(list.len().tofloat() / itemsPerPage), 1).tointeger()
  pageWatch.set(clamp(pageWatch.value, 0, pagesCount-1))
  let content = {
    size = [flex(), SIZE_TO_CONTENT]
    children = list
  }.__update(contentStyle)
  let maxContentHeight = calc_comp_size(content)[1]
  return function() {
    let itemsStart = pageWatch.get() * itemsPerPage
    let itemsEnd = itemsStart + itemsPerPage
    return {
      watch = pageWatch
      size = [flex(), SIZE_TO_CONTENT]
      flow = FLOW_VERTICAL
      gap = hdpx(10)
      halign = ALIGN_CENTER
      clipChildren = true
      behavior = Behaviors.TrackMouse
      onMouseWheel = function(mouseEvent) {
        let newIdx = -mouseEvent.button + pageWatch.get()
        if (newIdx < 0 || newIdx >= pagesCount)
          return
        pageWatch.set(newIdx)
      }
      children = [
        {
          size = [flex(), maxContentHeight]
          children = list.slice(itemsStart, itemsEnd)
        }.__update(contentStyle)
        pagesCount <= 1 ? null : mkPaginators(pagesCount, pageWatch, paginatorStyle, FLOW_HORIZONTAL)
      ]
    }.__update(style)
  }
}

let mkVertPaginatorList = @(list, itemsPerPage, pageWatch, contentStyle = {}, listStyle = {})
function() {
  let { style = {}, paginatorStyle = {} } = listStyle
  let pagesCount = ceil(list.len().tofloat() / itemsPerPage).tointeger()
  let itemsStart = pageWatch.get() * itemsPerPage
  let itemsEnd = itemsStart + itemsPerPage
  return {
    watch = pageWatch
    flow = FLOW_HORIZONTAL
    valign = ALIGN_CENTER
    clipChildren = true
    behavior = Behaviors.TrackMouse
    onMouseWheel = function(mouseEvent) {
      let newIdx = -mouseEvent.button + pageWatch.get()
      if (newIdx < 0 || newIdx >= pagesCount)
        return
      pageWatch.set(newIdx)
    }
    children = [
      @() {
        watch = pageWatch
        children = list.slice(itemsStart, itemsEnd)
      }.__update(contentStyle)
      pagesCount <= 1 ? null : mkPaginators(pagesCount, pageWatch, paginatorStyle, FLOW_VERTICAL)
    ]
  }.__update(style)
}

return {
  mkHorizPaginatorList
  mkVertPaginatorList
}