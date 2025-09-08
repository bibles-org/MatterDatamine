from "%ui/ui_library.nut" import *

let { mkHelpConsoleScreen, mkConsoleScreen } = require("%ui/components/commonComponents.nut")
let { cleanableItems, amProcessingTask,
      playerBaseState } = require("%ui/profile/profileState.nut")
let { addTabToDevInfo } = require("%ui/devInfo.nut")
let { get_sync_time } = require("net")
let { mkAmProcessingItemPanel, refineIsProcessing, refinesReady } = require("amProcessingSelectItem.nut")
let { sound_play } = require("%dngscripts/sound_system.nut")
let { wrapInStdPanel, screenSize } = require("%ui/mainMenu/stdPanel.nut")
let { safeAreaVerPadding } = require("%ui/options/safeArea.nut")

addTabToDevInfo("cleanableItems", cleanableItems)
addTabToDevInfo("amProcessingTask", amProcessingTask, "console commands: \n    profile.force_change_pouch_enrichment <is_enrich> (UI reload require after)\n")
addTabToDevInfo("playerBaseState", playerBaseState, "console commands: \n    profile.force_open_refiner\n    profile.force_set_replicators_count <count>\n")

let help_data = {
  content = "amClean/helpContent"
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
      }
    }, id)
    timerNum++
  }
}

amProcessingTask.subscribe(function(_v){
  resetRefineTimer()
})

const AmCleanMenuId = "Am_clean"
let name = loc("amClean/extractionFacility")
let windowName = loc("amClean/title")

function mkAmProcessing() {

  let availableSlots = Computed(@() playerBaseState.get()?.openedAMCleaningDevices ?? 0)

  let helpConsole = mkHelpConsoleScreen(Picture("ui/build_icons/am_cleaning_device.avif:{0}:{0}:P".subst(hdpx(600))), help_data)

  function content() {
    let needShowHelp = availableSlots.get() == 0
    return {
      watch = [ availableSlots, safeAreaVerPadding ]
      size = flex()
      children = wrapInStdPanel(AmCleanMenuId, needShowHelp ? helpConsole : mkConsoleScreen(mkAmProcessingItemPanel),
        windowName, helpConsole, null, needShowHelp ? null : {size = [hdpx(960), screenSize[1]-safeAreaVerPadding.get()*2]})
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