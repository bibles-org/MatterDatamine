import "console" as console
from "%ui/ui_library.nut" import console_print
from "%ui/quickMatchQueue.nut" import joinQueue
from "%ui/state/queueState.nut" import isQueueHiddenBySchedule
from "%ui/matchingQueues.nut" import isQueueDisabledBySchedule
from "%ui/state/matchingUtils.nut" import get_matching_utc_time
from "%ui/hud/hud_menus_state.nut" import closeAllMenus

let { matchingQueuesMap } = require("%ui/matchingQueues.nut")
let { selectedRaid, queueRaid } = require("%ui/gameModeState.nut")
let { isOnPlayerBase, isInPlayerSession } = require("%ui/hud/state/gametype_state.nut")
let { levelLoaded } = require("%ui/state/appState.nut")
let { useAgencyPreset } = require("%ui/equipPresets/presetsState.nut")


function printAndReturn(value) {
  console_print(value)
  return value
}

function joinPvERaid(raidName) {
  let raid = matchingQueuesMap.get()?[raidName]
  if (raid == null) {
    error($"\"{raidName}\" is disabled")
    return false
  }
  if (!raid.enabled || isQueueDisabledBySchedule(raid, get_matching_utc_time())) {
    error($"\"{raidName}\" is disabled")
    return false
  }

  useAgencyPreset.set(true)
  selectedRaid.set(raid)
  queueRaid.set(raid)

  joinQueue(raid, {})
  return true
}
console.register_command(@(raid_name) printAndReturn(joinPvERaid(raid_name)), "autotest.join_pve_raid")

let getAllowedPvERaids = @() matchingQueuesMap.get().filter(function(v){
  if (v?.extraParams?.nexus ?? false)
    return false
  if (!v.enabled || isQueueHiddenBySchedule(v, get_matching_utc_time()))
    return false
  return true
}).keys()

console.register_command(@() printAndReturn(getAllowedPvERaids()), "autotest.get_allowed_pve_raids")

console.register_command(@() printAndReturn(isOnPlayerBase.get() && levelLoaded.get()), "autotest.is_in_menu")
console.register_command(@() printAndReturn(isInPlayerSession.get() && levelLoaded.get()), "autotest.is_in_raid")
console.register_command(@() closeAllMenus(), "autotest.close_all_menus")
