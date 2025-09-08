from "%ui/ui_library.nut" import *

let { squadMembers } = require("%ui/squad/squadState.nut")
let { nestWatched } = require("%dngscripts/globalState.nut")
let { isOnPlayerBase } = require("%ui/hud/state/gametype_state.nut")

let orderedTeamNicks = nestWatched("orderedTeamNicks", [])

squadMembers.subscribe(function(data) {
  if(!isOnPlayerBase.get())
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

return { orderedTeamNicks }