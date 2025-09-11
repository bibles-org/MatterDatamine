from "%ui/fonts_style.nut" import body_txt
from "%ui/popup/popupsState.nut" import getPopups
from "%ui/components/button.nut" import textButton
from "%ui/components/colors.nut" import BtnBgNormal
from "%ui/viewConst.nut" import bigGap
from "%ui/hud/state/interactive_state.nut" import addInteractiveElement, removeInteractiveElement

from "%ui/ui_library.nut" import *

let { popupsGen } = require("%ui/popup/popupsState.nut")
let { safeAreaHorPadding, safeAreaVerPadding } = require("%ui/options/safeArea.nut")
let { areHudMenusOpened } = require("%ui/hud/hud_menus_state.nut")

let HighlightNeutral = Color(230, 230, 100)
let HighlightFailure = Color(255,60,70)

let styles = static {
  def = {  animColor = HighlightNeutral}
  error = { animColor = HighlightFailure}
}
let popupWidth = calc_comp_size({rendObj = ROBJ_TEXT text = "" size=[fontH(1000), SIZE_TO_CONTENT]}.__update(body_txt))[0]
let defPopupBlockPos = [-safeAreaVerPadding.get() - popupWidth-fsh(1), -(safeAreaHorPadding.get()-fsh(1) + 4*bigGap)]
let popupBlockStyle = static {
  hplace = ALIGN_RIGHT
  vplace = ALIGN_BOTTOM
  pos = defPopupBlockPos
}

function popupBlock() {
  let children = []
  let popups = getPopups()
  foreach(idx, popup in popups) {
    let prevVisIdx = popup.visibleIdx.get()
    let curVisIdx = popups.len() - idx
    if (prevVisIdx != curVisIdx) {
      let prefix = curVisIdx > prevVisIdx ? "popupMoveTop" : "popupMoveBottom"
      anim_start(prefix + popup.id)
    }

    let style = styles?[popup.styleName] ?? styles.def

    let id = popup.id
    let visibleIdx = popup.visibleIdx
    if (!areHudMenusOpened.get())
      removeInteractiveElement("popups")
    children.append({
      size = SIZE_TO_CONTENT
      onAttach = @() areHudMenusOpened.get() ? addInteractiveElement("popups") : null
      onDetach = @() removeInteractiveElement("popups")
      children = textButton(popup.text, popup.click, {
        margin = 0
        textParams = static {
          rendObj = ROBJ_TEXTAREA
          behavior = Behaviors.TextArea
          size = [popupWidth, SIZE_TO_CONTENT]
        }.__update(body_txt)
        key = $"popup_block_{id}"
        animations = [
          { prop=AnimProp.fillColor, from=style.animColor, to=BtnBgNormal, easing=OutCubic, duration=0.5, play=true }
        ]
      }.__update(areHudMenusOpened.get() ? {} : static { behavior = null }))

      key = $"popup_{id}"
      transform = {}
      animations = [
        { prop=AnimProp.opacity, from=0.0, to=1.0, duration=0.5, play=true, easing=OutCubic }
        { prop=AnimProp.translate, from=[0,100], to=[0, 0], duration=0.3, trigger = $"popupMoveTop{id}", play = true, easing=OutCubic }
        { prop=AnimProp.translate, from=[0,-100], to=[0, 0], duration=0.3, trigger = $"popupMoveBottom{id}", easing=OutCubic }
      ]

      behavior = areHudMenusOpened.get() ? Behaviors.RecalcHandler : null
      onRecalcLayout = @(_initial) visibleIdx.set(curVisIdx)
    })
  }
  let {hplace, vplace, pos = defPopupBlockPos} = popupBlockStyle
  return {
    watch = [ popupsGen, safeAreaHorPadding, areHudMenusOpened ]
    pos
    size = SIZE_TO_CONTENT
    hplace
    vplace
    flow = FLOW_VERTICAL
    children
  }
}

return {popupBlock, defPopupBlockPos}
