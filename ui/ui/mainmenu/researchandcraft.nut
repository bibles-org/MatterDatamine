from "%ui/fonts_style.nut" import h2_txt, body_txt
from "%ui/mainMenu/stdPanel.nut" import wrapInStdPanel, mkHeader, mkWndTitleComp, mkHelpButton,
  mkCloseBtn, wrapButtons, mkBackBtn
from "%ui/components/cursors.nut" import setTooltip
from "%ui/mainMenu/currencyPanel.nut" import currencyAnim, notEnoughMoneyAnim
from "%ui/components/commonComponents.nut" import mkConsoleScreen, mkHelpConsoleScreen, mkText, mkTextArea
from "%ui/mainMenu/craftSelection.nut" import mkCraftSelection
from "%ui/mainMenu/currencyIcons.nut" import chronotraceTextIcon, chronotracesColor
from "%ui/profile/profileState.nut" import playerBaseState, playerProfileChronotracesCount, playerProfileCurrentContracts
from "%ui/components/colors.nut" import  CurrencyDefColor, CurrencyUseColor, InfoTextValueColor
import "%ui/components/colorize.nut" as colorize
from "%ui/components/button.nut" import textButton
from "%ui/components/accentButton.style.nut" import accentButtonStyle
from "%ui/matchingQueues.nut" import matchingQueuesMap
from "%ui/mainMenu/raid_preparation_window_state.nut" import Missions_id
from "%ui/gameModeState.nut" import raidToFocus, selectedPlayerGameModeOption
from "%ui/hud/hud_menus_state.nut" import openMenu
from "%ui/mainMenu/contractWidget.nut" import contractToFocus, getContracts, isRightRaidName
from "%sqstd/string.nut" import utf8ToUpper

from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { craftsReady, scrollToRecipe } = require("%ui/mainMenu/craftSelection.nut")
let { MonolithMenuId } = require("%ui/mainMenu/monolith/monolith_common.nut")

let mk_help_data = @(firstAccess = null) {
  content = "research/helpContent"
  firstAccess
  components = [
    "research/helpComponent1",
    "research/helpComponent2"
  ]
  footnotes = [
    "research/helpFootnote1",
    "research/helpFootnote2",
    "research/helpFootnote3",
    "research/helpFootnote4",
    "research/helpFootnote5",
    "research/helpFootnote6",
    "research/helpFootnote7",
    "research/helpFootnote8",
    "research/helpFootnote9",
    "research/helpFootnote10",
    "research/helpFootnote11",
    "research/helpFootnote12",
    "research/helpFootnote13",
    "research/helpFootnote14",
    "research/helpFootnote15",
    "research/helpFootnote16",
    "research/helpFootnote17",
    "research/helpFootnote18",
  ]
}

const CRAFT_WND_ID = "craftWindow"
let craftWndName = utf8ToUpper(loc("researchAndCraft/title"))
let deviceName = "ReplicatorDevice"

let mkCraftNotifications = @() Computed(function() {
  let notificationsCount = craftsReady.get()
  let notificationsType = "reward"

  return {
    notificationsCount
    notificationsType
  }
})

function mkChronotracesHeaderIcon() {
  let sf = Watched(0)
  return @() {
    watch = [playerProfileChronotracesCount, sf]
    key = chronotraceTextIcon
    onElemState = @(s) sf.set(s)
    flow = FLOW_HORIZONTAL
    gap = hdpx(1)
    behavior = Behaviors.Button
    skipDirPadNav = true
    onHover = @(on) setTooltip(on ? loc("chronotraces") : null)
    valign = ALIGN_CENTER
    transform = static {}
    animations = currencyAnim(chronotraceTextIcon)
    hplace = ALIGN_RIGHT
    pos = [hdpx(30), 0]
    children = [
      mkText(chronotraceTextIcon, {
        color = sf.get() ? CurrencyUseColor : chronotracesColor
        animations = notEnoughMoneyAnim(chronotraceTextIcon)
      }.__merge(h2_txt))
      mkText(playerProfileChronotracesCount.get(), {
        color = sf.get() ? CurrencyDefColor : CurrencyUseColor
        animations = notEnoughMoneyAnim(chronotraceTextIcon)
      }.__merge(h2_txt))
    ]
  }
}

function mkCraftWnd() {
  let availableSlots = Computed(@() playerBaseState.get()?.openedReplicatorDevices ?? 0)
  let chronotracesOffset = { size = static [ hdpx(40), 0 ] }
  let closeBtn = @() {
    watch = scrollToRecipe
    onDetach = @() scrollToRecipe.set(null)
    children = scrollToRecipe.get() != null ? mkBackBtn(MonolithMenuId)
      : mkCloseBtn(CRAFT_WND_ID)
  }
  function content() {
    let needShowHelp = availableSlots.get() <= 0
    local firstAccess = null
    if (needShowHelp) {
      local contract = null
      foreach (data in playerProfileCurrentContracts.get())
      foreach (reward in (data?.rewards ?? [])) {
        let isNeededContract = (reward?.playerBaseUpgrades ?? []).findindex(@(v) v == deviceName)
        if (isNeededContract != null) {
          contract = data
          break
        }
      }
      if (contract != null)
        firstAccess = {
          size = FLEX_H
          flow = FLOW_VERTICAL
          gap = static hdpx(30)
          halign = ALIGN_CENTER
          children = [
            mkTextArea(loc("research/firstAccess", {
              contract = colorize(InfoTextValueColor, loc($"contract/{contract?.name}"))
              raid = colorize(InfoTextValueColor, loc((contract?.raidName ?? "").split("+")[1]))
            }), body_txt)
            textButton(loc("missions/goTo"), function() {
              let raidToSelect = matchingQueuesMap.get().findvalue(function(v) {
                return isRightRaidName((v?.extraParams ?? {})?.raidName, contract?.raidName)
              })
              selectedPlayerGameModeOption.set(raidToSelect?.extraParams.nexus ? "Nexus" : "Raid")
              raidToFocus.set({ raid = raidToSelect })
              let contractsList = getContracts(raidToSelect)
              let contractIdx = contractsList.findindex(@(v) v?[1].protoId == contract?.protoId)
              contractToFocus.set(contractIdx)
              openMenu(Missions_id)
            }, accentButtonStyle)
          ]
        }
    }
    let helpConsole = {
      size = flex()
      children = mkHelpConsoleScreen(Picture("ui/build_icons/replicator_device.avif:{0}:{0}:P".subst(hdpx(600))),
        mk_help_data(firstAccess))
    }
    let helpBtn = @() {
      watch = availableSlots
      children = availableSlots.get() > 0 ? mkHelpButton(helpConsole, craftWndName) : null
    }
    let header = mkHeader({
      size = FLEX_H
      valign = ALIGN_CENTER
      children = [
        mkWndTitleComp(craftWndName)
        mkChronotracesHeaderIcon()
      ]
    }, wrapButtons(chronotracesOffset, helpBtn, closeBtn))
    return {
      size = flex()
      watch = availableSlots
      children = wrapInStdPanel(CRAFT_WND_ID, availableSlots.get() <= 0 ? helpConsole : mkConsoleScreen(mkCraftSelection),
        craftWndName, helpConsole, header)
    }
  }

  return {
    notifications = mkCraftNotifications
    getContent = @() content
    id = CRAFT_WND_ID
    name = loc("researchAndCraft")
  }
}

return {
  CRAFT_WND_ID
  mkCraftWnd
  craftIsAvailable = Computed(@() (playerBaseState.get()?.openedReplicatorDevices ?? 0) > 0)
  mkCraftNotifications
}