from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs
from "dagor.math" import Point2
from "%ui/components/colors.nut" import BtnBdActive
from "dasevents" import EventCloseShowroom, EventUIMouseMoved, EventUIMouseWheelUsed, EventInitialAlterSelected, EventGameTrigger, broadcastNetEvent
from "%ui/components/commonComponents.nut" import mkText, mkTextArea
from "%ui/fonts_style.nut" import body_txt, h2_txt
from "%ui/mainMenu/clonesMenu/itemGenesSlots.nut" import mkMainChronogeneInfoStrings
from "%ui/components/button.nut" import buttonWithGamepadHotkey
from "%ui/components/accentButton.style.nut" import accentButtonStyle
from "%ui/hud/hud_menus_state.nut" import openMenu
from "%ui/hud/menus/components/fakeItem.nut" import mkFakeItem
from "%ui/components/modalWindows.nut" import addModalWindow, removeModalWindow
from "%ui/mainMenu/clonesMenu/cloneMenuState.nut" import alterRewardWindowOpened
from "%sqstd/rand.nut" import shuffle
from "%ui/hud/menus/components/inventoryItemImages.nut" import inventoryItemImage, highInventoryImageParams
from "%ui/components/msgbox.nut" import showMessageWithContent
from "%ui/mainMenu/clonesMenu/clonesMenuCommon.nut" import mkAlterIconParams
from "%ui/components/scrollbar.nut" import makeVertScrollExt, thinStyle

from "%ui/mainMenu/clonesMenu/mainChronogeneSelection.nut" import mainChronogenesCards, hoveredAlter,
  updateAlterTemplateInShowroom, selectedPreviewAlter, mkAlterBackgroundTexture

let { marketItems } = require("%ui/profile/profileState.nut")
let JB = require("%ui/control/gui_buttons.nut")
let { isOnboardingMemory, onboardingStateMachineCurrentStateEid } = require("%ui/hud/state/onboarding_state.nut")

const mainChronogeneRewardScreenId = "mainChronogeneRewardScreen"
let mainChronogeneRewardScreenName = loc("clonesControlMenu/mainChronogeneReward")

let selectedAlter = keepref(Computed(function() {
  let hovered = hoveredAlter.get()
  if (hovered)
    return hovered
  let selected = selectedPreviewAlter.get()
  if (selected)
    return selected

  return null
}))

let altersToSelectOf = Watched(null)

const WND_UID = "chronogeneRewardSelection"


function getFakeAlterItemFromMarketItems(marketAlterOffers) {
  if (marketAlterOffers == null)
    return []
  return marketAlterOffers.map(function(marketId) {
    let market = marketItems.get()?[marketId]
    if (market == null)
      throw null

    return mkFakeItem(market.children.items[0].templateName, { marketId })
  })
}

function selectReward(fakedAlter) {
  let templateName = fakedAlter?.itemTemplate
  let marketOffer = fakedAlter?.marketId
  if (templateName == null || marketOffer == null) {
    return
  }
  let { attachments, alterIconParams } = mkAlterIconParams(templateName)
  let fake = mkFakeItem(templateName, alterIconParams, attachments)
  showMessageWithContent({
    content = {
      size = static [sw(80), SIZE_TO_CONTENT]
      flow = FLOW_VERTICAL
      gap = static hdpx(40)
      halign = ALIGN_CENTER
      children = [
        mkTextArea(loc("clonesMenu/rewardSelectionConfirm"), { halign = ALIGN_CENTER }.__merge(h2_txt)),
        {
          rendObj = ROBJ_BOX
          borderWidth = static hdpx(4)
          borderColor = BtnBdActive
          padding = static hdpx(4)
          children = [
            mkAlterBackgroundTexture(fake?.itemRarity)
            inventoryItemImage(fake, highInventoryImageParams)
          ]
        },
        mkMainChronogeneInfoStrings(fakedAlter, { size = static [min(hdpx(450), sw(25)), SIZE_TO_CONTENT] })
      ]
    }
    buttons = [
      {
        text = loc("clonesMenu/backToSelection")
        isCancel = true
      }
      {
        text = loc("clonesMenu/selectAlter")
        action = @()   ecs.g_entity_mgr.broadcastEvent(EventInitialAlterSelected({alter=templateName, offer=marketOffer}))
        isCurrent = true
        customStyle = accentButtonStyle
      }
    ]
  })
}


let mainChronogeneRewardScreenMenu = {
  getContent = @() @() {
    size = flex()
    id = mainChronogeneRewardScreenId
    name = mainChronogeneRewardScreenName
    flow = FLOW_VERTICAL
    gap = hdpx(70)
    vplace = ALIGN_BOTTOM
    onDetach = function() {
      alterRewardWindowOpened.set(false)
      ecs.g_entity_mgr.broadcastEvent(EventCloseShowroom())
    }
    onAttach = function() {
      let firstAlter = getFakeAlterItemFromMarketItems([ altersToSelectOf.get()[0] ])?[0]
      if (firstAlter?.templateName != null) {
        updateAlterTemplateInShowroom(firstAlter?.templateName, Point2(0.5, 0.55))
        selectedPreviewAlter.set(firstAlter)
      }
      else
        updateAlterTemplateInShowroom(null, Point2(0.6, 0.55))
      alterRewardWindowOpened.set(true)
    }
    hotkeys = [[$"Esc | {JB.B}", { action = @() null }]]
    children = [
      mkTextArea(loc("clonesMenu/rewardSelectionTitle"), { halign = ALIGN_CENTER }.__merge(h2_txt))
      {
        size = flex()
        flow = FLOW_HORIZONTAL
        children = [
          @() {
            watch = altersToSelectOf
            size = FLEX_V
            children = mainChronogenesCards(selectReward, getFakeAlterItemFromMarketItems(altersToSelectOf.get()), [], 2)
          }
          {
            size = flex()
            halign = ALIGN_CENTER
            behavior = [Behaviors.MoveResize, Behaviors.WheelScroll]
            stopMouse = false
            skipDirPadNav = true
            onMoveResize = @(dx, dy, _dw, _dh) ecs.g_entity_mgr.broadcastEvent(EventUIMouseMoved({screenX = dx, screenY = dy}))
            onWheelScroll = @(value) ecs.g_entity_mgr.broadcastEvent(EventUIMouseWheelUsed({value}))
            children = [
              function() {
                let textBlock = mkText(loc("clonesMenu/selectEquipAlter"), { hplace = ALIGN_CENTER }.__merge(body_txt))
                let textWidth = calc_comp_size(textBlock)[0]
                return {
                  watch = [selectedPreviewAlter, selectedAlter]
                  size = [min(sw(25), hdpx(425)), flex()]
                  padding = hdpx(5)
                  flow = FLOW_VERTICAL
                  gap = { size = flex() }
                  vplace = ALIGN_BOTTOM
                  hplace = ALIGN_RIGHT
                  children = [
                    mkMainChronogeneInfoStrings(selectedAlter.get(),
                      {
                        margin = 0
                        size = FLEX_H
                      })
                    makeVertScrollExt(mkTextArea(loc($"{selectedAlter.get()?.itemTemplate}/desc"), {
                        size = FLEX_H
                        hplace = ALIGN_LEFT
                      }),
                      {
                        size = [flex(), sh(30)]
                        styling = thinStyle
                      })
                    selectedPreviewAlter.get() == null ? null : buttonWithGamepadHotkey(textBlock,
                      @() selectReward(selectedPreviewAlter.get()), {
                        size = [textWidth + hdpx(80), static hdpx(50)]
                        hotkeys = [["J:X", { description = { skip = true } }]]
                      }.__update(accentButtonStyle) )
                  ]
                }
              }
            ]
          }
        ]
      }
    ]
  }
}

let isMonolithSelectionQuery = ecs.SqQuery("isMonolithSelectionQuery", { comps_rq = ["onboarding_phase_monolith_selection"] })

ecs.register_es("track_is_onboarding_alter_selection_required", {
  onInit = function(_evt, eid, _comp) {
    local isInSelection = false
    isMonolithSelectionQuery.perform(onboardingStateMachineCurrentStateEid.get(), @(...) isInSelection = true)
    if (isOnboardingMemory.get() || isInSelection) {
      ecs.g_entity_mgr.destroyEntity(eid)
      return
    }
    let triggerHash = ecs.calc_hash("forced_onboarding_alter_selection_started")
    broadcastNetEvent(EventGameTrigger({triggerHash}))

    let list = shuffle([ "120008", "120009", "120010", "120011" ])
    altersToSelectOf.set(list)
    addModalWindow({
      size = flex()
      key = WND_UID
      gap = hdpx(10)
      padding = fsh(5)
      onClick = @() null
      eventPassThrough = true
      halign = ALIGN_CENTER
      children = mainChronogeneRewardScreenMenu.getContent()
    })
  }
  onDestroy = function(...) {
    removeModalWindow(WND_UID)
  }
}, {comps_rq=["forced_onboarding_alter_selection"]})

return {
  mainChronogeneRewardScreenId
  mainChronogeneRewardScreenMenu
}