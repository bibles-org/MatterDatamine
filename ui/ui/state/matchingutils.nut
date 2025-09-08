import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *
let { get_local_unixtime } = require("dagor.time")
let { matchingCall, netStateCall } = require("%ui/matchingClient.nut")
let logM = require("%sqGlob/library_logs.nut").with_prefix("[MATCHING UTILS] ")

local matchingUTCTimestamp = Watched(0)
local localUnixTimestamp = Watched(0)


let matchingTimeQueue = ecs.SqQuery(
  "matchingTimeQueue",
  {
    comps_rw = [
      ["matching_time__matchingUTCTimestamp", ecs.TYPE_INT],
      ["matching_time__localUnixTimestamp", ecs.TYPE_INT]
    ]
  })


function updateMatchingUnixTimestamp(matchingTimestamp, localTimestamp) {
  matchingUTCTimestamp.set(matchingTimestamp)
  localUnixTimestamp.set(localTimestamp)

  matchingTimeQueue.perform(
    function(_evt, comps){
      comps.matching_time__matchingUTCTimestamp = matchingTimestamp
      comps.matching_time__localUnixTimestamp = localTimestamp
    })
}


function requestUpdateMatchingUnixTimestamp() {
  matchingCall(
    "enlmm.get_utc_time",
    function(response) {
      let localTimestamp = get_local_unixtime()

      if ((response?.error ?? 0) != 0) {
        logM($"get_utc_time failed: error={response.error}")
        return
      }

      updateMatchingUnixTimestamp(response?.timestamp ?? 0, localTimestamp)
    })
}


ecs.register_es("matching_utc_time_update_es",
  {
    function onUpdate(_dt, _eid, _comps) {
      requestUpdateMatchingUnixTimestamp()
    }
  },
  {
    comps_rq = [
      ["matching_time__matchingUTCTimestamp", ecs.TYPE_INT],
      ["matching_time__localUnixTimestamp", ecs.TYPE_INT]
    ]
  },
  {
    updateInterval = 60, before="*", after="*"
  }
)

netStateCall(function() {
  requestUpdateMatchingUnixTimestamp()
})


function get_matching_utc_time(){
  if (matchingUTCTimestamp.get() == 0)
    return 0

  let localUnixTime = get_local_unixtime()
  let timePassed = localUnixTime - localUnixTimestamp.get()
  if (timePassed < 0) {
    logM($"timePassed is negative - {timePassed}! localUnixTime={localUnixTime}, localUnixTimestamp={localUnixTimestamp.get()}, matchingUTCTimestamp={matchingUTCTimestamp.get()}")
    return 0
  }

  return matchingUTCTimestamp.get() + timePassed
}


return {
  get_matching_utc_time
}