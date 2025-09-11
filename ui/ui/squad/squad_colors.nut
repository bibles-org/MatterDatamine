from "%dngscripts/globalState.nut" import nestWatched

from "%ui/hud/state/teammates_es.nut" import groupmatesSet, groupmatesGetWatched
from "%ui/ui_library.nut" import *

let userInfo = require("%sqGlob/userInfo.nut")
let { squadMembers } = require("%ui/squad/squadState.nut")
let { isOnPlayerBase } = require("%ui/hud/state/gametype_state.nut")

let orderedTeamNicks = nestWatched("orderedTeamNicks", [])

squadMembers.subscribe_with_nasty_disregard_of_frp_update(function(data) {
  if (!isOnPlayerBase.get())
    return
  if (data.len() <= 1) {
    orderedTeamNicks.set([])
    return
  }

  local res = data
    .reduce(@(res, v) res.append(v?.realnick) ,[])
    .sort(@(a, b) a <=> b)

  orderedTeamNicks.set(res)
})

groupmatesSet.subscribe_with_nasty_disregard_of_frp_update(function(data) {
  if (data.len() <= 0 || isOnPlayerBase.get() || orderedTeamNicks.get().len() > 0)
    return
  let res = data.keys()
    .map(@(v) groupmatesGetWatched(v)?.get().name)
    .append(userInfo.get()?.name)
    .sort(@(a, b) a <=> b)

  orderedTeamNicks.set(res)
})

return { orderedTeamNicks }