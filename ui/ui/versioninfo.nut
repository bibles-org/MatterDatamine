from "%ui/fonts_style.nut" import tiny_txt, basic_text_shadow
from "dagor.time" import get_local_unixtime, unixtime_to_local_timetbl
from "%ui/helpers/remap_nick.nut" import remap_nick

from "%ui/ui_library.nut" import *

let { isProductionCircuit, circuit, version, build_number } = require("%sqGlob/appInfo.nut")
let userInfo = require("%sqGlob/userInfo.nut")
let txtStyle = basic_text_shadow.__merge({fontFxColor = Color(0,0,0,20)})

let monthToStr = {
  [0] = "Jan",
  [1] = "Feb",
  [2] = "Mar",
  [3] = "Apr",
  [4] = "May",
  [5] = "Jun",
  [6] = "Jul",
  [7] = "Aug",
  [8] = "Sep",
  [9] = "Oct",
  [10] = "Nov",
  [11] = "Dec"
}

function mkTime(){
  let {day, month, year} = unixtime_to_local_timetbl(get_local_unixtime())
  return $"{day} {monthToStr?[month] ?? month} {year}"
}

function version_info_text(){
  let buildNum = build_number.get() ?? ""
  let versionNum = version.get() ?? ""
  let userName = userInfo.get()?.name ? $", {remap_nick(userInfo.get()?.name)}" : ""
  local versionInfo = $"{versionNum}, {mkTime()}{userName}"
  if (!isProductionCircuit.get())
    versionInfo = $"{versionInfo}@{circuit.get()}, {buildNum}"
  return {
    text = versionInfo
    rendObj = ROBJ_TEXT
    watch = [circuit, version, isProductionCircuit, userInfo]
    opacity = 0.3
    zOrder = Layers.MsgBox
    padding = static [hdpx(2), hdpx(18)]
  }.__update(txtStyle, tiny_txt)
}

return {
  versionInfo = @(){
    size = flex()
    children = [
      {
        hplace = ALIGN_RIGHT
        vplace = ALIGN_BOTTOM
        children = version_info_text
      }
      version_info_text
    ]
  }
}