let console = require("console")
let { console_print } = require("%ui/ui_library.nut")
let { joinQueue } = require("%ui/quickMatchQueue.nut")
let { isQueueHiddenBySchedule } = require("%ui/state/queueState.nut")
let { matchingQueuesMap, isQueueDisabledBySchedule } = require("%ui/matchingQueues.nut")
let { get_matching_utc_time } = require("%ui/state/matchingUtils.nut")
let { selectedRaid, queueRaid } = require("%ui/gameModeState.nut")
let { isOnPlayerBase, isInPlayerSession } = require("%ui/hud/state/gametype_state.nut")
let { levelLoaded } = require("%ui/state/appState.nut")
let { closeAllMenus } = require("%ui/hud/hud_menus_state.nut")


function printAndReturn(value) {
  console_print(value)
  return value
}

function joinMindcontrolledRaid(raidName) {
  let raid = matchingQueuesMap.get()?[raidName]
  if (!(raid?.extraParams?.mindcontrolled ?? false)) {
    error($"\"{raidName}\" doesn't support mindcontrolled raid")
    return false
  }
  if (!raid.enabled || isQueueDisabledBySchedule(raid, get_matching_utc_time())) {
    error($"\"{raidName}\" is disabled")
    return false
  }

  selectedRaid.set(raid)
  queueRaid.set(raid)

  joinQueue(raid, {})
  return true
}
console.register_command(@(raid_name) printAndReturn(joinMindcontrolledRaid(raid_name)), "autotest.join_mindcontrolled_raid")

let getAllowedMindcontrolledRaids = @() matchingQueuesMap.get().filter(function(v){
  if (!(v?.extraParams?.mindcontrolled ?? false))
    return false
  if (!v.enabled || isQueueHiddenBySchedule(v, get_matching_utc_time()))
    return false
  return true
}).keys()

console.register_command(@() printAndReturn(getAllowedMindcontrolledRaids()), "autotest.get_allowed_mindcontrolled_raids")

console.register_command(@() printAndReturn(isOnPlayerBase.get() && levelLoaded.get()), "autotest.is_in_menu")
console.register_command(@() printAndReturn(isInPlayerSession.get() && levelLoaded.get()), "autotest.is_in_raid")
console.register_command(@() closeAllMenus(), "autotest.close_all_menus")
