from "%ui/fonts_style.nut" import h2_txt, body_txt
from "%ui/components/commonComponents.nut" import mkDescTextarea, mkText
from "%ui/components/msgbox.nut" import showMessageWithContent
from "%ui/components/colors.nut" import BtnTextNormal, BtnTextHover
from "%ui/options/onlineSettings.nut" import onlineSettingUpdated, settings
from "%ui/components/cursors.nut" import setTooltip
import "%ui/components/faComp.nut" as faComp
import "console" as console

from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

const NEXUS_TOTORIAL_SEEN = "hasSeenNexusTutorial"

function mkTutorialRow(image, text, isReversed = false) {
  let content = [
    {
      rendObj = ROBJ_IMAGE
      size = [hdpxi(700), hdpx(250)]
      keepAspect = KEEP_ASPECT_FILL
      image = Picture($"ui/uiskin/{image}.avif")
    }
    mkDescTextarea(text, { halign = isReversed ? ALIGN_RIGHT : ALIGN_LEFT }.__merge(body_txt))
  ]
  if (isReversed)
    content.reverse()
  return {
    size = FLEX_H
    flow = FLOW_HORIZONTAL
    gap = static hdpx(20)
    halign = ALIGN_CENTER
    children = content
  }
}

function showNexusTutorial() {
  showMessageWithContent({
    content = {
      size = [min(hdpx(1800), sw(80)), SIZE_TO_CONTENT]
      flow = FLOW_VERTICAL
      gap = static hdpx(20)
      children = [
        mkDescTextarea(loc("nexus/tutorialTitle"), { halign = ALIGN_CENTER }.__merge(h2_txt))
        mkTutorialRow("nexus_tutorial_1", loc("nexus/capitalDesc"))
        mkTutorialRow("nexus_tutorial_2", loc("nexus/worldFightDesc"), true)
        mkTutorialRow("nexus_tutorial_3", loc("nexus/mercenary"))
      ]
    }
  })
}

function checkShowNexusTutorial() {
  if (!onlineSettingUpdated.get() || settings.get()?[NEXUS_TOTORIAL_SEEN])
    return
  settings.mutate(@(v) v[NEXUS_TOTORIAL_SEEN] <- true)
  showNexusTutorial()
}

function mkNexusBriefingButton() {
  let stateFlags = Watched(0)
  return @() {
    watch = stateFlags
    size = FLEX_H
    onElemState = @(sf) stateFlags.set(sf)
    flow = FLOW_HORIZONTAL
    gap = static hdpx(4)
    behavior = Behaviors.Button
    onClick = showNexusTutorial
    halign = ALIGN_RIGHT
    valign = ALIGN_CENTER
    onHover = @(on) setTooltip(on ? loc("nexus/briefingShow") : null)
    skipDirPadNav = true
    children = [
      mkText(loc("nexus/briefing"), { color = stateFlags.get() & S_HOVER ? BtnTextHover : BtnTextNormal })
      faComp("question-circle", {
        fontSize = hdpxi(16)
        color = stateFlags.get() & S_HOVER ? BtnTextHover : BtnTextNormal
      })
    ]
  }
}

console.register_command(@() settings.mutate(@(v) v[NEXUS_TOTORIAL_SEEN] <- false), "nexus.tutorialClear")

return {
  checkShowNexusTutorial
  mkNexusBriefingButton
}
