from "%ui/fonts_style.nut" import body_txt
from "%ui/components/commonComponents.nut" import mkTextArea, mkText
from "%ui/components/colors.nut" import TextNormal, BtnBgNormal, HudTipFillColor, HUD_TIPS_HOTKEY_FG
from "%ui/components/gamepadImgByKey.nut" import mkImageComp, keysImagesMap
import "string" as string
from "%ui/hud/state/spectator_state.nut" import isSpectator
from "%ui/components/itemIconComponent.nut" import itemIconNoBorder

from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { isGamepad } = require("%ui/control/active_controls.nut")

let progressHeight = static hdpxi(65)
let mouseIconHeight = static hdpxi(16)

let picProgress = Picture($"ui/skin#round_border.svg:{progressHeight}:{progressHeight}:P")

let mkContinuousActionTipIcon = @(itemTemplateName) itemIconNoBorder(itemTemplateName, {
  width = static hdpxi(60)
  height = static hdpxi(60)
})

let mkContinousActionTipCircle = @(progressProportionWatched, timeLeft) @() {
  size = static [progressHeight, progressHeight]
  hplace = ALIGN_RIGHT
  children = [
    @() {
      watch = progressProportionWatched
      rendObj = ROBJ_PROGRESS_CIRCULAR
      size = progressHeight
      fgColor = TextNormal
      bgColor = BtnBgNormal
      fValue = progressProportionWatched.get()
      image = picProgress
    }
    @() {
      watch = timeLeft
      vplace = ALIGN_CENTER
      hplace = ALIGN_CENTER
      children = mkText($"{string.format("%.1f", max(timeLeft.get(), 0.0))}")
    }
  ]
}

let itemNameFromTemplate = function(templateName) {
  let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(templateName)
  return loc(template.getCompValNullable("item__name"))
}

let actionNameFromTemplate = function(templateName) {
  let itemName = itemNameFromTemplate(templateName)
  return itemName
}

let defaultNoOverride = Watched(null)

let mkContinuousActionTip = @(progressProportionWatched, timeLeftWatched, showItemTemplateWatched,
  actionNameOverrideWatched = defaultNoOverride, showInterrupt = true
) function() {
  let actionNameOverride = actionNameOverrideWatched.get()
  let actionName = actionNameOverride ?? (showItemTemplateWatched.get() != null ? actionNameFromTemplate(showItemTemplateWatched.get()) : null)
  let watch = [showItemTemplateWatched, actionNameOverrideWatched]
  if (showItemTemplateWatched.get() == null)
    return { watch }
  return {
    watch
    flow = FLOW_VERTICAL
    gap = static hdpx(4)
    children = [
      {
        rendObj = ROBJ_WORLD_BLUR_PANEL
        size = static [SIZE_TO_CONTENT, hdpx(75)]
        minWidth = static hdpx(350)
        borderRadius = static [hdpx(5), hdpx(75), hdpx(75), hdpx(5)]
        fillColor = HudTipFillColor
        padding = static hdpx(5)
        valign = ALIGN_CENTER
        flow = FLOW_HORIZONTAL
        gap = static hdpx(6)
        children = [
          showItemTemplateWatched.get() != null ? mkContinuousActionTipIcon(showItemTemplateWatched.get()) : null
          mkTextArea(actionName, {
            ellipsis = true
            textOverflowY = TOVERFLOW_LINE
            lineSpacing = static -hdpx(4)
            maxHeight = static hdpx(56)
          }.__update(body_txt))
          mkContinousActionTipCircle(progressProportionWatched, timeLeftWatched)
        ]
      }
      function() {
        if (!showInterrupt)
          return null
        if (isSpectator.get())
          return { watch = isSpectator }
        let interruptHotkey = isGamepad.get() ? "J:Y" : "LMB"
        return {
          watch = [keysImagesMap, isGamepad, isSpectator]
          rendObj = ROBJ_WORLD_BLUR_PANEL
          padding = static [0, hdpx(4)]
          hplace = ALIGN_CENTER
          flow = FLOW_HORIZONTAL
          gap = static hdpx(4)
          valign = ALIGN_CENTER
          children = [
            mkImageComp(keysImagesMap.get()?[interruptHotkey], {
              height = mouseIconHeight,
              color = HUD_TIPS_HOTKEY_FG
            })
            mkText(loc("action/interrupt"))
          ]
        }
      }
    ]
  }
}

return {
  mkContinuousActionTip
}