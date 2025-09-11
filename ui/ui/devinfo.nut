from "%sqstd/string.nut" import tostring_r, utf8ToLower

from "%ui/navState.nut" import addNavScene, removeNavScene, registerNavSceneCtorById
from "dagor.clipboard" import set_clipboard_text
from "%ui/fonts_style.nut" import sub_txt
from "string" import startswith, endswith
from "%ui/components/scrollbar.nut" import makeVertScroll
from "%ui/components/textInput.nut" import textInput

from "%ui/ui_library.nut" import *


let JB = require("%ui/control/gui_buttons.nut")

let wndWidth = sw(80)

let gap = hdpx(5)
let defaultColor = 0xFFA0A0A0
let filterText = mkWatched(persist, "filterText", "")

function tabButton(text, idx, curTab){
  let stateFlags = Watched(0)
  return function(){
    let isSelected = curTab.get() == idx
    let sf = stateFlags.get()
    return {
      children = {
        rendObj = ROBJ_TEXT
        text
        color = isSelected ? Color(255,255,255) : defaultColor
      }.__update(sub_txt)
      behavior = Behaviors.Button
      onClick = @() curTab.set(idx)
      onElemState = @(s) stateFlags.set(s)
      watch = [stateFlags, curTab]
      padding = static [hdpx(5),hdpx(10)]
      rendObj = ROBJ_BOX
      fillColor = sf & S_HOVER ? Color(200,200,200) : isSelected ? Color(0,0,0,0) : Color(0,0,0)
      borderColor = Color(200,200,200)
      borderWidth = isSelected ? [hdpx(1), hdpx(1), 0, hdpx(1)] : [0,0, hdpx(1), 0]
    }
  }
}
let hGap = freeze({rendObj = ROBJ_SOLID size = static [hdpx(1), hdpx(10)] vplace = ALIGN_CENTER color = Color(40,40,40,40)})
let mkTabs = @(tabs, curTab) @() {
  watch = curTab
  children = wrap(
    tabs.map(@(_, idx) tabButton(tabs[idx].id, idx, curTab)),
    {
      width = wndWidth - gap - hdpx(250), 
      vGap = gap
      hGap
    })
}

let textArea = @(text) {
  size = FLEX_H
  color = defaultColor
  rendObj=ROBJ_TEXTAREA
  behavior = Behaviors.TextArea
  preformatted = FMT_AS_IS 
  text
}.__update(sub_txt)

let dataToText = @(data) tostring_r(data, { maxdeeplevel = 10, compact = false })

function defaultRowFilter(rowData, rowKey, txt) {
  if (txt == "")
    return true
  if (startswith(txt, "\"") && endswith(txt, "\""))
    return txt.slice(1,-1) == rowKey.tostring()
  else if (startswith(txt, "\""))
    return startswith(rowKey.tostring(), txt.slice(1))
  else if (endswith(txt, "\""))
    return endswith(rowKey.tostring(), txt.slice(0,-1))

  if (utf8ToLower(rowKey.tostring()).contains(txt))
    return true
  if (rowData == null)
    return false
  let dataType = type(rowData)
  if (dataType == "array" || dataType == "table") {
    foreach(key, value in rowData)
      if (defaultRowFilter(value, key, txt))
        return true
    return false
  }
  return utf8ToLower(rowData.tostring()).indexof(txt) != null
}

function filterData(data, curLevel, filterLevel, rowFilter, countLeft) {
  let isArray = type(data) == "array"
  if (!isArray && type(data) != "table")
    return rowFilter(data, "") ? data : null

  let res = isArray ? [] : {}
  foreach(key, rowData in data) {
    local curData = rowData
    if (filterLevel <= curLevel) {
      let isVisible = countLeft.get() >= 0 && rowFilter(rowData, key)
      if (!isVisible)
        continue
      countLeft.set(countLeft.get() - 1)
      if (countLeft.get() < 0)
        break
    }
    else {
      curData = filterData(rowData, curLevel + 1, filterLevel, rowFilter, countLeft)
      if (curData == null)
        continue
    }

    if (isArray)
      res.append(curData)
    else
      res[key] <- curData
    if (countLeft.get() < 0)
      break
    continue
  }
  return (curLevel == 0 || res.len() > 0) ? res : null
}

let mkFilter = @(rowFilterBase, filterArr) filterArr.len() == 0 ? @(_rowData, _key) true
  : function(rowData, key) {
      foreach(anyList in filterArr) {
        local res = true
        foreach(andText in anyList)
          if (!rowFilterBase(rowData, key, andText)) {
            res = false
            break
          }
        if (res)
          return true
      }
      return false
    }

local mkInfoBlockKey = 0

function mkInfoBlock(curTabIdx, tabs) {
  let curTabV = tabs?[curTabIdx]
  let dataWatch = curTabV?.data
  let textHelp = curTabV?.helpText
  let textWatch = Watched("")
  let recalcText = function() {
    let filterArr = utf8ToLower(filterText.get()).split("||").map(@(v) v.split("&&"))
    let rowFilterBase = curTabV?.rowFilter ?? defaultRowFilter
    let rowFilter = mkFilter(rowFilterBase, filterArr)
    let countLeft = Watched(curTabV?.maxItems ?? 100)
    let resData = filterData(dataWatch?.get(), 0, curTabV?.recursionLevel ?? 0, rowFilter, countLeft)
    local resText = dataToText(resData)
    if (countLeft.get() < 0)
      resText = $"{resText}\n...... has more items ......"
    textWatch.set(resText)
  }

  function timerRestart(_) {
    gui_scene.clearTimer(recalcText)
    gui_scene.setTimeout(0.8, recalcText)
  }
  filterText.subscribe(timerRestart)

  mkInfoBlockKey++
  function copytoCb() {
    log_for_user("copied to clipboard")
    set_clipboard_text(textWatch.get())
  }
  return @() {
    watch = [textWatch]
    key = mkInfoBlockKey
    size = FLEX_H
    flow = FLOW_VERTICAL
    children = [
      textArea(textHelp)
      textArea(textWatch.get())
    ]
    hotkeys = [["L.Ctrl C", {action = copytoCb}]]
    onAttach = recalcText
    function onDetach() {
      gui_scene.clearTimer(recalcText)
      filterText.unsubscribe(timerRestart)
    }
  }
}

let mkCurInfo = @(curTab, tabs) @() {
  watch = curTab
  size = FLEX_H
  children = mkInfoBlock(curTab.get(), tabs)
}

let debugWnd = @(tabs, curTab) {
  size = [wndWidth + 2 * gap, sh(90)]
  stopMouse = true
  padding = gap
  vplace = ALIGN_CENTER
  hplace = ALIGN_CENTER
  rendObj = ROBJ_SOLID
  color = Color(30,30,30,120)
  flow = FLOW_VERTICAL
  gap

  children = [
    {
      size = FLEX_H
      flow = FLOW_HORIZONTAL
      valign = ALIGN_TOP
      children = [
        mkTabs(tabs, curTab)
        textInput(filterText, {
          placeholder = "filter..."
          textmargin = hdpx(5)
          margin = 0
          onChange = @(value) filterText.set(value)
          onEscape = @() filterText.set("")
        }.__update(sub_txt))
      ]
    }
    makeVertScroll(mkCurInfo(curTab, tabs))
  ]
}
const DebugWndId = "debugWnd"
let state = []

let curTab = mkWatched(persist, "curTab", 0)
function openDebugWnd() {
  let close = @() removeNavScene(DebugWndId)

  return {
    size = static [sw(100), sh(100)]
    rendObj = ROBJ_WORLD_BLUR_PANEL
    fillColor = Color(0,0,0,220)
    onClick = close
    behavior = Behaviors.Button
    skipDirPadNav = true
    children = debugWnd(state, curTab)
    hotkeys = [[$"^{JB.B} | Esc", { action = close, description = loc("Cancel") }]]
  }
}

let usedKeys = {}

function addTabToDevInfo(id, data, helpText=null){
  if (id in usedKeys) {
    state[usedKeys[id]] = {id, data, helpText}
  }
  else {
    usedKeys[id] <- state.len()
    state.append({id, data, helpText})
  }
}

registerNavSceneCtorById(DebugWndId, openDebugWnd)

return {
  addTabToDevInfo,
  openDevInfo = @() addNavScene(DebugWndId)
}