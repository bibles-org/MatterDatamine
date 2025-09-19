from "%ui/mainMenu/stdPanel.nut" import screenSize
from "%ui/mainMenu/clonesMenu/clonesMenuCommon.nut" import findItemInAllItems, getChronogeneItemByUniqueId,
  mkMainChronogeneInfoStrings, mkChronogeneDoll, getChronogenePreviewPresentation, mkChronogeneImage,
  getChronogeneTooltip, ClonesMenuId, AlterSelectionSubMenuId
from "%ui/mainMenu/clonesMenu/cloneMenuState.nut" import sendRawChronogenes
from "%ui/hud/menus/components/fakeItem.nut" import mkFakeItem
from "%ui/components/commonComponents.nut" import mkText, mkSelectPanelItem, mkSelectPanelTextCtor, BD_LEFT, fontIconButton
from "%ui/components/colors.nut" import BtnBgHover, panelRowColor, Inactive, ConsoleFillColor, BtnBdDisabled,
  BtnBdHover, BtnBgSelected, SelBgNormal, BtnBgDisabled, SelBdSelected, BtnBgNormal
from "%ui/hud/menus/components/inventoryItemUtils.nut" import mergeNonUniqueItems
from "%ui/components/button.nut" import button, textButton
from "%ui/components/scrollbar.nut" import makeVertScrollExt, thinStyle
from "%ui/components/msgbox.nut" import showMsgbox
from "%ui/components/cursors.nut" import setTooltip
import "%ui/components/faComp.nut" as faComp
from "%ui/mainMenu/clonesMenu/mainChronogeneSelection.nut" import closeMainChronogeneSelection, mkAlterBackgroundTexture
from "%ui/components/modalPopupWnd.nut" import addModalPopup, removeModalPopup
from "%ui/hud/hud_menus_state.nut" import openMenu, convertMenuId
import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *
from "%ui/fonts_style.nut" import body_txt, fontawesome
import "%ui/components/fontawesome.map.nut" as fa

let { currentChronogenes } = require("%ui/mainMenu/clonesMenu/cloneMenuState.nut")
let { playerBaseState } = require("%ui/profile/profileState.nut")
let { humanEquipmentSlots } = require("%ui/hud/state/equipment_slots_stubs.nut")
let { GENES_SECONDARY } = require("%ui/hud/menus/components/inventoryItemTypes.nut")
let { allChronogenesInGame, selectedMainChronogeneItem } = require("%ui/mainMenu/clonesMenu/itemGenes.nut")
let { hoverHotkeysWatchedList } = require("%ui/components/pcHoverHotkeyHitns.nut")
let { hoverPcHotkeysPresentation } = require("%ui/hud/menus/components/inventoryActionsHints.nut")
let { stashItems } = require("%ui/hud/state/inventory_items_es.nut")
let { equipment } = require("%ui/hud/state/equipment.nut")
let { safeAreaVerPadding } = require("%ui/options/safeArea.nut")

let mkChronogene = @(chronogene_template) mkFakeItem(chronogene_template, {
  isDragAndDropAvailable = false
})

function chronogeneOrStub(id){
  let item = findItemInAllItems(id)
  if (item?.templateName != null)
    return mkChronogene(item.templateName).__update({ uniqueId = id })
  return humanEquipmentSlots.chronogene_secondary 
}

let lock = faComp("lock", {
  color = Inactive
  padding = hdpx(8)
  fontSize = hdpx(15)
  hplace = ALIGN_RIGHT
  vplace = ALIGN_CENTER
})

let getStyle = memoize(@(isCurrent, isActive) freeze({
    BtnBgNormal = isActive ? SelBgNormal : BtnBgDisabled
    BtnBgHover = isActive ? SelBgNormal : BtnBgDisabled
    BtnBdNormal = isCurrent ? SelBdSelected : mul_color(BtnBdHover, 0.2, 10)
  })
)

let chronogenesImageParams = static {
  width=hdpx(40)
  height=hdpx(40)
  transform = {}
  animations=[]
  slotSize = [ hdpxi(50), hdpxi(50) ]
}

function mkChronogeneSelectPanel(chronogeneItem, isAvailable, currentChronogeneIdx, curUniqueId, onClickOverrideFunc=null) {
  let isCurrent = curUniqueId != null && curUniqueId != 0 && (
    curUniqueId == chronogeneItem?.uniqueId ||
    curUniqueId == chronogeneItem?.itemTemplate 
  )
  local stateFlags = Watched(0)
  return {
    size = FLEX_H
    flow = FLOW_HORIZONTAL
    gap = hdpx(1)
    children = [
      button({
          size = FLEX_H
          flow = FLOW_HORIZONTAL
          children = [
            mkChronogeneImage(chronogeneItem, chronogenesImageParams, { size = [hdpx(13), hdpx(13)] }),
            @() {
              watch = stateFlags
              rendObj = ROBJ_SOLID
              size = flex()
              padding = static [0,0,0, hdpx(4)]
              color = stateFlags.get() & S_HOVER ? BtnBgHover
                : isAvailable ? SelBgNormal
                : BtnBdDisabled
              children = [
                mkText(loc(chronogeneItem?.itemName) ?? loc("clonesMenu/emptySecondaryChronogeneSlot"), {
                  hplace = ALIGN_LEFT
                  vplace = ALIGN_CENTER
                  size = FLEX_H
                  padding = static [0,0,0,hdpx(10)]
                }),
                (chronogeneItem?.count ?? 0) <= 1 ? null : {
                  rendObj = ROBJ_WORLD_BLUR_PANEL
                  borderRadius = [0, 0, 0, hdpx(5)]
                  fillColor = Color(67, 67, 67)
                  padding = hdpx(3)
                  hplace = ALIGN_RIGHT
                  children = mkText($"{loc("ui/multiply")}{chronogeneItem.count}")
                },
                isAvailable ? null : lock
              ]
            }
          ]
        }, function() {
          if (isAvailable) {
            if (onClickOverrideFunc) {
              onClickOverrideFunc(chronogeneItem)
            }
            else if (currentChronogenes.get()) {
              let newContainer = clone(currentChronogenes.get())
              newContainer.secondaryChronogenes[currentChronogeneIdx] = (chronogeneItem?.uniqueId ?? "0")
              sendRawChronogenes(newContainer)
            }

            removeModalPopup("secondaryChronogeneSelectionPopup")
          }
          else {
            showMsgbox({ text = loc("clonesMenu/secondaryChronogeneNotAvailable") })
          }
      }, {
        size = FLEX_H
        halign = ALIGN_LEFT
        valign = ALIGN_CENTER
        style = getStyle(isCurrent, isAvailable)
        xmbNode = XmbNode()
        padding = hdpx(1)
        stateFlags
        onHover = function(on) {
          if (on) {
            selectedMainChronogeneItem.set(chronogeneItem)
            hoverHotkeysWatchedList.set(hoverPcHotkeysPresentation?[GENES_SECONDARY.name](chronogeneItem))
            setTooltip(getChronogeneTooltip(chronogeneItem))
          }
          else {
            selectedMainChronogeneItem.set(null)
            hoverHotkeysWatchedList.set(null)
            setTooltip(null)
          }
        }
      })
    ]
  }
}

let closeSecodaryChronogenesPanel = fontIconButton(
  "icon_buttons/x_btn.svg",
  @() removeModalPopup("secondaryChronogeneSelectionPopup"),
  static {
    fontSize = hdpx(30)
    size = hdpx(30)
    hplace = ALIGN_RIGHT
    skipDirPadNav = true
    sound = {
      click = null 
      hover = "ui_sounds/button_highlight"
    }
  }
)

function chronogeneListPanel(currentChronogeneIdx, availableChronogenes, equippedChronogenes, onClickOverrideFunc=null) {
  let curUniqueId = equippedChronogenes[currentChronogeneIdx]
  let isCurrentSlotEmpty = curUniqueId == "0" || curUniqueId == null

  let chronogeneList = availableChronogenes

  let notAvailableChronogenes =
    allChronogenesInGame.get()
      .filter(@(notAvailableChrono) notAvailableChrono?.type == "chronogene" && chronogeneList.findindex(@(v) v.itemTemplate == notAvailableChrono.itemTemplate) == null)
      .map(@(v) mkFakeItem(v.itemTemplate))
      .sort(@(a, b) loc(a.itemName) <=> loc(b.itemName))

  let availableChronogenesList = mergeNonUniqueItems(chronogeneList)

  return {
    size = static [ hdpx(400), flex() ]
    flow = FLOW_VERTICAL
    gap = hdpx(10)
    children = [
      {
        size = FLEX_H
        children = [
          mkText(loc("clonesMenu/secondaryChronogenes"), { vplace = ALIGN_CENTER }.__update(body_txt))
          closeSecodaryChronogenesPanel
        ]
      }
      makeVertScrollExt({
        size = FLEX_H
        flow = FLOW_VERTICAL
        gap = hdpx(2)
        xmbNode = XmbContainer({ scrollSpeed = 10.0 })
        children = [].extend(
          
          isCurrentSlotEmpty ? [] : [mkChronogeneSelectPanel(humanEquipmentSlots.chronogene_secondary, true, currentChronogeneIdx, null, onClickOverrideFunc) ]

          
          availableChronogenesList.map(@(chronogene)
            mkChronogeneSelectPanel(chronogene, true, currentChronogeneIdx, curUniqueId, onClickOverrideFunc))

          
          notAvailableChronogenes.map(@(chronogene)
            mkChronogeneSelectPanel(chronogene, false, currentChronogeneIdx, curUniqueId, onClickOverrideFunc))

        )
      }, {
        styling = thinStyle
      })
    ]
  }
}
let rightArrow = mkSelectPanelTextCtor(fa["angle-right"], fontawesome.__merge({fontSize = hdpx(30)}))
let selectableChronogeneItemState = Watched(null)
function mkSelectableChronogeneItem(chronogeneItem, idx) {
  let textCtor = mkSelectPanelTextCtor(loc(chronogeneItem?.itemName ?? $"{loc(humanEquipmentSlots.chronogene_secondary.slotTooltip)} #{idx+1}"), body_txt)
  return mkSelectPanelItem({
    children = @(params) {
      size = FLEX_H
      flow = FLOW_HORIZONTAL
      clipChildren = true
      padding = static [ 0, hdpx(10), 0, hdpx(4)]
      gap = hdpx(15)
      children = [
        mkChronogeneImage(chronogeneItem)
        textCtor(params)
        {size = static [flex(), 0]}
        rightArrow(params)
      ]
    }
    tooltip_text = getChronogeneTooltip(chronogeneItem)
    idx
    state = selectableChronogeneItemState
    cb = function(event) {
      selectableChronogeneItemState.set(idx)
      let { r } = event.targetRect

      let equippedChronogenes = currentChronogenes.get()?.secondaryChronogenes ?? []
      let chronogeneList = []
        .extend(
          stashItems.get() ?? [],
          equipment.get().values() ?? []
        )
        .filter(@(item) item?.filterType == "chronogene" && (equippedChronogenes.findindex(@(v) v == item?.uniqueId) == null
          || equippedChronogenes[idx] == item?.uniqueId))
        .sort(@(a, b) loc(a.itemName) <=> loc(b.itemName))

      addModalPopup( [ r + hdpx(10), hdpx(50)], {
        rendObj = ROBJ_WORLD_BLUR_PANEL
        size = [SIZE_TO_CONTENT, sh(90) - safeAreaVerPadding.get() * 2]
        uid = "secondaryChronogeneSelectionPopup"
        fillColor = ConsoleFillColor
        popupValign = ALIGN_CENTER
        popupHalign = ALIGN_LEFT
        margin = [safeAreaVerPadding.get(), 0, 0,0]
        flow = FLOW_VERTICAL
        gap = hdpx(10)
        borderWidth = 0
        onDetach = @() selectableChronogeneItemState.set(-1)
        children = chronogeneListPanel(idx, chronogeneList, equippedChronogenes)
      })
    }
    visual_params = {
      size = FLEX_H
      padding = 0
    }
    border_align = BD_LEFT
  })
}

function equippedSecondaryChronogenes() {
  let watch = [ playerBaseState, currentChronogenes ]
  if (playerBaseState.get()?.maxSecondaryChronogenesCount == null || currentChronogenes.get()?.secondaryChronogenes == null) {
    return { watch }
  }

  let secondaryGeneItems = []

  for (local i = 0; i < (playerBaseState.get()?.maxSecondaryChronogenesCount ?? 0); i++) {
    let chronogeneItem = chronogeneOrStub(currentChronogenes.get()?.secondaryChronogenes[i] ?? 0)
    secondaryGeneItems.append(mkSelectableChronogeneItem(chronogeneItem, i))
  }
  return {
    watch
    size = FLEX_H
    flow = FLOW_HORIZONTAL
    gap = hdpx(5)
    children = [
      {
        rendobj = ROBJ_SOLID
        size = FLEX_H
        color = panelRowColor
        flow = FLOW_VERTICAL
        gap = hdpx(4)
        children = secondaryGeneItems
      }
    ]
  }
}


function mkEquippedMainChronogenes() {
  let stateFlags = Watched(0)
  return function () {
    let currentMainChronogeneId = currentChronogenes.get()?.primaryChronogenes[0]
    let watch = [ currentChronogenes, equipment ]
    if (currentMainChronogeneId == null) {
      return { watch }
    }
    let currentAlter = getChronogeneItemByUniqueId(currentMainChronogeneId)
    let children = [
      {
        flow = FLOW_HORIZONTAL
        size = static [ hdpxi(550), hdpxi(320) ]
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        gap = hdpx(10)
        children = [
          currentAlter?.iconName == null ? null
            : @() {
                watch = stateFlags
                size = [hdpxi(200), hdpxi(300)]
                behavior = Behaviors.Button
                onElemState = @(sf) stateFlags.set(sf)
                clipChildren = true
                onClick = @() openMenu($"{ClonesMenuId}/{AlterSelectionSubMenuId}")
                children = [
                  mkAlterBackgroundTexture(currentAlter?.itemRarity)
                  {
                    transform = { scale = stateFlags.get() & S_HOVER ? [1.04, 1.04] : [1, 1] }
                    transitions = [{ prop = AnimProp.scale, duration = 0.4, easing = OutQuintic }]
                    children =  mkChronogeneDoll(currentAlter?.itemTemplate, [ hdpxi(200), hdpxi(300)],
                      getChronogenePreviewPresentation(currentAlter?.itemTemplate))
                  }
                  {
                    rendObj = ROBJ_BOX
                    size = flex()
                    borderWidth = hdpx(1)
                    borderColor = stateFlags.get() & S_HOVER ? BtnBdHover : BtnBdDisabled
                  }
                ]
            }
          mkMainChronogeneInfoStrings(currentAlter, {margin = static [hdpx(10) ,0,0,0], size = static [hdpx(300), flex()]})
        ]
      }
      textButton( loc("clonesMenu/selectMainChronogene"),
        @() openMenu($"{ClonesMenuId}/{AlterSelectionSubMenuId}"),
        {
          size = static [flex(), hdpx(44)]
          halign = ALIGN_CENTER
          vplace = ALIGN_BOTTOM
          margin = 0
        }
      )
    ]

    return {
      watch
      onDetach = closeMainChronogeneSelection
      flow = FLOW_VERTICAL
      children
    }
  }
}

return {
  equippedSecondaryChronogenes
  mkEquippedMainChronogenes
  findItemInAllItems
  mkChronogeneDoll
  mkMainChronogeneInfoStrings
  chronogeneListPanel
}
