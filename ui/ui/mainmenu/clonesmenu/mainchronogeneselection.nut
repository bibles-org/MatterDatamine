from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { h2_txt } = require("%ui/fonts_style.nut")
let { highInventoryImageParams } = require("%ui/hud/menus/components/inventoryItemImages.nut")
let { mkFakeItem } = require("%ui/hud/menus/components/fakeItem.nut")
let { primaryGenesListWatcheds,
      getPrimaryGenesList,
      allChronogenesInGame,
      chronogenesSorting } = require("itemGenes.nut")
let { mkEquipmentSlot } = require("%ui/hud/menus/components/inventorySuit.nut")
let { mkText, fontIconButton, bluredPanelWindow } = require("%ui/components/commonComponents.nut")
let { mkMainChronogeneInfoStrings,
      findItemInAllItems,
      mkChronogeneDoll,
      getChronogeneFullBodyPresentation,
      getChronogenePreviewPresentation } = require("clonesMenuCommon.nut")
let { currentChronogenes, sendRawChronogenes } = require("cloneMenuState.nut")
let { makeVertScrollExt, thinStyle } = require("%ui/components/scrollbar.nut")
let { showMsgbox } = require("%ui/components/msgbox.nut")
let { EventShowItemInShowroom } = require("dasevents")
let { Inactive, ConsoleFillColor } = require("%ui/components/colors.nut")
let { setTooltip } = require("%ui/components/cursors.nut")
let faComp = require("%ui/components/faComp.nut")
let JB = require("%ui/control/gui_buttons.nut")
let { addModalWindow, removeModalWindow } = require("%ui/components/modalWindows.nut")
let { floor } = require("math")

const MAIN_CHRONOGENE_UID = "mainChronogeneWindow"

let title = {
  size = [ flex(), SIZE_TO_CONTENT ]
  padding = hdpx(10)
  children = mkText(loc("clonesMenu/mainChronogenSelectionTitle"), h2_txt)
}

let hoveredAlter = Watched(null)
let chronogeneSelectionWindowSize = [ min(sw(90), hdpx(1920)), sh(90) ]


function mkMainChronogeneCard(chronogene, onDropOverrided=null) {
  let visualPatch = getChronogenePreviewPresentation(chronogene.itemTemplate)

  let imageParams = highInventoryImageParams.__merge(chronogene?.iconParamsOverride ?? {})

  return {
    opacity = chronogene?.mainChronogeneAvailable ? 1.0 : 0.8
    children = [
      mkEquipmentSlot(chronogene.__merge(visualPatch), {
        onHover = function(on) {
          if (on) {
            hoveredAlter.set(chronogene)
            if (!chronogene?.mainChronogeneAvailable)
              setTooltip(loc("clonesMenu/mainChronogeneNotAvailableTooltip"))
          }
          else {
            setTooltip(null)
          }
        }
        onClick = onDropOverrided ?
          function(_) {
            onDropOverrided(chronogene)
            removeModalWindow(MAIN_CHRONOGENE_UID)
          } :
          function(_) {
            if (chronogene?.mainChronogeneAvailable) {
              removeModalWindow(MAIN_CHRONOGENE_UID)

              let newContainer = clone(currentChronogenes.get())
              newContainer.primaryChronogenes[0] = chronogene.uniqueId
              sendRawChronogenes(newContainer)

              let data = ecs.CompObject()
              data["__alter"] <- chronogene.itemTemplate
              data["forceAnimState"] <- "presentation_idle"
              data["floatingAmplitude"] <- 0.0
              ecs.g_entity_mgr.broadcastEvent(EventShowItemInShowroom({ showroomKey=$"alterShowroom", data }))
            }
            else {
              showMsgbox({text = loc("clonesMenu/notAvailableChronogene/msg")})
            }
          }
      }, imageParams)
      chronogene?.mainChronogeneAvailable ? null :
        faComp("lock", {
          color = Inactive
          padding = hdpx(4)
          fontSize = hdpx(20)
          hplace = ALIGN_RIGHT
          vplace = ALIGN_TOP
        })
    ]
  }
}

let mainChronogenesCards = @(overridedCb=null) function() {
  let clonesScreenWidth = chronogeneSelectionWindowSize[0]
  let infoSectionWidth = hdpx(400)
  let horGap = hdpx(10)
  let sizeByCardsWidth = floor((clonesScreenWidth - infoSectionWidth) / (highInventoryImageParams.width + horGap))
  let cardsPerRow = sizeByCardsWidth

  let unavailableChronogenes = allChronogenesInGame.get()
    ?.filter(@(i) i.type == "alters" && getPrimaryGenesList().findindex(@(v) v.itemTemplate == i.itemTemplate) == null)
    ?.sort(chronogenesSorting)
    ?.map(@(i) mkFakeItem(i.itemTemplate, {
      isDragAndDropAvailable = false
      forceLockIcon = true
      needTooltip = false
      iconParamsOverride = {
        picSaturate = 0.3
      }
    })) ?? []

  let allMainChronogenes = [].extend(
    getPrimaryGenesList().map(@(v) v.__merge({
      isDragAndDropAvailable = false
      needTooltip = false
      mainChronogeneAvailable = true
    }))
      .sort(chronogenesSorting),
    unavailableChronogenes
  )

  if (cardsPerRow <= 0) {
    return { watch = allChronogenesInGame }
  }

  let cardRows = []
  local idx = 0
  while(idx <= allMainChronogenes.len()) {
    cardRows.append({
      flow = FLOW_HORIZONTAL
      gap = horGap
      children = allMainChronogenes.slice(idx, idx + cardsPerRow).map(@(v) mkMainChronogeneCard(v, overridedCb))
    })
    idx += cardsPerRow
  }

  return {
    watch = [ allChronogenesInGame ].extend(primaryGenesListWatcheds)
    padding = hdpx(10)
    size = [ SIZE_TO_CONTENT, flex() ]
    children = makeVertScrollExt({
        flow = FLOW_VERTICAL
        gap = hdpx(10)
        children = cardRows
      },
      {
        size = [ SIZE_TO_CONTENT, flex() ]
        styling = thinStyle
      }
    )
  }
}

let mainChronogeneInfo = function() {
  let alter = hoveredAlter.get()
  let presentationParams = getChronogeneFullBodyPresentation(alter?.itemTemplate)
  return {
    watch = [ currentChronogenes, hoveredAlter ]
    size = [ flex() , SIZE_TO_CONTENT]
    halign = ALIGN_CENTER
    flow = FLOW_VERTICAL
    gap = { size = flex() }
    children = [
      mkChronogeneDoll(alter?.iconName, [ hdpxi(300), hdpxi(560)], presentationParams)
      mkMainChronogeneInfoStrings(alter)
    ]
  }
}

let closeBtn = fontIconButton(
  "icon_buttons/x_btn.svg",
  @() removeModalWindow(MAIN_CHRONOGENE_UID),
  const {
    fontSize = hdpxi(30)
    size = [hdpxi(32), hdpxi(32)]
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
    addModalWindow({
      rendObj = ROBJ_WORLD_BLUR_PANEL
      key = MAIN_CHRONOGENE_UID
      size = flex()
      fillColor = ConsoleFillColor
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      children = {
        size = chronogeneSelectionWindowSize
        flow = FLOW_VERTICAL
        onAttach = function() {
          let currentMainChronogeneId = currentChronogenes.get().primaryChronogenes[0]
          let template = findItemInAllItems(currentMainChronogeneId)?.templateName
          if (template) {
            let fake = mkFakeItem(template)
            hoveredAlter.set(fake)
          }
        }
        children = [
          {
            size = [flex(), SIZE_TO_CONTENT]
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
              mainChronogenesCards(onDropOverrided)
              mainChronogeneInfo
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
  mkMainChronogeneCard
}