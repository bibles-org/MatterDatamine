from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { body_txt } = require("%ui/fonts_style.nut")
let { mkHelpButton, mkBackBtn, mkCloseBtn } = require("%ui/mainMenu/stdPanel.nut")
let { mkHelpConsoleScreen, mkText, mkTextArea, bluredPanelWindow
} = require("%ui/components/commonComponents.nut")
let { stashItems } = require("%ui/hud/state/inventory_items_es.nut")
let { equipment } = require("%ui/hud/state/equipment.nut")
let { selectedMainChronogeneItem } = require("itemGenes.nut")
let { equippedSecondaryChronogenes, mkEquippedMainChronogenes } = require("itemGenesSlots.nut")
let { isOnboarding } = require("%ui/hud/state/onboarding_state.nut")
let { alterContainers, playerBaseState, currentAlter } = require("%ui/profile/profileState.nut")
let { allItems } = require("%ui/state/allItems.nut")
let { currentChronogenes } = require("cloneMenuState.nut")
let { GreenSuccessColor, RedWarningColor } = require("%ui/components/colors.nut")
let { chronogeneStatCustom, chronogeneStatDefault } = require("%ui/hud/state/item_info.nut")
let { calc_change_mult_attr, calc_diminishing_change_mult_attr, calc_change_add_attr, calc_diminishing_change_add_attr } = require("das.inventory")
let { logerr } = require("dagor.debug")
let { format } = require("string")
let { addTabToDevInfo } = require("%ui/devInfo.nut")
let { EventShowItemInShowroom, EventActivateShowroom, EventCloseShowroom, EventUIMouseMoved, EventUIMouseWheelUsed } = require("dasevents")
let { Point2 } = require("dagor.math")
let { selectedContainerHighlightIntence, hoveredContainerHighlightIntence } = require("cloneTubesInitEs.nut")
let { clonesMenuScreenPadding, mkChronogeneParamString, findItemInAllItems, backTrackingMenu
} = require("clonesMenuCommon.nut")
let { makeVertScrollExt, thinStyle } = require("%ui/components/scrollbar.nut")

addTabToDevInfo("[ALTERS] alterContainers", alterContainers)
addTabToDevInfo("[ALTERS] currentAlter", currentAlter)

let alterScreenPos = Point2(0.45, 0.55)
const ClonesMenuId = "CloneBody"
let cloneMenuName = loc("clonesControlMenu/title", "Clones Body Research")
let alterShowQuadSize = [ sh(150), sh(150) ]

let help_data = {
  content = "clonesControlMenu/helpContent"
  footnotes = [
    "clonesControlMenu/helpFootnote1",
    "clonesControlMenu/helpFootnote2",
    "clonesControlMenu/helpFootnote3",
    "clonesControlMenu/helpFootnote4",
    "clonesControlMenu/helpFootnote5",
    "clonesControlMenu/helpFootnote6",
    "clonesControlMenu/helpFootnote7",
    "clonesControlMenu/helpFootnote8",
    "clonesControlMenu/helpFootnote9",
    "clonesControlMenu/helpFootnote10",
    "clonesControlMenu/helpFootnote11",
    "clonesControlMenu/helpFootnote12",
    "clonesControlMenu/helpFootnote13",
    "clonesControlMenu/helpFootnote14",
    "clonesControlMenu/helpFootnote15",
    "clonesControlMenu/helpFootnote16",
    "clonesControlMenu/helpFootnote17",
    "clonesControlMenu/helpFootnote18",
    "clonesControlMenu/helpFootnote19",
    "clonesControlMenu/helpFootnote20",
    "clonesControlMenu/helpFootnote21",
    "clonesControlMenu/helpFootnote22",
    "clonesControlMenu/helpFootnote23",
    "clonesControlMenu/helpFootnote24",
    "clonesControlMenu/helpFootnote25",
    "clonesControlMenu/helpFootnote26",
    "clonesControlMenu/helpFootnote27",
    "clonesControlMenu/helpFootnote28",
    "clonesControlMenu/helpFootnote29",
    "clonesControlMenu/helpFootnote30",
    "clonesControlMenu/helpFootnote31",
    "clonesControlMenu/helpFootnote32",
    "clonesControlMenu/helpFootnote33",
    "clonesControlMenu/helpFootnote34",
    "clonesControlMenu/helpFootnote35",
    "clonesControlMenu/helpFootnote36",
    "clonesControlMenu/helpFootnote37",
    "clonesControlMenu/helpFootnote38",
    "clonesControlMenu/helpFootnote39",
    "clonesControlMenu/helpFootnote40",
    "clonesControlMenu/helpFootnote41",
    "clonesControlMenu/helpFootnote42",
    "clonesControlMenu/helpFootnote43",
    "clonesControlMenu/helpFootnote44",
    "clonesControlMenu/helpFootnote45",
    "clonesControlMenu/helpFootnote46"
  ]
}

function getItemTemplate(template_name){
  return template_name ? ecs.g_entity_mgr.getTemplateDB().getTemplateByName(template_name) : null
}

function getChronogeneParams(chronogeneTemplateName) {
  let template = getItemTemplate(chronogeneTemplateName)
  return template?.getCompValNullable("entity_mod_effects").getAll() ?? {}
}

function getChronogeneName(chronogeneTemplateName) {
  let template = getItemTemplate(chronogeneTemplateName)
  return template?.getCompValNullable("item__name") ?? "unknown"
}

function placeAlterInItemShowroom(templateName) {
  if (!templateName)
    return

  let data = ecs.CompObject()
  data["__alter"] <- templateName
  data["forceAnimState"] <- "presentation_idle"
  data["floatingAmplitude"] <- 0.0

  ecs.g_entity_mgr.broadcastEvent(EventShowItemInShowroom({ showroomKey=$"alterShowroom", data }))
}

function updateAlterInShowroom(alterContainer) {
  if (alterContainer) {
    ecs.g_entity_mgr.broadcastEvent(EventCloseShowroom())

    let primary = alterContainer.primaryChronogenes[0]
    let primaryItem = allItems.get().findvalue(@(v) v?.itemId.tostring() == primary?.tostring())
    let primaryItemTemplate = primaryItem?.templateName ?? primaryItem?.itemTemplate

    ecs.g_entity_mgr.broadcastEvent(EventActivateShowroom({
      showroomKey=$"alterShowroom",
      placeScreenPosition=Point2(alterScreenPos.x * sw(100), alterScreenPos.y * sh(100)),
      placeScreenSize=Point2(alterShowQuadSize[0], alterShowQuadSize[1])
    }))
    placeAlterInItemShowroom(primaryItemTemplate)
  }
}

function mkClonesMenu() {
  let alterSpecialStats = Computed(function() {
    if (!currentChronogenes.get()) {
      return null
    }

    let specialMods = {}

    let primary = currentChronogenes.get()?.primaryChronogenes ?? []
    let hoveredChronogene = selectedMainChronogeneItem.get()?.itemTemplate ? [ selectedMainChronogeneItem.get() ] : []
    let secondary = hoveredChronogene.extend(currentChronogenes.get()?.secondaryChronogenes ?? [])

    foreach(v in [].extend(secondary, primary)) {
      if ( !v || v == "0")
        continue

      let itemTemplateName = v?.itemTemplate ?? findItemInAllItems(v)?.templateName
      if (!itemTemplateName)
        continue

      let params = getChronogeneParams(itemTemplateName)

      
      
      if (params.len() == 0) {
        specialMods[itemTemplateName] <- loc($"{getChronogeneName(itemTemplateName)}/desc")
      }
    }

    return specialMods
  })

  function getStatsTable(chronogenes) {
    let paramModifyRules = getItemTemplate("base_entity_mods")?.getCompValNullable("entity_mod_values").getAll() ?? {}

    let valueMods = {}
    foreach(v in chronogenes) {
      if ( !v || v == "0")
        continue
      let itemTemplateName = v?.itemTemplate ?? findItemInAllItems(v)?.templateName
      let params = getChronogeneParams(itemTemplateName)
      foreach (modName, modValue in params) {
        if (modName not in valueMods)
          valueMods[modName] <- []

        valueMods[modName].append(modValue)
      }
    }

    local anyValDeminished = false
    let calculatedValueMods = {}
    foreach(key, value in valueMods) {
      let modeNameInfo = key.split("+")
      let modeName = modeNameInfo?[0] ?? ""
      let calcType = modeNameInfo?[1] ?? "add"

      if (!anyValDeminished && (calcType == "mult_diminishing" || calcType == "add_diminishing")) {
        anyValDeminished = anyValDeminished || (value.len() > 1)
      }

      let obj = ecs.CompObject()
      value.each(function(v, idx) {
        obj[idx.tostring()] <- v
      })
      if (calcType == "mult_diminishing") {
        calculatedValueMods[modeName] <- calc_diminishing_change_mult_attr(obj)
      }
      else if (calcType == "mult") {
        calculatedValueMods[modeName] <- calc_change_mult_attr(obj)
      }
      else if (calcType == "add") {
        calculatedValueMods[modeName] <- calc_change_add_attr(obj)
      }
      else if (calcType == "add_diminishing") {
        calculatedValueMods[modeName] <- calc_diminishing_change_add_attr(obj)
      }
      else {
        logerr($"Clone info: calculation type <{calcType}> not found")
      }
    }

    return {
      anyValDeminished
      chronogenesStats = paramModifyRules.map(function(_v, k) {
        return {
          value = chronogeneStatCustom?[k]?.calc(calculatedValueMods?[k]) ?? chronogeneStatDefault.calc(calculatedValueMods?[k])
          reversePositivity = paramModifyRules?[k]?.reversePositivity
          hidden = paramModifyRules?[k]?.hidden ?? false
        }
      })
    }
  }

  let middleSection =  {
    size = [ pw(50), flex() ]
    halign = ALIGN_CENTER
    hplace = ALIGN_CENTER
    children = [
      {
        size = flex()
        behavior = [Behaviors.MoveResize, Behaviors.WheelScroll]
        stopMouse = false
        onMoveResize = @(dx, dy, _dw, _dh) ecs.g_entity_mgr.broadcastEvent(EventUIMouseMoved({screenX = dx, screenY = dy}))
        onWheelScroll = @(value) ecs.g_entity_mgr.broadcastEvent(EventUIMouseWheelUsed({value}))
      }
    ]
  }

  function cloneChronogeneSpecialInfo() {
    let specStats = alterSpecialStats.get().values().map(@(v) $"-{v}")

    let text = "\n".join(specStats)

    return {
      watch = alterSpecialStats
      margin = [ 0, hdpx(30) ]
      size = flex()
      flow = FLOW_VERTICAL
      gap = hdpx(5)
      children = specStats.len() > 0 ? [
        mkText(loc("clonesMenu/specialInfoTitle"), body_txt.__merge({ hplace = ALIGN_LEFT, color = GreenSuccessColor }))
        makeVertScrollExt(
          mkTextArea(text, {
            size = [flex(), SIZE_TO_CONTENT]
            hplace = ALIGN_LEFT
          }.__update(body_txt, { color = GreenSuccessColor })),
          {
            size = flex()
            styling = thinStyle
          }
        )
      ] : null
    }
  }

  let chronogenesToShowInStats = Computed(function() {
    let primary = currentChronogenes.get()?.primaryChronogenes ?? []
    let hoveredChronogene = selectedMainChronogeneItem.get()?.itemTemplate ? [ selectedMainChronogeneItem.get() ] : []
    let secondary = hoveredChronogene.extend(currentChronogenes.get()?.secondaryChronogenes ?? [])
    return [].extend(primary, secondary)
  })

  function cloneChronogenesInfo() {
    let alterStats = getStatsTable(chronogenesToShowInStats.get())

    let stats = alterStats.chronogenesStats.map(function(v, k) {
      if (v?.hidden ?? false)
        return null

      let measurement = chronogeneStatCustom?[k]?.measurement ?? chronogeneStatDefault.measurement
      let defVal = chronogeneStatCustom?[k]?.defVal ?? chronogeneStatDefault.defVal
      let def = chronogeneStatCustom?[k]?.calc(defVal) ?? chronogeneStatDefault.calc(defVal)

      let value = v.value

      local valueText = "---"
      if (value != def) {
        let plusNeeded = value > def
        valueText = $"{plusNeeded ? "+" : ""}{format("%.1f", value - def)}{measurement}"
      }

      let isPositive = @(stat) (!stat.reversePositivity && value > def) ||  (stat.reversePositivity && value < def)
      let chronogeneName = k.split("+")?[0] ?? ""

      return mkChronogeneParamString(
        loc($"clonesMenu/stats/{chronogeneName}"),
        valueText,
        loc($"clonesMenu/stats/tooltip/{chronogeneName}"),
        value == def ? null : isPositive(v) ? GreenSuccessColor : RedWarningColor
      )
    }).values()

    let alterStatsPanel = {
      size = [ flex(), SIZE_TO_CONTENT ]
      flow = FLOW_VERTICAL
      margin = [ 0, hdpx(30) ]
      gap = hdpx(10)
      children = [
        {
          halign = ALIGN_CENTER
          size = [ flex(), SIZE_TO_CONTENT ]
          children = mkText(loc("clonesMenu/boostsInfoTitle"), body_txt)
        }
        {
          size = [ flex(), SIZE_TO_CONTENT ]
          flow = FLOW_VERTICAL
          gap = hdpx(5)
          children = stats
        }
        {
          size = [flex(), SIZE_TO_CONTENT]
          children = alterStats.anyValDeminished ?
            mkTextArea(loc("clonesMenu/chronogenesRestriction"), {
              color = RedWarningColor
              halign = ALIGN_CENTER
            }) : null
        }
      ]
    }

    return {
      watch = chronogenesToShowInStats
      size = [ flex(), SIZE_TO_CONTENT ]

      valign = ALIGN_TOP
      halign = ALIGN_LEFT

      children = alterStatsPanel
    }
  }

  let cloneInfo = @(){
    watch = currentChronogenes
    size = [ pw(30), flex() ]
    hplace = ALIGN_RIGHT
    children = {
      size = flex()
      flow = FLOW_VERTICAL
      gap = hdpx(10)
      padding = [hdpx(10), 0]
      children = [
        cloneChronogenesInfo
        cloneChronogeneSpecialInfo
      ]
    }.__update(bluredPanelWindow)
  }

  function mkCloneInfoScreen() {
    return @() {
      watch = [ equipment, stashItems, currentChronogenes ]
      size = flex()
      gap = hdpx(5)
      children = [
        middleSection
        {
          size = SIZE_TO_CONTENT
          flow = FLOW_VERTICAL
          gap = hdpx(20)
          children = [
            mkEquippedMainChronogenes
            equippedSecondaryChronogenes
          ]
        }.__update(bluredPanelWindow)
        cloneInfo
      ]
    }
  }

  let cloneMenu = @(){
    size = flex()
    flow = FLOW_HORIZONTAL
    gap = hdpx(5)
    watch = currentChronogenes
    children = mkCloneInfoScreen()
  }

  let helpConsole = mkHelpConsoleScreen(Picture("ui/build_icons/clone_body_device.avif:{0}:{0}:PF".subst(hdpx(600))), help_data)

  let helpBtn = mkHelpButton(helpConsole, cloneMenuName)
  function buttons() {
    let closeBtn = backTrackingMenu.get() != null ? mkBackBtn(backTrackingMenu.get()) : mkCloseBtn(ClonesMenuId)
    return {
      watch = [playerBaseState, currentChronogenes, backTrackingMenu]
      gap = hdpx(2)
      size = [ flex(), SIZE_TO_CONTENT ]
      onDetach = @() backTrackingMenu.set(null)
      children = {
        hplace = ALIGN_RIGHT
        flow = FLOW_HORIZONTAL
        children = (playerBaseState.get()?.openedAlterContainers ?? 0) <= 1 ? [closeBtn] : [helpBtn, closeBtn]
      }
    }
  }


  let content = @(){
    watch = playerBaseState
    size = flex()
    children = (playerBaseState.get().openedAlterContainers <= 1) ? helpConsole : cloneMenu
    onAttach = function() {
      if ((playerBaseState.get()?.openedAlterContainers ?? 0) > 1) {
        updateAlterInShowroom(currentChronogenes.get())
      }
    }
    onDetach = function() {
      if ((playerBaseState.get()?.openedAlterContainers ?? 0) <= 1)
        return

      ecs.g_entity_mgr.broadcastEvent(EventCloseShowroom())
    }
  }

  return {
    getContent = @() @() {
      watch = [playerBaseState, currentChronogenes]
      padding = clonesMenuScreenPadding
      gap = hdpx(5)
      size = flex()
      flow = FLOW_VERTICAL
      children = [
        buttons
        content
      ]
    }
    id = ClonesMenuId
    name = cloneMenuName
  }
}

return {
  mkClonesMenu
  ClonesMenuId
  selectedContainerHighlightIntence
  hoveredContainerHighlightIntence
  clonesMenuIsAvailable = Computed(@() !isOnboarding.get() && (playerBaseState.get()?.openedAlterContainers ?? 0) > 1)
  backTrackingMenu
}