from "%dngscripts/platform.nut" import is_pc
from "%ui/fonts_style.nut" import fontawesome
import "%ui/components/colors.nut" as colors
from "%ui/components/modalPopupWnd.nut" import addModalPopup
from "%ui/components/scrollbar.nut" import makeVertScroll
import "dagor.debug" as dagorDebug
import "dagor.system" as dagorSys
from "%ui/ui_library.nut" import *
import "%ui/components/fontawesome.map.nut" as fa

let { platformId } = require("%dngscripts/platform.nut")


let errors = mkWatched(persist, "errors", [])
let haveUnseenErrors = mkWatched(persist, "haveUnseenErrors", false)

let maxErrorsToShow = 8

function addError(tag, logstring, timestamp, text){
  local curErrors = clone errors.get()

  if (curErrors.len() >= maxErrorsToShow)
    curErrors = curErrors.slice(-(maxErrorsToShow-1))
  curErrors.append({timestamp = timestamp, logstring = logstring, tag=tag, text=text})
  errors.set(curErrors)
  haveUnseenErrors.set(true)
}

function mkSimpleCb(locid) {
  return function(tag, logstring, timestamp){
    addError(tag, logstring, timestamp, "logerr/{0}{1}".subst(is_pc ? "" : $"{platformId}/", locid))
  }
}

dagorDebug.clear_logerr_interceptors()

let tagsForPopup = ["web-vromfs:", "[disk]", "[network]"]
tagsForPopup.map(@(tag) dagorDebug.register_logerr_interceptor([tag], mkSimpleCb(tag)))

if (dagorSys.DBGLEVEL <= 0) {
  let clientlog = require("clientlog")
  function sendErrorInRelease(_tag, logstring, _timestamp) {
    clientlog.send_error_log(logstring, {
      attach_game_log = false,
      meta = {}
    })
  }
  dagorDebug.register_logerr_interceptor(["[frp:error]"], sendErrorInRelease)
}

local counter = 0
function test_log_errors(){
  counter++
  errors.set(clone errors.get())
  dagorDebug.logerr($"web-vromfs: [network] {counter}")
}
console_register_command(@()gui_scene.setInterval(2.0, test_log_errors), "ui.test_logerrs")

function textarea(text, logstring) {
  local onClick

  if (dagorSys.DBGLEVEL > 0) {
    onClick = function onClickImpl() {
      addModalPopup( static [sw(50),sh(0)], {
        size = static [sw(100), sh(100)]
        uid = "LOGGER_ERROR_DETAILS"
        padding = 0
        popupOffset = 0
        margin = 0
        children = {
          size = flex()
          rendObj = ROBJ_TEXTAREA
          behavior = Behaviors.TextArea
          text = logstring
          color = Color(220,220,220,220)
          textColor = Color(220,220,220,220)
        }
        popupBg = static { rendObj = ROBJ_WORLD_BLUR_PANEL, color = Color(220,220,220,220) fillColor = Color(0,0,0,180)}
      })
    }
  }

  let stateFlags = Watched(0)
  return function() {
    let sf = stateFlags.get()
    return {
      watch = stateFlags
      rendObj = ROBJ_TEXTAREA
      behavior = static [Behaviors.TextArea, Behaviors.Button]
      text = loc(text,loc("unknown error"))
      color = (sf & S_HOVER) ? Color(220,220,220) : Color(128,128,128)
      size = FLEX_H
      onClick = onClick
      skipDirPadNav = true
      onElemState = @(s) stateFlags.set(s)
    }
  }
}


let header = @(text) {
  rendObj = ROBJ_SOLID
  size = FLEX_H
  padding = hdpx(10)
  color = colors.WindowHeader
  children = {rendObj = ROBJ_TEXT text = text color = Color(128,128,128) size = FLEX_H}
}






function errors_list(){
  return {
    watch = errors
    flow = FLOW_VERTICAL
    size = FLEX_H
    padding = hdpx(20)
    children = errors.get().map(@(v) textarea(v.text, v.logstring))
    gap = hdpx(20)
  }
}
function onClick(event){
  addModalPopup(event.targetRect,
  {
    size = static [sw(45), sh(40)]
    uid = "MODAL_LOGERR"
    padding = 0
    popupFlow = FLOW_VERTICAL
    popupValign = ALIGN_CENTER
    hplace = ALIGN_CENTER
    flow= FLOW_VERTICAL
    popupOffset = 0
    margin = 0
    onDetach = @() haveUnseenErrors.set(false)
    onAttach = @() haveUnseenErrors.set(false)
    children = [
      header(loc("logerrWnd_hdr", "Warnings"))
      {
        size = flex()
        clipChildren = true
        children = makeVertScroll(errors_list)
      }
    ]
    popupBg = { rendObj = ROBJ_WORLD_BLUR_PANEL, color = Color(220,220,220,220) fillColor = Color(0,0,0,180)}
  })
}
function mkBtn(){
  let stateFlags = Watched(0)
  let onElemState = @(sf) stateFlags.set(sf)
  return function() {
    let sf = stateFlags.get()
    return {
      behavior = Behaviors.Button
      onClick = onClick
      watch = stateFlags
      rendObj = ROBJ_INSCRIPTION
      validateStaticText = false
      onElemState = onElemState
      text = fa["exclamation-triangle"]
      fontSize = hdpx(12)
      font = fontawesome.font
      color = (sf & S_HOVER) ? Color(255,255,255) : Color(245, 100, 30, 100)
    }
  }
}

let errBtn = mkBtn()
function errorBtn(){
  return {
    watch = [haveUnseenErrors,errors]
    size = SIZE_TO_CONTENT
    children = haveUnseenErrors.get() ? errBtn : null
    padding = hdpx(5)
  }
}

return errorBtn
