from "%ui/fonts_style.nut" import body_txt
from "%dngscripts/sound_system.nut" import sound_play
from "%ui/components/colors.nut" import InfoTextValueColor
from "%ui/mainMenu/stdPanel.nut" import screenSize
from "%ui/components/commonComponents.nut" import mkHelpConsoleScreen, mkConsoleScreen, mkTextArea
from "net" import get_sync_time
from "%sqstd/string.nut" import utf8ToUpper
from "%ui/mainMenu/amProcessingSelectItem.nut" import mkAmProcessingItemPanel, refineIsProcessing
from "%ui/mainMenu/stdPanel.nut" import wrapInStdPanel
from "%ui/profile/profileState.nut" import amProcessingTask, playerBaseState, playerProfileCurrentContracts
import "%ui/components/colorize.nut" as colorize
from "%ui/components/button.nut" import textButton
from "%ui/components/accentButton.style.nut" import accentButtonStyle
from "%ui/matchingQueues.nut" import matchingQueuesMap
from "%ui/mainMenu/raid_preparation_window_state.nut" import Missions_id
from "%ui/gameModeState.nut" import raidToFocus, selectedPlayerGameModeOption
from "%ui/hud/hud_menus_state.nut" import openMenu
from "%ui/mainMenu/contractWidget.nut" import contractToFocus, getContracts, isRightRaidName
from "%ui/ui_library.nut" import *

let { refinesReady, finishRefine, autoFinishRefine } = require("%ui/mainMenu/amProcessingSelectItem.nut")
let { safeAreaVerPadding } = require("%ui/options/safeArea.nut")

let mk_help_data = @(firstAccess = null) {
  content = "amClean/helpContent"
  firstAccess
  components = [
    "amClean/helpComponent1",
    "amClean/helpComponent2"
  ]
  footnotes = [
    "amClean/helpFootnote1",
    "amClean/helpFootnote2",
    "amClean/helpFootnote3",
    "amClean/helpFootnote4",
    "amClean/helpFootnote5",
    "amClean/helpFootnote6",
    "amClean/helpFootnote7",
    "amClean/helpFootnote8",
    "amClean/helpFootnote9",
    "amClean/helpFootnote10",
    "amClean/helpFootnote11",
    "amClean/helpFootnote12",
    "amClean/helpFootnote13",
    "amClean/helpFootnote14",
    "amClean/helpFootnote15",
    "amClean/helpFootnote16",
    "amClean/helpFootnote17",
    "amClean/helpFootnote18",
    "amClean/helpFootnote19",
    "amClean/helpFootnote20",
    "amClean/helpFootnote21"
  ]
}

function resetRefineTimer() {
  local timerNum = 0
  let task = amProcessingTask.get()
  let isProcessing = refineIsProcessing(amProcessingTask.get())
  if (isProcessing) {
    refinesReady.set(0)
    let waitTime = task.endTimeAt.tofloat() - get_sync_time()
    let id = $"refine_timer"
    gui_scene.resetTimeout(waitTime, function() {
      if (refineIsProcessing(amProcessingTask.get())) {
        sound_play("ui_sounds/process_complete")
        refinesReady.set(1)
        if (autoFinishRefine.get()) {
          autoFinishRefine.set(false)
          finishRefine(amProcessingTask.get(), true)
        }
      }
    }, id)
    timerNum++
  }
}

amProcessingTask.subscribe_with_nasty_disregard_of_frp_update(function(_v) {
  resetRefineTimer()
})

const AmCleanMenuId = "Am_clean"
let deviceName = "AMCleaningDevice"
let name = loc("amClean/extractionFacility")
let windowName = utf8ToUpper(loc("amClean/title"))

function mkAmProcessing() {
  let availableSlots = Computed(@() playerBaseState.get()?.openedAMCleaningDevices ?? 0)
  function content() {
    let needShowHelp = availableSlots.get() == 0
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
            mkTextArea(loc("amClean/firstAccess", {
              contract = colorize(InfoTextValueColor, loc($"contract/{contract?.name}"))
              raid = colorize(InfoTextValueColor, loc((contract?.raidName ?? "").split("+")[1]))
            }), body_txt)
            textButton(loc("missions/goTo"), function() {
              let raidToSelect = matchingQueuesMap.get().findvalue(function(v) {
                return isRightRaidName((v?.extraParams ?? {})?.raidName, contract?.raidName)
              })
              raidToFocus.set({ raid = raidToSelect })
              selectedPlayerGameModeOption.set(raidToSelect?.extraParams.nexus ? "Nexus" : "Raid")
              let contractsList = getContracts(raidToSelect)
              let contractIdx = contractsList.findindex(@(v) v?[1].protoId == contract?.protoId)
              contractToFocus.set(contractIdx)
              openMenu(Missions_id)
            }, accentButtonStyle)
          ]
        }
    }
    let helpData = mk_help_data(firstAccess)

    let helpConsole = mkHelpConsoleScreen(Picture("ui/build_icons/am_cleaning_device.avif:{0}:{0}:P".subst(hdpx(600))), helpData)
    return {
      watch = [ availableSlots, safeAreaVerPadding ]
      size = flex()
      children = wrapInStdPanel(AmCleanMenuId, needShowHelp ? helpConsole : mkConsoleScreen(mkAmProcessingItemPanel),
        windowName, helpConsole, null, needShowHelp ? null : {size = [hdpx(1200), screenSize[1]-safeAreaVerPadding.get()*2]})
    }
  }

  return {
    getContent = @() content
    id = AmCleanMenuId
    notifications = refinesReady
    name
  }
}
return {
  mkAmProcessing,
  AmCleanMenuId,
  am_name = name,
  amProcessingIsAvailable = Computed(@() (playerBaseState.get()?.openedAMCleaningDevices ?? 0) > 0)
}