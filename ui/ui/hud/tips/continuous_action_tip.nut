from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { body_txt } = require("%ui/fonts_style.nut")
let { mkTextArea, mkText } = require("%ui/components/commonComponents.nut")
let { TextNormal, BtnBgNormal, HudTipFillColor } = require("%ui/components/colors.nut")
let string = require("string")
let { itemIconNoBorder } = require("%ui/components/itemIconComponent.nut")

let progressHeight = hdpxi(60)

let picProgress = Picture($"ui/skin#round_border.svg:{progressHeight}:{progressHeight}:P")

let mkContinuousActionTipIcon = @(itemTemplateName) itemIconNoBorder(itemTemplateName, {
  width = hdpxi(60)
  height = hdpxi(60)
})

let mkContinousActionTipCircle = @(progressProportionWatched, timeLeft) @() {
  size = [progressHeight, progressHeight]
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

let mkContinuousActionTip = @(progressProportionWatched, timeLeftWatched, showItemTemplateWatched, actionNameOverrideWatched = defaultNoOverride) function() {
  let actionNameOverride = actionNameOverrideWatched.get()
  let actionName = actionNameOverride ?? (showItemTemplateWatched.get() != null ? actionNameFromTemplate(showItemTemplateWatched.get()) : null)
  let watch = [showItemTemplateWatched, actionNameOverrideWatched]
  if (showItemTemplateWatched.get() == null)
    return { watch }
  return {
    watch
    rendObj = ROBJ_WORLD_BLUR_PANEL
    size = [SIZE_TO_CONTENT, hdpx(75)]
    minWidth = hdpx(350)
    borderRadius = [hdpx(5), hdpx(300), hdpx(300), hdpx(5)]
    fillColor = HudTipFillColor
    padding = [hdpx(5), hdpx(5), hdpx(5), hdpx(10)]
    valign = ALIGN_CENTER
    flow = FLOW_HORIZONTAL
    gap = hdpx(6)
    children = [
      showItemTemplateWatched.get() != null ? mkContinuousActionTipIcon(showItemTemplateWatched.get()) : null
      mkTextArea(actionName, {
        ellipsis = true
        textOverflowY = TOVERFLOW_LINE
        lineSpacing = -hdpx(4)
        maxHeight = hdpx(56)
      }.__update(body_txt))
      mkContinousActionTipCircle(progressProportionWatched, timeLeftWatched)
    ]
  }
}

return {
  mkContinuousActionTip
}