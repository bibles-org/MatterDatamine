from "team" import TEAM_UNASSIGNED

import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *
from "%dngscripts/globalState.nut" import nestWatched

let { localPlayerEid, localPlayerTeam, localPlayerTeamIsIncognito } = require("%ui/hud/state/local_player.nut")

let user_points = Watched({})
let teammatesPointsOpacity = nestWatched("teammatesPointsOpacity", 1.0)
let playerPointsOpacity = nestWatched("playerPointsOpacity", 1.0)

let getPlayerNameQuery = ecs.SqQuery("getNameQuery", {comps_ro = [["name", ecs.TYPE_STRING]], comps_rq=["player"]})
function getPlayerName(playerEid) {
  if (playerEid == ecs.INVALID_ENTITY_ID)
    return null
  let name = getPlayerNameQuery.perform(playerEid, @(_eid, comp) comp.name)
  if (name != null)
    return name
  return null
}

ecs.register_es("user_points_ui_es", {
    function onInit(_evt, eid, comp){
      user_points.mutate(function(v) {
        if (comp.team != TEAM_UNASSIGNED && comp.team != localPlayerTeam.get())
          return

        let res = {
          visible_distance = comp["hud_marker__visible_distance"]
          userPointType = comp.userPointType
        }
        if (comp["userPointOwner"]!=ecs.INVALID_ENTITY_ID) {
          let isLocalPlayer = comp.userPointOwner == localPlayerEid.get()
          if (localPlayerTeamIsIncognito.get() && !isLocalPlayer)
            return
          res.byLocalPlayer <- isLocalPlayer
          res.playerNick <- getPlayerName(comp["userPointOwner"])
        }
        v[eid] <- res
      })
    },
    function onDestroy(_evt, eid, _comp){
      if (eid in user_points.get())
        user_points.mutate(@(v) v.$rawdelete(eid))
    }
  },
  {
    comps_ro = [
      ["userPointType", ecs.TYPE_STRING],
      ["userPointOwner", ecs.TYPE_EID, ecs.INVALID_ENTITY_ID],
      ["team", ecs.TYPE_INT, TEAM_UNASSIGNED],
      ["hud_marker__visible_distance", ecs.TYPE_FLOAT, null]
    ],
  }
)

return {
  user_points,
  teammatesPointsOpacity
  playerPointsOpacity
}
