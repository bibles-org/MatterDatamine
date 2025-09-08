from "%ui/ui_library.nut" import *

let { body_txt } = require("%ui/fonts_style.nut")
let { popupsGen, getPopups } = require("popupsState.nut")
let { textButton } = require("%ui/components/button.nut")
let { BtnBgNormal } = require("%ui/components/colors.nut")
let { safeAreaHorPadding, safeAreaVerPadding } = require("%ui/options/safeArea.nut")
let { bigGap } = require("%ui/viewConst.nut")
let { addInteractiveElement, removeInteractiveElement } = require("%ui/hud/state/interactive_state.nut")
let { areHudMenusOpened } = require("%ui/hud/hud_menus_state.nut")

let HighlightNeutral = Color(230, 230, 100)
let HighlightFailure = Color(255,60,70)

let styles = const {
  def = {  animColor = HighlightNeutral}
  error = { animColor = HighlightFailure}
}
let popupWidth = calc_comp_size({rendObj = ROBJ_TEXT text = "" size=[fontH(1000), SIZE_TO_CONTENT]}.__update(body_txt))[0]
let defPopupBlockPos = [-safeAreaVerPadding.get() - popupWidth-fsh(1), -(safeAreaHorPadding.get()-fsh(1) + 4*bigGap)]
let popupBlockStyle = const {
  hplace = ALIGN_RIGHT
  vplace = ALIGN_BOTTOM
  pos = defPopupBlockPos
}

function popupBlock() {
  let children = []
  let popups = getPopups()
  foreach(idx, popup in popups) {
    let prevVisIdx = popup.visibleIdx.value
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
        textParams = const {
          rendObj = ROBJ_TEXTAREA
          behavior = Behaviors.TextArea
          size = [popupWidth, SIZE_TO_CONTENT]
        }.__update(body_txt)
        key = $"popup_block_{id}"
        animations = const [
          { prop=AnimProp.fillColor, from=style.animColor, to=BtnBgNormal, easing=OutCubic, duration=0.5, play=true }
        ]
      }.__update(areHudMenusOpened.get() ? {} : const { behavior = null }))

      key = $"popup_{id}"
      transform = {}
      animations = const [
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
    watch = [ popupsGen, safeAreaHorPadding ]
    pos
    size = SIZE_TO_CONTENT
    hplace
    vplace
    flow = FLOW_VERTICAL
    children
  }
}

return {popupBlock, defPopupBlockPos}
