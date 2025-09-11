import "%ui/components/faComp.nut" as faComp
import "math" as math
from "%ui/components/colors.nut" import BtnBdNormal, BtnBdActive, BtnBdHover, BtnBgNormal, BtnBgHover, BtnBgActive, ControlBgOpaque
from "%ui/components/modalPopupWnd.nut" import addModalPopup
from "%ui/ui_library.nut" import *

let { language, availableLanguages, nativeLanguageNames, changeLanguage } = require("%ui/state/clientState.nut")

let fillColor = @(sf) sf & S_ACTIVE ? BtnBgActive : (sf & S_HOVER ? BtnBgHover : 0)
let textColor = @(sf) sf & S_ACTIVE ? BtnBdActive : (sf & S_HOVER ? BtnBdHover :  BtnBdNormal)

function mkLanguageOpt(lang, f=false){
  let stateFlags = Watched(0)
  return function(){
    let sf = stateFlags.get()
    return {
      watch = stateFlags
      onClick = @() changeLanguage(lang)
      behavior = Behaviors.Button
      onElemState = @(s) stateFlags.set(s)
      size = f ? FLEX_H : SIZE_TO_CONTENT
      rendObj = ROBJ_BOX
      fillColor = fillColor(sf)
      padding = static [hdpx(5), hdpx(10)]
      children = {
        text = nativeLanguageNames?[lang] ?? lang
        rendObj = ROBJ_TEXT
        color = textColor(sf)
      }
    }
  }
}

let langOpts = availableLanguages.map(@(v) mkLanguageOpt(v))
let langWidth = langOpts.reduce(@(res, a) math.max(res, calc_comp_size(a)[0]), hdpx(100))

function mkSelectLanguage(){
  let stateFlags = Watched(0)
  return function() {
    let sf = stateFlags.get()
    return {
      flow = FLOW_HORIZONTAL
      behavior = Behaviors.Button
      onElemState = @(s) stateFlags.set(s)
      valign = ALIGN_CENTER
      onClick = @(event) addModalPopup(event.targetRect, {
          uid = "LANG_SELECT"
          size = static [langWidth, SIZE_TO_CONTENT]
          children = {flow = FLOW_VERTICAL, size = FLEX_H children = availableLanguages.map(@(v) mkLanguageOpt(v,true))}
          padding = [hdpx(2), 0]
          margin = 0
          popupOffset = hdpx(5)
          popupHalign = ALIGN_LEFT
          fillColor = ControlBgOpaque
        })

      watch = stateFlags
      gap = hdpx(4)
      halign = ALIGN_RIGHT
      rendObj = ROBJ_BOX
      fillColor = fillColor(sf)
      padding = [hdpx(5), hdpx(2)]
      children = [
        @() {
          size = [langWidth, SIZE_TO_CONTENT]
          text = nativeLanguageNames?[language.get()] ?? language.get()
          halign = ALIGN_RIGHT
          watch = language
          rendObj = ROBJ_TEXT
          color = textColor(sf)
        }
        faComp("language.svg", {color=textColor(sf)})
      ]
    }
  }
}

return freeze({
  mkSelectLanguage
})
