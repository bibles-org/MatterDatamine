from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let nexusPlayersConnected = Watched(0)
let nexusPlayersExpected = Watched(0)
let nexusPlayersNeedToStart = Watched(0)
let nexusPlayersLeftToStart = Watched(0)

ecs.register_es("nexus_track_players_connected_es", {
  [["onChange", "onInit"]] = function(_evt, _eid, comp){
    nexusPlayersConnected.set(comp.nexus_players_controller__numPlayersConnected)
    nexusPlayersExpected.set(comp.nexus_players_controller__numPlayersExpected)
  }
},
{
  comps_track = [
    ["nexus_players_controller__numPlayersConnected", ecs.TYPE_INT],
    ["nexus_players_controller__numPlayersExpected", ecs.TYPE_INT],
  ]
},
{
  tags = "gameClient"
})

ecs.register_es("nexus_track_players_left_to_start_es", {
  [["onChange", "onInit"]] = function(_evt, _eid, comp){
    nexusPlayersNeedToStart.set(comp.nexus_game_start__numPlayersNeedToStart)
    nexusPlayersLeftToStart.set(comp.nexus_game_start__numPlayersLeftToStart)
  }
},
{
  comps_track = [
    ["nexus_game_start__numPlayersNeedToStart", ecs.TYPE_INT],
    ["nexus_game_start__numPlayersLeftToStart", ecs.TYPE_INT]
  ]
},
{
  tags = "gameClient"
})


return {
  nexusPlayersConnected
  nexusPlayersExpected
  nexusPlayersNeedToStart
  nexusPlayersLeftToStart
}
