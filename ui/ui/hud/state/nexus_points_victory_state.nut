from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let nexusPointsToWin = Watched(-1.0)
let nexusTeamPoints = Watched({})

ecs.register_es("nexus_points_victory_init_points_to_win_es", {
  onInit = function(_evt, _eid, comp) {
    nexusPointsToWin.set(comp.nexus_points_victory_game_controller__pointsToWin)
  }
  onDestroy = function(...) {
    nexusPointsToWin.set(-1.0)
  }
}, {
  comps_ro = [
    ["nexus_points_victory_game_controller__pointsToWin", ecs.TYPE_FLOAT]
  ]
},
{
  tags = "gameClient"
})

ecs.register_es("nexus_points_victory_track_team_points_es", {
  [["onChange", "onInit"]] = function(_evt, _eid, comp) {
    nexusTeamPoints.mutate(@(points) points[comp.team__id] <- comp.nexus_points_victory_team__displayPoints)
  }
  onDestroy = function(_evt, _eid, comp) {
    nexusTeamPoints.mutate(@(points) points.$rawdelete($"{comp.team__id}"))
  }
}, {
  comps_track = [
    ["nexus_points_victory_team__displayPoints", ecs.TYPE_FLOAT],
  ]
  comps_ro = [["team__id", ecs.TYPE_INT]]
},
{
  tags = "gameClient"
})

return {
  nexusPointsToWin
  nexusTeamPoints
}
