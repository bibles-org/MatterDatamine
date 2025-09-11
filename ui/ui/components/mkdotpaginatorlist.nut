import "%ui/components/faComp.nut" as faComp
from "math" import ceil

from "%ui/ui_library.nut" import *
from "%ui/components/colors.nut" import SelBdNormal, SelBdHover, SelBdSelected
import "%ui/components/gamepadImgByKey.nut" as gamepadImgByKey
from "%ui/control/active_controls.nut" import isGamepad

#allow-auto-freeze

let defDotSize = hdpx(18)

function mkPaginators(pagesCount, pageWatch, style, flow, parentSf) {
  let content = array(pagesCount).map(function(_v, idx) {
    let isSelected = Computed(@() pageWatch.get() == idx)
    let stateFlags = Watched(0)
    return function() {
      let sf = stateFlags.get()
      return {
        watch = stateFlags
        onElemState = @(s) stateFlags.set(s)
        behavior = Behaviors.Button
        skipDirPadNav = true
        onClick = @() pageWatch.set(idx)
        children = @() {
          watch = isSelected
          children = faComp("circle", {
            padding = hdpx(5)
            fontSize = defDotSize
            color = isSelected.get() ? SelBdSelected
              : sf & S_HOVER ? SelBdHover
              : SelBdNormal
          }.__update(style))
        }
      }
    }
  })
  return function() {
    if (parentSf > 0 && isGamepad.get()) {
      content.insert(0, gamepadImgByKey.mkImageCompByDargKey("J:LT"))
      content.append(gamepadImgByKey.mkImageCompByDargKey("J:RT"))
    }
    return {
      watch = isGamepad
      flow
      children = content
    }
  }
}

function mkHorizPaginatorList(list, itemsPerPage, pageWatch, contentStyle = {}, listStyle = {}) {
  let { style = {}, paginatorStyle = {} } = listStyle
  let pagesCount = max(ceil(list.len().tofloat() / itemsPerPage), 1).tointeger()
  pageWatch.set(clamp(pageWatch.get(), 0, pagesCount-1))
  let content = {
    size = FLEX_H
    children = list
  }.__update(contentStyle)
  let maxContentHeight = calc_comp_size(content)[1]
  function changePage(delta) {
    let newIdx = delta + pageWatch.get()
    if (newIdx < 0 || newIdx >= pagesCount)
      return
    pageWatch.set(newIdx)
  }
  let stateFlags = Watched(0)
  return function() {
    let itemsStart = pageWatch.get() * itemsPerPage
    let itemsEnd = itemsStart + itemsPerPage
    return {
      watch = [pageWatch, stateFlags]
      size = FLEX_H
      flow = FLOW_VERTICAL
      gap = hdpx(10)
      halign = ALIGN_CENTER
      clipChildren = true
      behavior = [Behaviors.TrackMouse, Behaviors.Button]
      onElemState = @(sf) stateFlags.set(sf)
      onMouseWheel = @(mouseEvent) changePage(-mouseEvent.button)
      skipDirPadNav = true
      hotkeys = pagesCount <= 1 || stateFlags.get() == 0 ? null : [
        ["J:RT", { action = @() changePage(1), description = loc("page/next") }],
        ["J:LT", { action = @() changePage(-1), description = loc("page/prev") }]
      ]
      children = [
        {
          size = [flex(), maxContentHeight]
          children = list.slice(itemsStart, itemsEnd)
        }.__update(contentStyle)
        pagesCount <= 1 ? null : mkPaginators(pagesCount, pageWatch, paginatorStyle, FLOW_HORIZONTAL, stateFlags.get())
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
  function changePage(delta) {
    let newIdx = delta + pageWatch.get()
    if (newIdx < 0 || newIdx >= pagesCount)
      return
    pageWatch.set(newIdx)
  }
  let stateFlags = Watched(0)
  return {
    watch = [pageWatch, stateFlags]
    flow = FLOW_HORIZONTAL
    valign = ALIGN_CENTER
    clipChildren = true
    behavior = [Behaviors.TrackMouse, Behaviors.Button]
    onElemState = @(sf) stateFlags.set(sf)
    onMouseWheel = function(mouseEvent) {
      let newIdx = -mouseEvent.button + pageWatch.get()
      if (newIdx < 0 || newIdx >= pagesCount)
        return
      pageWatch.set(newIdx)
    }
    hotkeys = pagesCount <= 1 || stateFlags.get() == 0 ? null : [
      ["J:RT", { action = @() changePage(1), description = loc("page/next") }],
      ["J:LT", { action = @() changePage(-1), description = loc("page/prev") }]
    ]
    children = [
      @() {
        watch = pageWatch
        children = list.slice(itemsStart, itemsEnd)
      }.__update(contentStyle)
      pagesCount <= 1 ? null : mkPaginators(pagesCount, pageWatch, paginatorStyle, FLOW_VERTICAL, stateFlags.get())
    ]
  }.__update(style)
}

return {
  mkHorizPaginatorList
  mkVertPaginatorList
}