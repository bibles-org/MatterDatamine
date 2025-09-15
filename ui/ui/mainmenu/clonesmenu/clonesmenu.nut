from "%ui/components/commonComponents.nut" import mkHelpConsoleScreen, mkText, mkTextArea, bluredPanelWindow, mkTooltiped
from "dasevents" import EventShowItemInShowroom, EventCloseShowroom, EventUIMouseMoved, EventUIMouseWheelUsed, CmdHideUiMenu
from "%ui/fonts_style.nut" import body_txt
from "%ui/mainMenu/stdPanel.nut" import mkHelpButton, mkBackBtn, mkCloseBtn
from "%ui/components/colors.nut" import GreenSuccessColor, RedWarningColor, BtnBgDisabled
from "string" import format
from "dagor.math" import Point2
from "%ui/components/scrollbar.nut" import makeVertScrollExt, thinStyle
from "%ui/ui_library.nut" import *
from "%ui/hud/hud_menus_state.nut" import openMenu, convertMenuId
from "%ui/mainMenu/clonesMenu/clonesMenuCommon.nut" import mkChronogeneParamString, findItemInAllItems, getCurrentHeroEffectMod, ClonesMenuId,
  AlterSelectionSubMenuId, getChronogeneItemByUniqueId, clonesMenuScreenPadding, backTrackingMenu, mkPassiveChronogeneSlot
from "%ui/mainMenu/clonesMenu/cloneTubesInitEs.nut" import selectedContainerHighlightIntence, hoveredContainerHighlightIntence
from "%ui/mainMenu/clonesMenu/itemGenesSlots.nut" import mkEquippedMainChronogenes, equippedSecondaryChronogenes, mkMainChronogeneInfoStrings
from "%ui/mainMenu/clonesMenu/mainChronogeneSelection.nut" import mainChronogenesCards, hoveredAlter, showAlterWidth,
  updateAlterInShowroom, selectedPreviewAlter, selectAlterToEquip, alterToFocus
from "%ui/components/button.nut" import buttonWithGamepadHotkey
from "%ui/components/accentButton.style.nut" import accentButtonStyle
from "%ui/profile/profileState.nut" import playerBaseState, allPassiveChronogenes
from "%ui/state/allItems.nut" import allItems
import "%dngscripts/ecs.nut" as ecs

let { stashItems } = require("%ui/hud/state/inventory_items_es.nut")
let { equipment } = require("%ui/hud/state/equipment.nut")
let { selectedMainChronogeneItem } = require("%ui/mainMenu/clonesMenu/itemGenes.nut")
let { isOnboarding } = require("%ui/hud/state/onboarding_state.nut")
let { currentChronogenes } = require("%ui/mainMenu/clonesMenu/cloneMenuState.nut")
let { chronogeneStatCustom, chronogeneStatDefault } = require("%ui/hud/state/item_info.nut")
let { mutationForbidenDueToInQueueState } = require("%ui/hud/state/inventory_state.nut")
let { currentMenuId } = require("%ui/hud/hud_menus_state.nut")

let cloneMenuName = loc("clonesControlMenu/title", "Clones Body Research")

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

let selectedAlter = keepref(Computed(function() {
  let hovered = hoveredAlter.get()
  if (hovered)
    return hovered
  let selected = selectedPreviewAlter.get()
  if (selected)
    return selected
  let currentMain = currentChronogenes.get()?.primaryChronogenes[0]
  return getChronogeneItemByUniqueId(currentMain)
}))

function mkClonesMenu() {
  let initialMods = getCurrentHeroEffectMod([])
  let effectModVal = Watched(initialMods.entity_mod_values)

  function updateEffectModVal(additionalChronogenes=[]) {
    effectModVal.set(getCurrentHeroEffectMod(additionalChronogenes).entity_mod_values)
  }

  selectedMainChronogeneItem.subscribe_with_nasty_disregard_of_frp_update(function(item) {
    updateEffectModVal(item?.templateName ? [ item?.templateName ] : [])
  })

  
  
  equipment.subscribe_with_nasty_disregard_of_frp_update(@(_) updateEffectModVal([]))

  let effectModStrings = Computed(function() {
    let effectMod = effectModVal.get()
    return {
      anyValDeminished = false
      chronogenesStats = effectMod.map(function(v, k) {
        return v.__merge({
          value = chronogeneStatCustom?[k].calc(v.value) ?? chronogeneStatDefault.calc(v.value)
        })
      })
    }
  })

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

  let middleSection =  {
    size = static [ pw(50), flex() ]
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
      margin = static [ 0, hdpx(30) ]
      size = FLEX_H
      flow = FLOW_VERTICAL
      gap = hdpx(5)
      children = specStats.len() > 0 ? [
        mkText(loc("clonesMenu/specialInfoTitle"), body_txt.__merge({ hplace = ALIGN_LEFT, color = GreenSuccessColor }))
        makeVertScrollExt(
          mkTextArea(text, {
            size = FLEX_H
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

  function cloneChronogenesInfo() {
    let alterStats = effectModStrings.get()

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
      size = FLEX_H
      flow = FLOW_VERTICAL
      margin = static [ 0, hdpx(30) ]
      gap = hdpx(10)
      children = [
        {
          halign = ALIGN_CENTER
          size = FLEX_H
          children = mkText(loc("clonesMenu/boostsInfoTitle"), body_txt)
        }
        {
          size = FLEX_H
          flow = FLOW_VERTICAL
          gap = hdpx(5)
          children = stats
        }
        {
          size = FLEX_H
          children = alterStats.anyValDeminished ?
            mkTextArea(loc("clonesMenu/chronogenesRestriction"), {
              color = RedWarningColor
              halign = ALIGN_CENTER
            }) : null
        }
      ]
    }

    return {
      watch = effectModStrings
      size = FLEX_H

      valign = ALIGN_TOP
      halign = ALIGN_LEFT

      children = alterStatsPanel
    }
  }

  let cloneInfo = {
    size = static [ pw(30), flex() ]
    hplace = ALIGN_RIGHT
    children = {
      size = FLEX_H
      flow = FLOW_VERTICAL
      gap = hdpx(10)
      padding = static [hdpx(10), 0]
      children = [
        cloneChronogenesInfo
        cloneChronogeneSpecialInfo
      ]
    }.__update(bluredPanelWindow)
  }

  let visualParams = static {
    slotSize = [hdpxi(58), hdpxi(58)]
    height = hdpxi(44)
    width = hdpxi(44)
  }

  function passiveChronogenesList() {
    let allPassiveChronogenesTemplates = allPassiveChronogenes.get().keys()
    let allRewards = []

    foreach (item in allItems.get())
      if (allPassiveChronogenesTemplates.contains(item.templateName))
        allRewards.append(mkPassiveChronogeneSlot(item, visualParams))

    let rewardsLists = []
    if (allRewards.len() <= 0)
      rewardsLists.append(mkTextArea(loc("player_progression/rewardBlockExplain"), { margin = static [0, hdpx(4)]}))
    else {
      function mkColumn(itemInRow) {
        return {
          flow = FLOW_HORIZONTAL
          gap = hdpx(4)
          children = itemInRow
        }
      }
      let itemsPerRow = 9
      for (local i = 0; i < allRewards.len(); i += itemsPerRow)
        rewardsLists.append(mkColumn(allRewards.slice(i, i + itemsPerRow)))
    }
    #allow-auto-freeze
    return {
      watch = [allItems, allPassiveChronogenes]
      size = FLEX_H
      flow = FLOW_VERTICAL
      gap  = hdpx(6)
      padding = static [0,0, hdpx(10), 0]
      children = [
        mkTooltiped(mkText(loc("clonesMenu/passiveChronogenes"), body_txt), loc("player_progression/rewardBlockExplain"))
        {
          size = FLEX_H
          flow = FLOW_VERTICAL
          gap = hdpx(4)
          children = rewardsLists
        }
      ]
    }
  }

  function mkCloneInfoScreen() {
    return @() {
      watch = [ equipment, stashItems ]
      size = flex()
      gap = hdpx(5)
      children = [
        middleSection
        {
          size = SIZE_TO_CONTENT
          flow = FLOW_VERTICAL
          gap = hdpx(20)
          children = [
            mkEquippedMainChronogenes()
            equippedSecondaryChronogenes
            passiveChronogenesList
          ]
        }.__update(bluredPanelWindow)
        cloneInfo
      ]
    }
  }

  let cloneMenu = {
    size = flex()
    flow = FLOW_HORIZONTAL
    gap = hdpx(5)
    children = mkCloneInfoScreen()
  }

  function buttons() {
    let closeBtn = backTrackingMenu.get() != null ? mkBackBtn(backTrackingMenu.get()) : mkCloseBtn(ClonesMenuId)
    return {
      watch = [playerBaseState, backTrackingMenu]
      gap = hdpx(2)
      size = FLEX_H
      onDetach = @() backTrackingMenu.set(null)
      children = {
        hplace = ALIGN_RIGHT
        flow = FLOW_HORIZONTAL
        children = [closeBtn]
      }
    }
  }

  
  
  
  mutationForbidenDueToInQueueState.subscribe(function(state) {
    if (!state)
      return

    ecs.g_entity_mgr.broadcastEvent(CmdHideUiMenu(static { menuName = ClonesMenuId }))
  })

  let cloneMenuScreen = @(){
    watch = [ playerBaseState ]
    padding = clonesMenuScreenPadding
    gap = hdpx(5)
    size = flex()
    flow = FLOW_VERTICAL
    onAttach = function() {
      updateAlterInShowroom(currentChronogenes.get())
    }
    children = [
      buttons
      cloneMenu
    ]
  }

  let alterSelectionScreen = @() {
    size = flex()
    padding = clonesMenuScreenPadding
    onAttach = function() {
      if (alterToFocus.get() == null)
        updateAlterInShowroom(currentChronogenes.get(), Point2(0.6, 0.5))
    }
    children = [
      {
        size = static flex()
        halign = ALIGN_RIGHT
        hplace = ALIGN_RIGHT
        children = [
          {
            size = flex()
            behavior = [Behaviors.MoveResize, Behaviors.WheelScroll]
            stopMouse = false
            skipDirPadNav = true
            onMoveResize = @(dx, dy, _dw, _dh) ecs.g_entity_mgr.broadcastEvent(EventUIMouseMoved({screenX = dx, screenY = dy}))
            onWheelScroll = @(value) ecs.g_entity_mgr.broadcastEvent(EventUIMouseWheelUsed({value}))
          }
        ]
      }
      {
        flow = FLOW_HORIZONTAL
        size = flex()
        gap = { size = flex() }
        children = [
          mainChronogenesCards()
          function() {
            let isAlterAvailable = selectedPreviewAlter.get()?.mainChronogeneAvailable ?? false
            let textBlock = mkText(loc("clonesMenu/selectEquipAlter"), { hplace = ALIGN_CENTER }.__merge(body_txt))
            let textWidth = calc_comp_size(textBlock)[0]
            return {
              watch = [selectedPreviewAlter, selectedAlter]
              size = [min(sw(25), hdpx(425)), sh(80)]
              flow = FLOW_VERTICAL
              gap = { size = flex() }
              halign = ALIGN_CENTER
              vplace = ALIGN_BOTTOM
              children = [
                mkMainChronogeneInfoStrings(selectedAlter.get(),
                  {
                    size = FLEX_H
                    margin = 0
                  })
                makeVertScrollExt(mkTextArea(loc($"{selectedAlter.get()?.itemTemplate}/desc"), {
                    size = FLEX_H
                    hplace = ALIGN_LEFT
                  }),
                  {
                    size = [flex(), sh(30)]
                    styling = thinStyle
                  })
                buttonWithGamepadHotkey(textBlock,
                  function() {
                    selectAlterToEquip(selectedPreviewAlter.get())
                    if (isAlterAvailable)
                      openMenu(ClonesMenuId)
                  }, {
                    style = isAlterAvailable ? {} : { BtnBgNormal = BtnBgDisabled }
                    size = [textWidth + hdpx(80), static hdpx(50)]
                    vplace = ALIGN_BOTTOM
                    hotkeys = [["J:X", { description = { skip = true } }]]
                  }.__merge(isAlterAvailable ? accentButtonStyle : {}) )
              ]
            }
          }
        ]
      }
      {
        hplace = ALIGN_RIGHT
        vplace = ALIGN_TOP
        children = mkBackBtn(alterToFocus.get() == null ? ClonesMenuId : "monolithAccessWnd")
      }
    ]
  }

  return {
    getContent = @() function() {
      let [_id, submenus] = convertMenuId(currentMenuId.get())
      let submenu = submenus?[0]
      let isAlterSelection = submenu == AlterSelectionSubMenuId

      let menuContent = isAlterSelection ? alterSelectionScreen : cloneMenuScreen
      return {
        watch = currentMenuId
        size = flex()
        children = menuContent
        onDetach = @() ecs.g_entity_mgr.broadcastEvent(EventCloseShowroom())
      }
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