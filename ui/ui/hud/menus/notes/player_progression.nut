from "%sqstd/string.nut" import utf8ToUpper

from "%ui/fonts_style.nut" import h1_txt, h2_txt, sub_txt, giant_txt
from "%ui/components/colors.nut" import InfoTextValueColor, RedWarningColor
from "%ui/components/commonComponents.nut" import mkText, mkTextArea, mkTooltiped
from "%ui/mainMenu/clonesMenu/clonesMenuCommon.nut" import getChronogeneFullBodyPresentation, mkChronogeneDoll, mkChronogeneSlot
import "%ui/components/colorize.nut" as colorize
from "%ui/helpers/remap_nick.nut" import remap_nick
from "%ui/mainMenu/menus/options/player_interaction_option.nut" import isStreamerMode, playerRandName

from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { playerProfileExperience, playerExperienceToLevel, allPassiveChronogenes } = require("%ui/profile/profileState.nut")
let { equipment } = require("%ui/hud/state/equipment.nut")
let { allItems } = require("%ui/state/allItems.nut")
let { recognitionImagePattern } = require("%ui/hud/menus/components/inventoryItem.nut")
let userInfo = require("%sqGlob/userInfo.nut")
let { isOnboarding } = require("%ui/hud/state/onboarding_state.nut")

#allow-auto-freeze

let levelLineExpColor = Color(186, 186, 186, 255)
let levelLineExpBackgroundColor = Color(0, 0, 0, 50)

let playerCurrentLevel = Computed(function() {
  if (playerProfileExperience.get() != 0
    && playerProfileExperience.get() == playerExperienceToLevel.get()?[playerExperienceToLevel.get().len() - 1]
  )
    return playerExperienceToLevel.get().len() - 1
  for (local i = 0; i < playerExperienceToLevel.get().len(); i++) {
    if (playerProfileExperience.get() < playerExperienceToLevel.get()[i]) {
      return i
    }
  }
  return 0
})

let currentPlayerLevelNeedExp = Computed(function() {
  let needExp = playerExperienceToLevel.get()?[playerCurrentLevel.get()] ?? 0
  let prevExp = playerExperienceToLevel.get()?[playerCurrentLevel.get()-1] ?? 0

  return needExp - prevExp
})

let currentPlayerLevelHasExp = Computed(function() {
  let prevExp = playerExperienceToLevel.get()?[playerCurrentLevel.get()-1] ?? 0
  return playerProfileExperience.get() - prevExp
})

let playerLevelExpLine = function() {
  let levelRatio = currentPlayerLevelHasExp.get().tofloat() / currentPlayerLevelNeedExp.get().tofloat()

  return {
    watch = [ currentPlayerLevelHasExp, currentPlayerLevelNeedExp ]
    size = static [ flex(), hdpx(10) ]
    children = [
      {
        rendObj = ROBJ_SOLID
        size = flex()
        color = levelLineExpBackgroundColor
      }
      {
        rendObj = ROBJ_SOLID
        size = [ pw(clamp(100, 0, levelRatio * 100)), flex() ]
        color = levelLineExpColor
      }
    ]
  }
}

let levelBlock = {
  size = FLEX_H
  flow = FLOW_VERTICAL
  gap = hdpx(12)
  vplace = ALIGN_CENTER
  children = [
    {
      size = FLEX_H
      flow = FLOW_VERTICAL
      gap = hdpx(4)
      children = [
        playerLevelExpLine
        {
          size = FLEX_H
          children = [
            @() {
              watch = currentPlayerLevelHasExp
              children = mkText($"{currentPlayerLevelHasExp.get()} XP", h2_txt)
            }
            @() {
              watch = currentPlayerLevelNeedExp
              hplace = ALIGN_RIGHT
              children = mkText($"{currentPlayerLevelNeedExp.get()} XP", h2_txt)
            }
          ]
        }
      ]
    }
  ]
}

function mainChronogeneImage() {
  let mainChronogene = equipment.get()?.chronogene_primary_1

  local iconName = mainChronogene?.iconName
  let templateName = mainChronogene?.itemTemplate
  if (iconName == null && templateName) {
    let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(templateName)
    iconName = template.getCompValNullable("animchar__res") ?? ""
  }
  return {
    watch = equipment
    vplace = ALIGN_CENTER
    padding = static [0, hdpx(10)]
    children = mkChronogeneDoll(templateName, [hdpxi(350), hdpxi(700)],
    getChronogeneFullBodyPresentation(templateName))
  }
}

let operativeData = {
  size = FLEX_H
  flow = FLOW_VERTICAL
  gap = hdpx(10)
  children = [
    mkText(loc("playerProfile/shortTitle"), h1_txt)
    {
      size = FLEX_H
      flow = FLOW_VERTICAL
      gap = hdpx(2)
      children = [
        @() {
          watch = [userInfo, isStreamerMode, playerRandName]
          size = FLEX_H
          children = mkTextArea(loc("playerProfile/name",
            { name = colorize(InfoTextValueColor, remap_nick(isStreamerMode.get() ? playerRandName.get() : userInfo.get().name)) }), h2_txt)
        }
        @() {
          watch = playerCurrentLevel
          size = FLEX_H
          children = mkTextArea(loc("playerProfile/levelTitle", { level = colorize(InfoTextValueColor, playerCurrentLevel.get() + 1) }), h2_txt)
        }
      ]
    }
  ]
}

let playerHeader = {
  size = FLEX_H
  flow = FLOW_VERTICAL
  gap = hdpx(10)
  children = [
    operativeData
    levelBlock
  ]
}

let visualParams = static {
  slotSize = [hdpxi(100), hdpxi(100)]
  height = hdpxi(80)
  width = hdpxi(80)
}

function agencyRewards() {
  let allPassiveChronogenesTemplates = allPassiveChronogenes.get().keys()
  let allRewardsCount = allPassiveChronogenes.get().values().reduce(@(acc, v) acc+=v, 0)
  #forbid-auto-freeze
  let allRewards = []

  foreach (item in allItems.get()) {
    if (allPassiveChronogenesTemplates.contains(item.templateName)) {
      allRewards.append(mkChronogeneSlot(item, visualParams))
    }
  }
  for (local i = allRewards.len(); i < allRewardsCount; i++) {
    allRewards.append({
      size = static [hdpxi(100), hdpxi(100)]
      children = mkTooltiped(recognitionImagePattern, loc("player_progression/unknownChronogenesTooltip"), { size = flex() })
    })
  }

  let rewardsLists = []
  function mkColumn(itemInRow) {
    return {
      flow = FLOW_HORIZONTAL
      gap = hdpx(10)
      children = itemInRow
    }
  }
  let itemsPerRow = 9
  for (local i=0; i < allRewards.len(); i+=itemsPerRow) {
    rewardsLists.append(mkColumn(allRewards.slice(i, i + itemsPerRow)))
  }
  #allow-auto-freeze
  return {
    watch = [ allItems, allPassiveChronogenes ]
    size = FLEX_H
    hplace = ALIGN_CENTER
    halign = ALIGN_CENTER
    flow = FLOW_VERTICAL
    gap  = hdpx(10)
    children = [
      mkText(loc("player_progression/rewardBlockTitle"),  h1_txt)
      mkTextArea(loc("player_progression/rewardBlockExplain"), { hplace = ALIGN_CENTER, halign = ALIGN_CENTER }.__update(sub_txt))
      {
        size = FLEX_H
        flow = FLOW_VERTICAL
        gap = hdpx(10)
        padding = hdpx(20)
        halign = ALIGN_CENTER
        children = rewardsLists
      }
    ]
  }
}

let dataContent = {
  size = static [hdpx(990), flex()]
  flow = FLOW_VERTICAL
  gap = hdpx(20)
  valign = ALIGN_CENTER
  children = [
    playerHeader
    agencyRewards
  ]
}

let unavailableProfileBlock = {
  size = FLEX_H
  flow = FLOW_VERTICAL
  gap = sh(20)
  halign = ALIGN_CENTER
  children = [
    mkTextArea(loc("playerProfile/unavailable"), {
      vplace = ALIGN_CENTER
      halign = ALIGN_CENTER
    }.__update(h2_txt))
    {
      rendObj = ROBJ_FRAME
      padding = hdpx(20)
      borderWidth = hdpx(4)
      color = RedWarningColor
      transform = { rotate = -45 }
      children = mkText(utf8ToUpper(loc("playerProfile/classified")),
        { color = RedWarningColor, fontFx = null }.__update(giant_txt))
    }
  ]
}

let playerProgression = @() @() {
  watch = isOnboarding
  size = FLEX_H
  flow = FLOW_HORIZONTAL
  gap = hdpx(50)
  halign = ALIGN_CENTER
  children = isOnboarding.get() ? unavailableProfileBlock : [
    mainChronogeneImage
    dataContent
  ]
}

return {
  playerProgression
  currentPlayerLevelHasExp
  currentPlayerLevelNeedExp
  playerCurrentLevel
  levelLineExpColor
  levelLineExpBackgroundColor
}