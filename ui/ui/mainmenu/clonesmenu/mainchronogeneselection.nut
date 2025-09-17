from "%ui/mainMenu/clonesMenu/itemGenes.nut" import primaryGenesListWatcheds, getPrimaryGenesList, mainChronogenesSorting
from "%ui/mainMenu/clonesMenu/clonesMenuCommon.nut" import mkMainChronogeneInfoStrings, findItemInAllItems,
  mkChronogeneDoll, getChronogeneFullBodyPresentation, mkAlterIconParams, ClonesMenuId, getChronogeneItemByUniqueId,
  clonesMenuScreenPadding, AlterSelectionSubMenuId
from "%ui/fonts_style.nut" import h2_txt, body_txt
from "%ui/hud/menus/components/fakeItem.nut" import mkFakeItem
from "%ui/hud/menus/components/inventoryItemImages.nut" import inventoryItemImage, highInventoryImageParams
from "%ui/components/button.nut" import button, getGamepadHotkeyIcon, buttonWithGamepadHotkey, defButtonStyle
from "%ui/components/commonComponents.nut" import mkText, fontIconButton, bluredPanelWindow, mkTextArea, mkDescTextarea
from "%ui/mainMenu/clonesMenu/cloneMenuState.nut" import sendRawChronogenes, currentChronogenes
from "%ui/components/scrollbar.nut" import makeVertScrollExt, thinAndReservedPaddingStyle
from "%ui/components/msgbox.nut" import showMsgbox, showMessageWithContent
from "dasevents" import EventShowItemInShowroom, EventCloseShowroom, EventActivateShowroom
from "dagor.math" import Point2
from "%ui/components/colors.nut" import Inactive, ConsoleFillColor, BtnBdDisabled, BtnBgDisabled, BtnBdNormal,
  BtnBdFocused, TextHighlight, SelBdSelected, SelBdHover, GreenSuccessColor, InfoTextValueColor
from "%ui/components/cursors.nut" import setTooltip
import "%ui/components/tooltipBox.nut" as tooltipBox
import "%ui/components/faComp.nut" as faComp
from "%ui/components/modalWindows.nut" import addModalWindow, removeModalWindow
from "math" import floor, ceil
from "%ui/hud/hud_menus_state.nut" import openMenu, convertMenuId
from "%ui/components/pcHoverHotkeyHitns.nut" import hoverHotkeysWatchedList
from "%ui/state/allItems.nut" import allItems
from "%ui/mainMenu/clonesMenu/itemGenes.nut" import allChronogenesInGame
from "%ui/hud/menus/components/inventoryItemTypes.nut" import GENES_MAIN
from "%ui/hud/menus/components/inventoryActionsHints.nut" import hoverPcHotkeysPresentation
from "%ui/control/active_controls.nut" import isGamepad
from "%ui/components/accentButton.style.nut" import accentButtonStyle
from "%ui/hud/menus/components/inventoryItemRarity.nut" import rarityColorTable
from "%ui/mainMenu/clonesMenu/main_chronogenes_presentation.nut" import mainChronogeneObtainWay, ObtainWay
from "%ui/mainMenu/monolith/monolith_common.nut" import monolithLevelOffers, MonolithMenuId,
  monolithSelectedLevel, selectedMonolithUnlock, monolithSectionToReturn, currentTab, permanentMonolithLevelOffers
from "%ui/profile/profileState.nut" import playerProfileCurrentContracts
from "%ui/gameModeState.nut" import raidToFocus, selectedPlayerGameModeOption
from "%ui/matchingQueues.nut" import matchingQueuesMap
from "%ui/mainMenu/raid_preparation_window_state.nut" import Missions_id
from "%ui/mainMenu/contractWidget.nut" import contractToFocus, getContracts, isRightRaidName
from "%ui/mainMenu/currencyPanel.nut" import packData
import "%ui/components/colorize.nut" as colorize
from "%ui/components/openUrl.nut" import openUrl


from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs
import "%ui/control/gui_buttons.nut" as JB


const MAIN_CHRONOGENE_UID = "mainChronogeneWindow"
let selectedAlterToEquip = Watched(null)

local canPlaceOnScene = true
let tblScrollHandler = ScrollHandler()
let backgrounds = static {
  common = "common_bg"
  uncommon = "uncommon_bg"
  rare = "rare_bg"
  epic = "epic_bg"
}

let title = {
  size = FLEX_H
  padding = hdpx(10)
  children = mkText(loc("clonesMenu/mainChronogenSelectionTitle"), h2_txt)
}

let hoveredAlter = Watched(null)
let alterToFocus = Watched(null)
let selectedPreviewAlter = Watched(null)
let chronogeneSelectionWindowSize = static [sw(90), sh(90)]
let alterSelectionWidth = static max(sw(50) - clonesMenuScreenPadding[1] * 2, hdpx(900))
let showAlterWidth = static min(sw(50) - clonesMenuScreenPadding[1] * 2, hdpx(900))
let alterScreenPos = Point2(0.45, 0.55)
let alterShowQuadSize = [ sh(175), sh(175) ]
function placeAlterInItemShowroom(templateName) {
  if (!templateName)
    return

  let data = ecs.CompObject()
  data["__alter"] <- templateName
  data["forceAnimState"] <- "presentation_idle"
  data["floatingAmplitude"] <- 0.0

  ecs.g_entity_mgr.broadcastEvent(EventShowItemInShowroom({ showroomKey=$"alterShowroom", data }))
}

function updateAlterTemplateInShowroom(alterTemplate, pos=alterScreenPos){
  ecs.g_entity_mgr.broadcastEvent(EventActivateShowroom({
    showroomKey=$"alterShowroom",
    placeScreenPosition=Point2(pos.x * sw(100), pos.y * sh(100)),
    placeScreenSize=Point2(alterShowQuadSize[0], alterShowQuadSize[1])
  }))

  placeAlterInItemShowroom(alterTemplate)
}

function updateAlterInShowroom(alterContainer, pos=alterScreenPos) {
  if (alterContainer) {
    ecs.g_entity_mgr.broadcastEvent(EventCloseShowroom())

    let primary = alterContainer.primaryChronogenes[0]
    let primaryItem = allItems.get().findvalue(@(v) v?.itemId.tostring() == primary?.tostring())
    let primaryItemTemplate = primaryItem?.templateName ?? primaryItem?.itemTemplate

    updateAlterTemplateInShowroom(primaryItemTemplate, pos)
  }
}

function mkAlterBackgroundTexture(rarity, isSelected = false) {
  let icon = backgrounds?[rarity]
  if (icon == null)
    return null

  let color = rarityColorTable[rarity]
  return {
    rendObj = ROBJ_IMAGE
    size = flex()
    color
    opacity = 0.5
    keepAspect = KEEP_ASPECT_FILL
    transform = {}
    animations = !isSelected ? null : [
      {prop = AnimProp.opacity, from = 1, to = 0.5, duration = 2, play = true, loop = true, easing = CosineFull }
    ]
    image = Picture($"ui/skin#{icon}.svg:{190}:{320}:K:Ac")
  }
}

function noAccessMessageBox(chronogene, templateName, text) {
  let { attachments, alterIconParams } = mkAlterIconParams(templateName)
  let fake = mkFakeItem(templateName, alterIconParams, attachments)
  showMessageWithContent({
    content = {
      size = static [sw(80), SIZE_TO_CONTENT]
      flow = FLOW_VERTICAL
      gap = static hdpx(40)
      halign = ALIGN_CENTER
      children = [
        mkTextArea(text, { halign = ALIGN_CENTER }.__merge(h2_txt)),
        {
          rendObj = ROBJ_BOX
          borderWidth = static hdpx(4)
          borderColor = BtnBdDisabled
          padding = static hdpx(4)
          children = [
            mkAlterBackgroundTexture(fake?.itemRarity)
            inventoryItemImage(fake, highInventoryImageParams)
          ]
        },
        mkMainChronogeneInfoStrings(chronogene, { size = static [min(hdpx(450), sw(25)), SIZE_TO_CONTENT] })
      ]
    }
  })
}

function getWayToObtainString(chronogene) {
  let { itemTemplate } = chronogene
  let wayToObtain = mainChronogeneObtainWay?[itemTemplate]

  if (wayToObtain == null) {
    return loc("clonesMenu/notAvailableChronogene/obtainClassified")
  }

  let { way = null } = wayToObtain

  if (way == null)
    return loc("clonesMenu/notAvailableChronogene/obtainClassified")

  if (way == ObtainWay.MONOLITH) {
    let { level } = wayToObtain
    return loc("clonesMenu/notAvailableChronogene/obtainMonolith",
      { level = colorize(InfoTextValueColor, level == "prestige" ? loc("monolith/permanentLevel")
        : loc("monolith/level", { level = loc($"monolithAccessLevel{level}") })) })
  }
  else if (way == ObtainWay.MONOLITH_END)
    return loc("clonesMenu/notAvailableChronogene/obtainMonolithEnd")
  else if (way == ObtainWay.CONTRACT) {
    local contract = null
    foreach (data in playerProfileCurrentContracts.get())
      foreach (reward in (data?.rewards ?? [])) {
        let isNeededContract = (reward?.items ?? []).findindex(@(v) v?.itemPrototypeName == itemTemplate)
        if (isNeededContract != null) {
          contract = data
          break
        }
      }
    let raid = (contract?.raidName ?? "").split("+")?[1]
    if (raid == null)
      return loc("clonesMenu/notAvailableChronogene/obtainClassified")
    return loc("clonesMenu/notAvailableChronogene/obtainContract", {
      contract = colorize(InfoTextValueColor, loc($"contract/{contract?.name}"))
      raid = colorize(InfoTextValueColor, loc(raid))
    })
  }
  else if (way == ObtainWay.GAME_PACK) {
    let { pack } = wayToObtain
    if (packData?[pack] == null) {
      return loc("clonesMenu/notAvailableChronogene/obtainClassified")
    }
    let { color } = packData[pack]
    return loc("clonesMenu/notAvailableChronogene/obtainGamePack", { pack = colorize(color, loc($"shop/pack_{pack}")) })
  }
  else if (way == ObtainWay.T_DROPS)
    return loc("clonesMenu/notAvailableChronogene/tDrops")
  else if (way == ObtainWay.PREPURCHASED)
    return loc("clonesMenu/notAvailableChronogene/prepurchased")
  return loc("clonesMenu/notAvailableChronogene/obtainClassified")
}


function obtainWayMessageBox(chronogene, templateName, wayToObtain) {
  let { attachments, alterIconParams } = mkAlterIconParams(templateName)
  let fake = mkFakeItem(templateName, alterIconParams, attachments)
  let text = getWayToObtainString(chronogene)
  let buttons = [{ text = loc("Cancel"), isCurrent = true }]
  let { way } = wayToObtain
  if (way == ObtainWay.MONOLITH) {
    let { level } = wayToObtain
    buttons.insert(0, {
      text = loc("market/goToMonolith")
      action = function() {
        monolithSelectedLevel.set(level == "prestige" ? 0 : level)
        selectedMonolithUnlock.set(templateName)
        monolithSectionToReturn.set($"{ClonesMenuId}/{AlterSelectionSubMenuId}")
        currentTab.set("monolithLevelId")
        openMenu(MonolithMenuId)
      }
      customStyle = accentButtonStyle
    })
  }
  else if (way == ObtainWay.CONTRACT) {
    local contract = null
    foreach (data in playerProfileCurrentContracts.get())
      foreach (reward in (data?.rewards ?? [])) {
        let isNeededContract = (reward?.items ?? []).findindex(@(v) v?.itemPrototypeName == templateName)
        if (isNeededContract != null) {
          contract = data
          break
        }
      }
    if (contract == null) {
      noAccessMessageBox(chronogene, templateName, loc("clonesMenu/notAvailableChronogene/obtainClassified"))
      return
    }
    buttons.insert(0, {
      text = loc("missions/goTo")
      action = function() {
        let raidToSelect = matchingQueuesMap.get().findvalue(function(v) {
          return isRightRaidName((v?.extraParams ?? {})?.raidName, contract?.raidName)
        })
        raidToFocus.set({ raid = raidToSelect, backWay = $"{ClonesMenuId}/{AlterSelectionSubMenuId}"})
        selectedPlayerGameModeOption.set(raidToSelect?.extraParams.nexus ? "Nexus" : "Raid")
        let contractsList = getContracts(raidToSelect)
        let contractIdx = contractsList.findindex(@(v) v?[1].protoId == contract?.protoId)
        contractToFocus.set(contractIdx)
        openMenu(Missions_id)
      }
      customStyle = accentButtonStyle
    })
  }
  else if (way == ObtainWay.GAME_PACK) {
    let { pack } = wayToObtain
    if (packData?[pack] == null) {
      noAccessMessageBox(chronogene, templateName, loc("clonesMenu/notAvailableChronogene/obtainClassified"))
      return
    }
    let { url } = packData[pack]
    buttons.insert(0, {
      customButton = {
        flow = FLOW_HORIZONTAL
        gap = static hdpx(10)
        valign = ALIGN_CENTER
        margin = defButtonStyle.textMargin
        children = [
          mkText(loc("shop/openLink"), body_txt)
          faComp("external-link", { fontSize = hdpx(20) })
        ]
      }
      isCurrent = true
      action = @() openUrl(url)
      customStyle = {
        textParams = { rendObj = ROBJ_TEXTAREA, behavior = Behaviors.TextArea }
      }.__merge(accentButtonStyle)
    })
  }
  else if (way == ObtainWay.T_DROPS) {
    noAccessMessageBox(chronogene, templateName, loc("clonesMenu/notAvailableChronogene/obtainClassified"))
    return
  }
  else if (way == ObtainWay.PREPURCHASED) {
    noAccessMessageBox(chronogene, templateName, loc("clonesMenu/notAvailableChronogene/prepurchased"))
    return
  }
  showMessageWithContent({
    content = {
      size = static [sw(80), SIZE_TO_CONTENT]
      flow = FLOW_VERTICAL
      gap = static hdpx(40)
      halign = ALIGN_CENTER
      children = [
        mkDescTextarea(text, { halign = ALIGN_CENTER }.__merge(h2_txt)),
        {
          rendObj = ROBJ_BOX
          borderWidth = static hdpx(4)
          borderColor = BtnBdDisabled
          padding = static hdpx(4)
          children = [
            mkAlterBackgroundTexture(chronogene?.itemRarity)
            inventoryItemImage(fake, highInventoryImageParams)
          ]
        },
        mkMainChronogeneInfoStrings(chronogene, { size = static [min(hdpx(450), sw(25)), SIZE_TO_CONTENT] })
      ]
    }
    buttons
  })
}

function selectAlterToEquip(chronogene, overridedCb = null) {
  let { itemTemplate } = chronogene
  if (overridedCb != null && !chronogene?.mainChronogeneAvailable)
    noAccessMessageBox(chronogene, itemTemplate, loc("clonesMenu/notAvailableChronogene/msg"))
  else if (overridedCb != null)
    overridedCb(chronogene)
  else if (!chronogene?.mainChronogeneAvailable) {
    let wayToObtain = mainChronogeneObtainWay?[itemTemplate] ?? {}
    if (wayToObtain.len() <= 0)
      noAccessMessageBox(chronogene, itemTemplate, loc("clonesMenu/notAvailableChronogene/obtainClassified"))
    else
      obtainWayMessageBox(chronogene, itemTemplate, wayToObtain)
  }
  else
    selectedAlterToEquip.set(chronogene)
}

let lockIcon = faComp("lock", {
  color = Inactive
  margin = hdpx(6)
  fontSize = hdpx(20)
  hplace = ALIGN_RIGHT
  vplace = ALIGN_TOP
})

let selectedIcon = faComp("check", {
  color = GreenSuccessColor
  margin = hdpx(6)
  fontSize = hdpx(20)
  hplace = ALIGN_RIGHT
  vplace = ALIGN_TOP
})

function mkMainChronogeneCard(chronogene, idx, overridedCb = null) {
  let { itemTemplate = null, iconParamsOverride = {}, mainChronogeneAvailable = false } = chronogene
  if (itemTemplate == null)
    return null
  let { alterIconParams } = mkAlterIconParams(itemTemplate)
  let stateFlags = Watched(0)
  let suit = chronogene.__merge(alterIconParams)
  let imageParams = highInventoryImageParams.__merge(iconParamsOverride ?? {})
  let isSelected = Computed(@() (selectedAlterToEquip.get()?.uniqueId ?? currentChronogenes.get()?.primaryChronogenes[0])
    == chronogene.uniqueId)
  let isPrewiewAlter = Computed(@() selectedPreviewAlter.get()?.itemTemplate == chronogene.itemTemplate)
  return  @() {
    watch = [stateFlags, selectedAlterToEquip, isSelected, isPrewiewAlter]
    behavior = Behaviors.Button
    onAttach = function() {
      if (isSelected.get() && alterToFocus.get() == null)
        selectedPreviewAlter.set(chronogene)
    }
    onClick = function() {
      if (canPlaceOnScene && selectedPreviewAlter.get()?.itemTemplate != chronogene?.itemTemplate)
        placeAlterInItemShowroom(chronogene?.itemTemplate)
      selectedPreviewAlter.set(chronogene)
    }
    onDoubleClick = function() {
      selectAlterToEquip(chronogene, overridedCb)
      if (chronogene?.mainChronogeneAvailable)
        openMenu(ClonesMenuId)
    }
    onElemState = @(s) stateFlags.set(s)
    clipChildren = true
    onHover = function(on) {
      if (on) {
        if (isGamepad.get()) {
          hoveredAlter.set(chronogene)
          if (canPlaceOnScene)
            placeAlterInItemShowroom(chronogene?.itemTemplate)
        }
        if (!chronogene?.mainChronogeneAvailable)
          setTooltip(@() tooltipBox({
            size = SIZE_TO_CONTENT
            maxWidth = hdpxi(500)
            children = mkDescTextarea(getWayToObtainString(chronogene), { size = SIZE_TO_CONTENT maxWidth = hdpx(500) })
          }))
        let pcHotkeysHints = hoverPcHotkeysPresentation?[GENES_MAIN.name](chronogene)
        hoverHotkeysWatchedList.set(pcHotkeysHints)
      }
      else {
        hoveredAlter.set(null)
        if (canPlaceOnScene && isGamepad.get())
          placeAlterInItemShowroom(selectedPreviewAlter.get()?.itemTemplate)
        setTooltip(null)
        hoverHotkeysWatchedList.set(null)
      }
    }
    hotkeys = [[ "J:X", { action = function() {
      let alterToEquip = hoveredAlter.get() ?? selectedPreviewAlter.get()
      selectAlterToEquip(alterToEquip, overridedCb)
    }, description = loc("clonesMenu/selectEquipAlter") }]]
    fillColor = mainChronogeneAvailable ? ConsoleFillColor : mul_color(BtnBgDisabled, 0.4)
    xmbNode = XmbNode()
    children = [
      mkAlterBackgroundTexture(chronogene?.itemRarity, isSelected.get())
      {
        transform = { scale = stateFlags.get() & S_HOVER ? [1.04, 1.04] : [1, 1] }
        transitions = [{ prop = AnimProp.scale, duration = 0.4, easing = OutQuintic }]
        animations = selectedAlterToEquip.get() != null ? null : [
          {
            prop = AnimProp.translate, from = [sw(10), sw(10)], to = [sw(10), sw(10)], duration = 0.05 * idx,
            play = true, easing = InOutCubic
          }
          {
            prop = AnimProp.translate, from = [sw(10), 0], to = [0, 0], duration = 0.05,
            delay = idx * 0.05, play = true, easing = InOutCubic
          }
        ]
        children = inventoryItemImage(suit, imageParams)
      }
      isSelected.get() ? selectedIcon
        : mainChronogeneAvailable ? null
        : lockIcon
      function() {
        if (!isGamepad.get())
          return { watch = [isGamepad] }
        let hotkeyIcon = hoveredAlter.get()?.itemTemplate == chronogene.itemTemplate
          ? getGamepadHotkeyIcon([["J:X", { description = { skip = true }}]]) : null
        return {
          watch = [hoveredAlter, isGamepad]
          hplace = ALIGN_CENTER
          vplace = ALIGN_BOTTOM
          children = hotkeyIcon
        }
      }
      {
        rendObj = ROBJ_BOX
        size = flex()
        borderWidth = isPrewiewAlter.get() || isSelected.get() || (stateFlags.get() & S_HOVER) ? hdpx(4) : hdpx(1)
        borderColor = isPrewiewAlter.get() ? SelBdSelected
          : isSelected.get() || (stateFlags.get() & S_HOVER) ? SelBdHover
          : mainChronogeneAvailable ? BtnBdNormal
          : BtnBdDisabled
      }
    ]
  }
}

function splitCardsByRows(cards, cardsPerRow, overridedCb, needToRemoveTitle = false) {
  let available = cards.filter(@(c) c?.mainChronogeneAvailable)
  let unavailable = cards.filter(@(c) !c?.mainChronogeneAvailable)

  function splitByRows(arr) {
    local rows = []
    for (local i = 0; i < arr.len(); i += cardsPerRow)
      rows.append(arr.slice(i, i + cardsPerRow))
    return rows
  }

  return {
    cardAvailableRows = {
      flow = FLOW_VERTICAL
      gap = static hdpx(10)
      children = available.len() <= 0 ? null
        : [needToRemoveTitle ? null : mkTextArea(loc("clonesMenu/availableMainChronogene"), h2_txt)]
            .extend(splitByRows(available).map(@(rows, index) {
              flow = FLOW_HORIZONTAL
              gap = static hdpx(10)
              children = rows.map(@(c, idx) mkMainChronogeneCard(c, index + idx, overridedCb))
            }))
    }
    cardUnavailableRows = unavailable.len() > 0 ? {
      flow = FLOW_VERTICAL
      gap = static hdpx(10)
      children = [mkText(loc("clonesMenu/unavailableMainChronogene"), h2_txt)]
        .extend(splitByRows(unavailable).map(@(rows, index) {
          flow = FLOW_HORIZONTAL
          gap = static hdpx(10)
          children = rows.map(@(c, idx) mkMainChronogeneCard(c, index + idx, overridedCb))
        }))
    } : null
  }
}

let getUnavailableChronogenes = @() allChronogenesInGame.get()?.filter(@(i) i.type == "alters" && getPrimaryGenesList().findindex(@(v) v.itemTemplate == i.itemTemplate) == null)
let getAvailableChronogenes = function() {
  let avTbl = {}
  let available = getPrimaryGenesList()
  foreach (item in available) {
    avTbl[item.itemTemplate] <- item
  }

  return avTbl.values()
}

let mainChronogenesCards = @(overridedCb = null, availableCh = null, unavailbleCh = null, numCardsPerRow = null)
function() {
  let horGap = hdpx(10)
  let sizeByCardsWidth = floor(alterSelectionWidth / (highInventoryImageParams.width + horGap))
  let cardsPerRow = numCardsPerRow ?? sizeByCardsWidth

  let unavailableChronogenes = (unavailbleCh ?? getUnavailableChronogenes() ?? [])
    .map(@(i) mkFakeItem(i.itemTemplate, {
      isDragAndDropAvailable = false
      forceLockIcon = true
      needTooltip = false
      sortingPriority = i.sortingPriority
    }))
    .sort(mainChronogenesSorting)
  let availableChronogenes = (availableCh ?? getAvailableChronogenes())
    .map(@(v) v.__merge({
      isDragAndDropAvailable = false
      needTooltip = false
      mainChronogeneAvailable = true
    }))
    .sort(@(a, b) numCardsPerRow == null ? mainChronogenesSorting(a, b) : true)

  let allMainChronogenes = [].extend(unavailableChronogenes, availableChronogenes)

  if (cardsPerRow <= 0) {
    return { watch = allChronogenesInGame }
  }

  let { cardAvailableRows, cardUnavailableRows } = splitCardsByRows(allMainChronogenes, cardsPerRow, overridedCb, numCardsPerRow != null)

  return {
    watch = [ allChronogenesInGame ].extend(primaryGenesListWatcheds)
    size = FLEX_V
    onDetach = function() {
      if (selectedAlterToEquip.get() != null) {
        let chronogene = selectedAlterToEquip.get()
        let newContainer = clone(currentChronogenes.get())
        newContainer.primaryChronogenes[0] = chronogene.uniqueId
        sendRawChronogenes(newContainer)

        selectedPreviewAlter.set(chronogene)
        placeAlterInItemShowroom(chronogene.itemTemplate)
        let data = ecs.CompObject()
        data["__alter"] <- chronogene.itemTemplate
        data["forceAnimState"] <- "presentation_idle"
        data["floatingAmplitude"] <- 0.0
        ecs.g_entity_mgr.broadcastEvent(EventShowItemInShowroom({ showroomKey=$"alterShowroom", data }))
      }
      alterToFocus.set(null)
    }
    xmbNode = XmbContainer({
      canFocus = false
      wrap = false
      scrollSpeed = 5.0
    })
    onAttach = function() {
      if (alterToFocus.get() == null)
        return
      let fullList = [].extend(availableChronogenes, unavailableChronogenes)
      let neededIdx = fullList.findindex(@(v) v?.itemTemplate == alterToFocus.get().itemTemplate) ?? 0
      let neededRow = ceil(neededIdx.tofloat() / cardsPerRow)
      tblScrollHandler.scrollToY(neededRow * highInventoryImageParams.slotSize[1])
      selectedPreviewAlter.set(alterToFocus.get())
    }
    children = makeVertScrollExt({
        rendObj = ROBJ_WORLD_BLUR_PANEL
        padding = static hdpx(10)
        flow = FLOW_VERTICAL
        gap = hdpx(20)
        children = [cardAvailableRows, cardUnavailableRows]
      },
      {
        size = FLEX_V
        padding = static [hdpx(10), hdpx(10), hdpx(10), 0]
        styling = thinAndReservedPaddingStyle
        scrollAlign = ALIGN_LEFT
        scrollHandler = tblScrollHandler
      }
    )
  }
}

let mainChronogeneInfo = function() {
  let alter = selectedPreviewAlter.get() ?? hoveredAlter.get()
  let presentationParams = getChronogeneFullBodyPresentation(alter?.itemTemplate)
  return {
    watch = [selectedPreviewAlter, hoveredAlter]
    size = FLEX_H
    halign = ALIGN_CENTER
    flow = FLOW_VERTICAL
    gap = { size = flex() }
    children = [
      mkChronogeneDoll(alter?.itemTemplate, [ hdpxi(300), hdpxi(560)], presentationParams)
      mkMainChronogeneInfoStrings(alter)
    ]
  }
}

let closeBtn = fontIconButton(
  "icon_buttons/x_btn.svg",
  @() removeModalWindow(MAIN_CHRONOGENE_UID),
  static {
    fontSize = hdpxi(30)
    size = hdpxi(32)
    hotkeys = [[$"^Esc | {JB.B}", {description = loc("mainmenu/btnClose")}]]
    skipDirPadNav = true
    sound = {
      hover = "ui_sounds/button_highlight"
    }
    margin = hdpx(10)
  }
)

function openMainChronogeneSelection(onDropOverrided=null) {
  let primaryChronogene = currentChronogenes.get()?.primaryChronogenes[0]
  if (primaryChronogene == null) {
    showMsgbox({text = loc("clonesMenu/noAnswerFromProfileServer")})
  }
  else {
    canPlaceOnScene = false
    addModalWindow({
      key = MAIN_CHRONOGENE_UID
      size = flex()
      fillColor = ConsoleFillColor
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      onDetach = function() {
        canPlaceOnScene = true
      }
      children = {
        size = chronogeneSelectionWindowSize
        flow = FLOW_VERTICAL
        onAttach = function() {
          if (alterToFocus.get() != null)
            return
          let currentMainChronogeneId = currentChronogenes.get().primaryChronogenes[0]
          let template = findItemInAllItems(currentMainChronogeneId)?.templateName
          if (template) {
            let fake = mkFakeItem(template)
            hoveredAlter.set(fake)
            if (canPlaceOnScene)
              placeAlterInItemShowroom(fake.itemTemplate)
          }
        }
        children = [
          {
            size = FLEX_H
            flow = FLOW_HORIZONTAL
            valign = ALIGN_CENTER
            children = [
              title
              closeBtn
            ]
          }
          {
            size = flex()
            flow = FLOW_HORIZONTAL
            children = [
              mainChronogenesCards(onDropOverrided, null, null, onDropOverrided != null ? 6 : null )
              {
                size = flex()
                flow = FLOW_VERTICAL
                gap = { size = flex() }
                halign = ALIGN_CENTER
                children = [
                  mainChronogeneInfo
                  function() {
                    let textBlock = mkText(loc("clonesMenu/selectEquipAlter"), { hplace = ALIGN_CENTER }.__merge(body_txt))
                    let textWidth = calc_comp_size(textBlock)[0]
                    let isAlterAvailable = selectedPreviewAlter.get()?.mainChronogeneAvailable ?? false
                    return {
                      watch = selectedPreviewAlter
                      children = buttonWithGamepadHotkey(textBlock,
                        @() selectAlterToEquip(selectedPreviewAlter.get(), onDropOverrided), {
                          style = isAlterAvailable ? {} : { BtnBgNormal = BtnBgDisabled }
                          size = [textWidth + hdpx(80), static hdpx(50)]
                          hotkeys = [["J:X", { description = { skip = true } }]]
                          margin = static hdpx(10)
                        }.__merge(isAlterAvailable ? accentButtonStyle : {}) )
                    }
                  }
                ]
              }
            ]
          }
        ]
      }.__update(bluredPanelWindow)
    })
  }
}

let closeMainChronogeneSelection = @() removeModalWindow(MAIN_CHRONOGENE_UID)

return {
  openMainChronogeneSelection
  closeMainChronogeneSelection
  mainChronogenesCards
  showAlterWidth
  hoveredAlter
  selectedPreviewAlter
  selectAlterToEquip
  updateAlterInShowroom
  updateAlterTemplateInShowroom
  MAIN_CHRONOGENE_UID
  canPlaceOnScene
  mkAlterBackgroundTexture
  alterToFocus
}
