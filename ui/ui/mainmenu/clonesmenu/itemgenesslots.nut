import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *
from "%ui/fonts_style.nut" import body_txt, fontawesome
import "%ui/components/colors.nut" as colors

let { mkEquipmentSlot } = require("%ui/hud/menus/components/inventorySuit.nut")
let { currentChronogenes, sendRawChronogenes } = require("cloneMenuState.nut")
let { playerBaseState } = require("%ui/profile/profileState.nut")
let { inventoryImageParams } = require("%ui/hud/menus/components/inventoryItemImages.nut")
let { mkFakeItem } = require("%ui/hud/menus/components/fakeItem.nut")
let { humanEquipmentSlots } = require("%ui/hud/state/equipment_slots_stubs.nut")
let { GENES_SECONDARY } = require("%ui/hud/menus/components/inventoryItemTypes.nut")
let { mkText, mkSelectPanelItem, mkSelectPanelTextCtor, BD_LEFT, fontIconButton } = require("%ui/components/commonComponents.nut")
let { BtnBgHover, panelRowColor, Inactive, ConsoleFillColor } = require("%ui/components/colors.nut")
let { secondaryGeneEquipped, allChronogenesInGame, selectedMainChronogeneItem } = require("itemGenes.nut")
let { mergeNonUniqueItems } = require("%ui/hud/menus/components/inventoryItemUtils.nut")
let { button, textButton } =  require("%ui/components/button.nut")
let { makeVertScrollExt, thinStyle } = require("%ui/components/scrollbar.nut")
let { showMsgbox } = require("%ui/components/msgbox.nut")
let { setTooltip } = require("%ui/components/cursors.nut")
let { hoverHotkeysWatchedList } = require("%ui/components/pcHoverHotkeyHitns.nut")
let { hoverPcHotkeysPresentation } = require("%ui/hud/menus/components/inventoryActionsHints.nut")
let { findItemInAllItems,
      getChronogeneItemByUniqueId, mkMainChronogeneInfoStrings,
      mkChronogeneDoll, getChronogenePreviewPresentation, mkChronogeneImage, getChronogeneTooltip } = require("clonesMenuCommon.nut")
let faComp = require("%ui/components/faComp.nut")
let { openMainChronogeneSelection, closeMainChronogeneSelection } = require("mainChronogeneSelection.nut")
let { addModalPopup, removeModalPopup } = require("%ui/components/modalPopupWnd.nut")
let { stashItems } = require("%ui/hud/state/inventory_items_es.nut")
let { equipment } = require("%ui/hud/state/equipment.nut")
let fa = require("%ui/components/fontawesome.map.nut")
let { safeAreaVerPadding } = require("%ui/options/safeArea.nut")
let { screenSize } = require("%ui/mainMenu/stdPanel.nut")

let mkChronogene = @(chronogene_template) mkFakeItem(chronogene_template, {
  isDragAndDropAvailable = false
})

function chronogeneOrStub(id){
  let item = findItemInAllItems(id)
  if (item?.templateName != null)
    return mkChronogene(item.templateName).__update({ uniqueId = id })
  return humanEquipmentSlots.chronogene_secondary 
}

function mkChronogeneEquipmentSlot(container, chronogenListName, idx) {
  let containerVal = type(container) == "instance" ? container.get() : container
  let currentChronogeneIdx =  containerVal?[chronogenListName][idx] ?? 0

  let slot = chronogeneOrStub(currentChronogeneIdx)
  return mkEquipmentSlot(slot)
}

function mkGeneSlot(chronogeneItem, onClick) {
  return function() {
    let slotAndItem = chronogeneItem.__merge(humanEquipmentSlots.chronogene_secondary, { isDragAndDropAvailable = false })
    return {
      watch = currentChronogenes
      rendObj = ROBJ_BOX
      borderWidth = chronogeneItem?.itemTemplate != null ? hdpx(2) : 0
      borderColor = BtnBgHover
      children = mkEquipmentSlot(slotAndItem,
        {
          canDrop = @(_) false,
          onClick
        }
        inventoryImageParams,
        null
      )
    }
  }
}

let lock = faComp("lock", {
  color = Inactive
  padding = hdpx(8)
  fontSize = hdpx(15)
  hplace = ALIGN_RIGHT
  vplace = ALIGN_CENTER
})

let getStyle = memoize(@(isCurrent) freeze({
    BtnBgNormal = isCurrent ? colors.BtnBgSelected : colors.SelBgNormal
    BtnBdNormal = mul_color(colors.BtnBdHover, 0.2, 10)
  })
)
function mkChronogeneSelectPanel(chronogeneItem, isAvailable, currentChronogeneIdx, curUniqueId, onClickOverrideFunc=null) {
  let isCurrent = curUniqueId != null && curUniqueId != 0 && (
    curUniqueId == chronogeneItem?.uniqueId ||
    curUniqueId == chronogeneItem?.itemTemplate 
  )

  return {
    size = [ flex(), SIZE_TO_CONTENT ]
    flow = FLOW_HORIZONTAL
    gap = hdpx(1)
    children = [
      button({
          size = [ flex(), SIZE_TO_CONTENT ]
          flow = FLOW_HORIZONTAL
          gap = hdpx(4)
          children = [
            mkChronogeneImage(chronogeneItem),
            mkText(loc(chronogeneItem?.itemName) ?? loc("clonesMenu/emptySecondaryChronogeneSlot"), {
              hplace = ALIGN_LEFT
              vplace = ALIGN_CENTER
              size = [flex(), SIZE_TO_CONTENT]
              padding = [0,0,0,hdpx(10)]
            }),
            (chronogeneItem?.count ?? 0) <= 1 ? null : {
              rendObj = ROBJ_WORLD_BLUR_PANEL
              borderRadius = [0, 0, 0, hdpx(5)]
              fillColor = Color(67, 67, 67)
              padding = hdpx(3)
              children = mkText($"{loc("ui/multiply")}{chronogeneItem.count}")
            },
            isAvailable ? null : lock
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
        size = [ flex(), SIZE_TO_CONTENT ]
        halign = ALIGN_LEFT
        valign = ALIGN_CENTER
        style = getStyle(isCurrent)
        xmbNode = XmbNode()
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
  const {
    fontSize = hdpx(30)
    size = [ hdpx(30), hdpx(30) ]
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

  return {
    size = [ hdpx(400), flex() ]
    flow = FLOW_VERTICAL
    gap = hdpx(10)
    children = [
      {
        size = [ flex(), SIZE_TO_CONTENT ]
        children = [
          mkText(loc("clonesMenu/secondaryChronogenes"), { vplace = ALIGN_CENTER }.__update(body_txt))
          closeSecodaryChronogenesPanel
        ]
      }
      makeVertScrollExt({
        size = [ flex(), SIZE_TO_CONTENT ]
        flow = FLOW_VERTICAL
        gap = -1
        xmbNode = XmbContainer({ scrollSpeed = 10.0 })
        children = [].extend(
          
          isCurrentSlotEmpty ? [] : [ mkChronogeneSelectPanel(humanEquipmentSlots.chronogene_secondary, true, currentChronogeneIdx, null, onClickOverrideFunc) ]

          
          mergeNonUniqueItems(chronogeneList).map(function(chronogene) {
            return mkChronogeneSelectPanel(chronogene, true, currentChronogeneIdx, curUniqueId, onClickOverrideFunc)
          })

          
          notAvailableChronogenes.map(function(chronogene) {
            return mkChronogeneSelectPanel(chronogene, false, currentChronogeneIdx, curUniqueId, onClickOverrideFunc)
          })

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
      size = [ flex(), SIZE_TO_CONTENT ]
      flow = FLOW_HORIZONTAL
      clipChildren = true
      padding = [ 0, hdpx(10), 0, hdpx(4)]
      gap = hdpx(15)
      children = [
        mkChronogeneImage(chronogeneItem)
        textCtor(params)
        {size = [flex(), 0]}
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

      addModalPopup( [ r + hdpx(10), hdpx(126)], {
        rendObj = ROBJ_WORLD_BLUR_PANEL
        size = [SIZE_TO_CONTENT, screenSize[1] - safeAreaVerPadding.get() * 2]
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
      size = [ flex(), SIZE_TO_CONTENT ]
      padding = 0
    }
    border_align = BD_LEFT
  })
}

let mkSpeedUpButton = @() {
  watch = secondaryGeneEquipped
  size = [ flex(), hdpx(44) ]
  children = button(
    {
      size = flex()
      flow = FLOW_HORIZONTAL
      gap = hdpx(15)
      valign = ALIGN_CENTER
      halign = ALIGN_CENTER
      children = [
        faComp("refresh", {
          fontSize = hdpx(26)
          hplace = ALIGN_LEFT
          vplace = ALIGN_CENTER
        })
        mkText(loc("clonesMenu/recharge"), body_txt)
      ]
    },
    @() showMsgbox({ text = secondaryGeneEquipped.get().findvalue(@(v) v != "0" && v != 0) != null
      ? loc("clonesMenu/noRecharge")
      : loc("clonesMenu/noActive")
    }),
    {
      size = flex()
      onHover = @(on) setTooltip(on ? loc("clonesMenu/recharge") : null)
    }
  )
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
    size = [ flex(), SIZE_TO_CONTENT ]
    flow = FLOW_HORIZONTAL
    gap = hdpx(5)
    children = [
      {
        rendobj = ROBJ_SOLID
        size = [ flex(), SIZE_TO_CONTENT ]
        color = panelRowColor
        flow = FLOW_VERTICAL
        gap = hdpx(4)
        children = secondaryGeneItems.append(mkSpeedUpButton)
      }
    ]
  }
}


function mkEquippedMainChronogenes() {
  let currentMainChronogeneId = currentChronogenes.get()?.primaryChronogenes[0]
  let watch = currentChronogenes
  if (currentMainChronogeneId == null) {
    return { watch }
  }
  let currentAlter = getChronogeneItemByUniqueId(currentMainChronogeneId)
  let children = [
    {
      flow = FLOW_HORIZONTAL
      margin = [ hdpx(10), hdpx(10), hdpx(10), 0 ]
      gap = hdpx(10)
      children = [
        currentAlter?.iconName != null ? mkChronogeneDoll(currentAlter.iconName, [ hdpxi(200), hdpxi(300)],
          getChronogenePreviewPresentation(currentAlter?.itemTemplate)) : null
        mkMainChronogeneInfoStrings(currentAlter, {margin = 0, size = [hdpx(300), flex()]})
      ]
    }
    textButton( loc("clonesMenu/selectMainChronogene"),
      @() openMainChronogeneSelection(),
      {
        size = [flex(), hdpx(44)]
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

return {
  mkChronogeneEquipmentSlot
  mkGeneSlot
  equippedSecondaryChronogenes
  mkEquippedMainChronogenes
  findItemInAllItems
  mkChronogeneDoll
  mkMainChronogeneInfoStrings
  chronogeneListPanel
}
