from "%ui/components/commonComponents.nut" import mkText
from "%ui/fonts_style.nut" import fontawesome
from "%ui/components/scrollbar.nut" import makeVertScrollExt
from "%ui/components/colors.nut" import TextNormal, BtnBgSelected, BtnBgHover, BtnBgNormal, BtnBgActive
from "%ui/helpers/time.nut" import secondsToStringLoc, secondsToTime
from "%ui/hud/map/map_extraction_points.nut" import extractionIcon
from "string" import endswith, format
from "%ui/ui_library.nut" import *
import "%ui/components/fontawesome.map.nut" as fa
import "%dngscripts/ecs.nut" as ecs

let { logEntries, chosenLogElement, hoveredLogElement } = require("%ui/mainMenu/debriefing/debriefing_log_state.nut")
let { locTable } = require("%ui/helpers/time.nut")

let iconParams = {size = [fontawesome.fontSize, fontawesome.fontSize], halign = ALIGN_CENTER}

let longTime = 23*60 + 9 
let timeTextSize = calc_comp_size(mkText(secondsToStringLoc(longTime), {padding=static [0, hdpx(5), 0, 0]}))

let mkLogEntryText = @(time, text, icon) {
  flow = FLOW_HORIZONTAL
  gap = hdpx(5)
  padding = static [0, hdpx(5), 0, hdpx(5)]
  children = [
    icon
    {
      size = timeTextSize
      halign = ALIGN_LEFT
      children = mkText(time, {size = timeTextSize}),
    }
    mkText(text)
  ]
}

let defaultIcon = {
  rendObj = ROBJ_TEXT
  text = fa["circle-o"]
  color = TextNormal
}.__update(fontawesome, iconParams)

let picIcon = @(iconName) iconParams.__merge({
  rendObj = ROBJ_IMAGE
  image = Picture("{0}:{1}:{2}".subst(iconName, iconParams.size[0], iconParams.size[1]))
})

let killIcons = {
  militant = { iconName = "ui/skin#skull.svg", color = Color(255, 128, 0) }
  turned_soldier = { iconName = "ui/skin#raid_info/turned.svg" }
  changed_human = { iconName = "ui/skin#raid_info/distorted.svg" }
  flower_human = { iconName = "ui/skin#raid_info/flower.svg" }
  swarm_snake_nest = { iconName = "ui/skin#raid_info/worms.svg" }
  wandering_core = { iconName = "ui/skin#raid_info/ball_lightning.svg" }
  invisible_man = { iconName = "ui/skin#raid_info/invisible.svg" }
  beehive = { iconName = "ui/skin#raid_info/mosquito.svg" }
  hellhound = { iconName = "ui/skin#raid_info/distorted_hound.svg" }
  dendroid = { iconName = "ui/skin#raid_info/dendroid.svg" }
}

let spawnIcon = {
  rendObj = ROBJ_IMAGE
  image = Picture($"ui/skin#white_circle.svg:{iconParams.size[0]}:{iconParams.size[1]}:P")
  color = Color(50,50,50,255)
  size = iconParams.size
  children = @(){
    rendObj = ROBJ_IMAGE
    hplace = ALIGN_CENTER
    vplace = ALIGN_CENTER
    image = Picture($"ui/skin#antenna.svg:{iconParams.size[0]}:{iconParams.size[1]}:P")
    color = Color(255, 255, 255)
    size = iconParams.size
  }
}

let icons = {
  died = defaultIcon.__merge({text = fa["close"], color = Color(200, 0, 0)})
  extracted = extractionIcon
  respawned = spawnIcon 
  transformed = spawnIcon 
  kill = function(point) {
    let {
      iconName = "ui/skin#skull.svg"
      color = BtnBgActive
    } = killIcons?[point?.victimType] ?? {}
    return picIcon(iconName).__merge({color})
  }
  encounterVisit = picIcon("ui/skin#question.svg")
}

let chooseLogPointIcon = function(point) {
  let icon = icons?[point.eventType] ?? defaultIcon
  local iconToUse = icon
  if (typeof icon == "function")
    iconToUse = icon(point)
  return {
    size = hdpx(21)
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    children = iconToUse
  }
}

let mkLogEntryTitle = function(point) {
  local {eventType = "", name = "" } = point
  if (endswith(name, " "))
    name = name.slice(0, -1)
  if (point.eventType == "kill") {
    let { victimType = "" } = point
    let victimTypeLoc = (victimType != null && victimType != "")
      ? loc($"debriefing/log/victim/{victimType}")
      : loc("debriefing/log/victim/unknown")
    return (name != null && name != "")
      ? loc("debriefing/log/kill_name", { victimType = victimTypeLoc, name })
      : loc("debriefing/log/kill", { victimType = victimTypeLoc })
  }
  if (point.eventType == "died") {
    let { offenderType = "", murderWeaponTemplate = null } = point
    let template = murderWeaponTemplate == null ? null : ecs.g_entity_mgr.getTemplateDB().getTemplateByName(murderWeaponTemplate)
    let weaponName = template == null ? null : loc(template.getCompValNullable("item__name"))

    let offenderTypeLoc = (offenderType != null && offenderType != "")
      ? loc($"debriefing/log/victim/{offenderType}") : ""
    let viaWeapon = weaponName != null ? loc("debriefing/log/death_from_weapon", {weapName=weaponName}) : ""
    return ((name != null && name != "")
    ? loc("debriefing/log/died_name", { name })
    : offenderTypeLoc != ""
    ? loc("debriefing/log/died_monster", { offenderType = offenderTypeLoc })
    : loc("debriefing/log/died")) + viaWeapon
  }
  if (point.eventType == "transformed") {
    let { monsterType = "Monster" } = point
    return loc("debriefing/log/transformed", { monsterType = loc(monsterType) })
  }
  return loc($"debriefing/log/{eventType}")
}

let mkLogEntryContent = function(point) {
  let { minutes = 0, seconds = 0 } = secondsToTime(point.timestamp)
  let time = $"{minutes}{locTable.minutes} {format("%02d", seconds)}{locTable.seconds}"
  let text = mkLogEntryTitle(point)
  let icon = chooseLogPointIcon(point)
  return mkLogEntryText(time, text, icon)
}

let chooseFillColor = function(index, sf) {
  if (sf & S_ACTIVE)
    return BtnBgActive
  if (index == chosenLogElement.get())
    return BtnBgSelected
  if (index == hoveredLogElement.get())
    return BtnBgHover
  return BtnBgNormal
}

let mkLogEntry = function(point, index){
  let stateFlags = Watched(0)
  return @(){
    size = FLEX_H
    watch = [chosenLogElement, hoveredLogElement, stateFlags]
    behavior = Behaviors.Button
    xmbNode = XmbNode()
    onHover = @(v) v ? hoveredLogElement.set(index) : hoveredLogElement.set(null)
    onClick = @() chosenLogElement.modify(@(old_index) old_index == index ? null : index)
    onElemState = @(v) stateFlags.set(v)

    rendObj = ROBJ_BOX
    fillColor = chooseFillColor(index, stateFlags.get())
    children = mkLogEntryContent(point)
    borderColor = index == chosenLogElement.get() ? Color(200, 200, 200) : Color(230, 200, 90, 255)
    borderWidth = static [0, 0, 0, hdpx(2)]
    data = { index }
    padding = hdpx(5)
    sound = {
      click = "ui_sounds/button_action"
      hover = "ui_sounds/button_highlight"
    }
  }
}

local scrollHandler = ScrollHandler()

let debriefingLog = makeVertScrollExt(@() {
  xmbNode = XmbContainer({
    canFocus = false
    wrap = false
    scrollSpeed = 5.0
  })
  flow = FLOW_VERTICAL
  watch = logEntries
  size = FLEX_H
  children = logEntries.get().map(mkLogEntry)
  onDetach = @() scrollHandler = ScrollHandler()
}, {
  scrollHandler
})

let scrollToLogElement = function(index) {
  if (scrollHandler == null || index == null)
    return
  scrollHandler.scrollToChildren(@(child) (child?.data.index ?? -1) == index, 2, false, true)
}

return {
  debriefingLog
  chooseLogPointIcon
  logIconParams = iconParams
  scrollToLogElement
}
