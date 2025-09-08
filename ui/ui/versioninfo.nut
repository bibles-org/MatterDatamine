from "%ui/ui_library.nut" import *

let rand = require("%sqstd/rand.nut")()
let { tiny_txt, basic_text_shadow } = require("%ui/fonts_style.nut")
let {isProductionCircuit, circuit, version, build_number} = require("%sqGlob/appInfo.nut")
let {get_local_unixtime, unixtime_to_local_timetbl} = require("dagor.time")
let {remap_nick} = require("%ui/helpers/remap_nick.nut")
let userInfo = require("%sqGlob/userInfo.nut")
let {sessionId} = require("service_info.nut")
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
  local versionInfo = $"Closed Beta version: {versionNum}, {mkTime()}{userName}"
  if (!isProductionCircuit.get())
    versionInfo = $"{versionInfo}@{circuit.get()}, {buildNum}"
  return {
    text = versionInfo
    rendObj = ROBJ_TEXT
    watch = [circuit, version, isProductionCircuit, userInfo]
    opacity = 0.3
    zOrder = Layers.MsgBox
    padding = [hdpx(2), hdpx(18)]
  }.__update(txtStyle, tiny_txt)
}

let mkRandPosWatermark = @() [sw(rand.rint(5, 40)), sh(rand.rint(55, 85))]
let watermark = @() {
    flow = FLOW_VERTICAL
    halign = ALIGN_CENTER
    children = [
      @() { rendObj = ROBJ_TEXT text = "Closed Beta" color = Color(27,27,27,22) fontSize = hdpx(30) }.__update(txtStyle)
      function(){
        let userName = userInfo.get()?.name ? remap_nick(userInfo.get().name) : ""
        return { rendObj = ROBJ_TEXT text = userName color = Color(18,18,18,15)  fontSize = hdpx(14) }.__update(txtStyle)
      }
    ]
}
function alphaWatermark() {
  return {
    size = flex()
    watch = sessionId
    children = {children = watermark pos = mkRandPosWatermark()}
  }
}
return {
  alphaWatermark
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