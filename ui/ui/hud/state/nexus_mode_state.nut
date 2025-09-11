from "%sqGlob/dasenums.nut" import NexusGameStartState, NexusTeam
from "%dngscripts/globalState.nut" import nestWatched
from "dasevents" import EventNexusGameEnd, EventNexusGameDebriefing
from "team" import TEAM_UNASSIGNED
from "%ui/mainMenu/ribbons_colors_state.nut" import indexToColor
from "dagor.math" import Point4
from "app" import get_session_id
import "%ui/voiceChat/voiceState.nut" as voiceState
from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { localPlayerTeam } = require("%ui/hud/state/local_player.nut")

let nexusSelectedNames = nestWatched("nexusSelectedNames", {})
let mutedNexusPlayersList = nestWatched("mutedNexusPlayersList", {})

let isNexus = Watched(false)
let isNexusWaveMode = Watched(false)
let isNexusRoundMode = Watched(false)

let nexusBeacons = Watched({})
let nexusBeaconEids = Watched([])
let nexusSpawnPoints = Watched({})

let isNexusGameStarted = Watched(false)
let isNexusGameFinished = Watched(false)
let isNexusPlayerExists = Watched(false)
let isNexusPlayerCanSpawn = Watched(false)
let isNexusPlayerCanChangeLoadout = Watched(false)
let isNexusPlayerSpawned = Watched(false)
let isNexusEndGameDebriefing = Watched(false)
let nexusModeTeamColors = Watched([Point4(0.7, 0.7, 0.7, 1).x, Point4(0.7, 0.7, 0.7, 1).y])
let nexusModeTeamColorIndices = Watched([-1, -1])
let nexusModeEnemiesColors = Watched([Point4(1, 1, 1, 1).x, Point4(1, 1, 1, 1).y])
let nexusGameWinner = Watched(-1)
let nexusPlayerSpawnCount = Watched(0)

let nexusAllyTeam = Watched(-1)
let nexusEnemyTeam = Computed(@() nexusAllyTeam.get() == NexusTeam.FIRST ? NexusTeam.SECOND : NexusTeam.FIRST)

let allyTeam = Watched({})
let enemyTeam = Watched({})

ecs.register_es("nexus_battle_track_team_colors_es", {
  onInit = function(_evt, _eid, comp) {

    nexusModeEnemiesColors.set([indexToColor(comp.ribbonNexusEnemyColor.x), indexToColor(comp.ribbonNexusEnemyColor.y)])
    nexusModeTeamColors.set([indexToColor(comp.ribbonNexusAllyColor.x), indexToColor(comp.ribbonNexusAllyColor.y)])
    nexusModeTeamColorIndices.set([comp.ribbonNexusAllyColor.x, comp.ribbonNexusAllyColor.y])
  }
  onDestroy = function(...) {
    nexusModeEnemiesColors.set([indexToColor(-1), indexToColor(-1)])
    nexusModeTeamColors.set([indexToColor(-1), indexToColor(-1)])
    nexusModeTeamColorIndices.set([-1, -1])
  }
}, {
  comps_ro = [["ribbonNexusEnemyColor", ecs.TYPE_IPOINT2], ["ribbonNexusAllyColor", ecs.TYPE_IPOINT2]]
}, {tags = "gameClient"})

localPlayerTeam.subscribe_with_nasty_disregard_of_frp_update(function(team) {
  if (team == TEAM_UNASSIGNED) {
    nexusSelectedNames.set({})
    mutedNexusPlayersList.set({})
    return
  }
})

ecs.register_es("nexus_ally_team_es", {
  [["onChange", "onInit"]] = function(_evt, _eid, comp){
    if (!comp.is_local)
      return
    nexusAllyTeam.set(comp.team)
  },
},
{
  comps_track = [
    ["team", ecs.TYPE_INT],
    ["is_local", ecs.TYPE_BOOL]
  ]
},
{
  tags = "gameClient"
})

ecs.register_es("track_nexus_game_start", {
  [["onChange", "onInit"]] = @(_evt, _eid, comp) isNexusGameStarted.set(comp.nexus_game_controller__isGameStarted)
  onDestroy = @(...) isNexusGameStarted.set(false)
}, {
  comps_track = [ ["nexus_game_controller__isGameStarted", ecs.TYPE_BOOL] ]
}, {tags = "gameClient"})

ecs.register_es("track_nexus_game_end", {
  [["onChange", "onInit"]] = @(_evt, _eid, comp) isNexusGameFinished.set(comp.nexus_game_controller__isGameFinished)
  onDestroy = @(...) isNexusGameFinished.set(false)
}, {
  comps_track = [ ["nexus_game_controller__isGameFinished", ecs.TYPE_BOOL] ]
}, {tags = "gameClient"})

ecs.register_es("nexus_battle_track_beacons_state", {
  onInit = function(_evt, eid, comp) {
    {
      nexusBeaconEids.mutate(@(v) v.append(eid))

      if (nexusBeacons.get()?[eid].state != comp.nexus_beacon__state) {
        anim_start($"nexus_beacon_trigger_{eid}")
      }

      nexusBeacons.mutate(@(beacons) beacons[eid] <- {
        state = comp.nexus_beacon__state
        controllingTeam = comp.nexus_beacon__controllingTeam
        activationProgress = comp.nexus_beacon__progressVisual
        symbol = comp.nexus_beacon__symbol
        name = comp.nexus_beacon__name
        pos = comp.transform[3]
        eid
      })
    }
  },
  onChange = function(_evt, eid, comp) {

    if (comp.nexus_beacon__state != nexusBeacons.get()?[eid].state) {
      anim_start($"nexus_beacon_trigger_{eid}")
    }
    nexusBeacons.mutate(@(beacons) beacons[eid] <- {
      state = comp.nexus_beacon__state
      controllingTeam = comp.nexus_beacon__controllingTeam
      activationProgress = comp.nexus_beacon__progressVisual
      symbol = comp.nexus_beacon__symbol
      name = comp.nexus_beacon__name
      pos = comp.transform[3]
      eid
    })
  }
  onDestroy = function(eid, _comp) {
    nexusBeacons.mutate(@(beacons) beacons.$rawdelete(eid))
    nexusBeaconEids.set([])
  }
}, {
  comps_track = [
    [ "nexus_beacon__state", ecs.TYPE_INT ],
    [ "nexus_beacon__progressVisual", ecs.TYPE_FLOAT ],
    [ "nexus_beacon__controllingTeam", ecs.TYPE_INT ]
  ]
  comps_ro = [
    [ "nexus_beacon__progressToCapture", ecs.TYPE_FLOAT ],
    [ "nexus_beacon__name", ecs.TYPE_STRING ],
    [ "nexus_beacon__symbol", ecs.TYPE_STRING ],
    [ "transform", ecs.TYPE_MATRIX ]
  ]
}, {tags = "gameClient"})


ecs.register_es("nexus_battle_track_spawn_points_state", {
  [["onChange", "onInit"]] = function(_evt, eid, comp) {
    nexusSpawnPoints.mutate(@(points) points[eid] <- {
      team = comp.team
      pos = comp.transform[3]
    })
  }
  onDestroy = function(eid, _comp) {
    nexusSpawnPoints.mutate(@(points) points.$rawdelete(eid))
  }
}, {
  comps_rq = [
    [ "respbase" ]
  ]
  comps_track = [
    [ "team", ecs.TYPE_INT ]
  ]
  comps_ro = [
    [ "transform", ecs.TYPE_MATRIX ]
  ]
}, {tags = "gameClient"})

ecs.register_es("detect_nexus_es", {
  onInit = @(...) isNexus.set(true)
  onDestroy = function(...) {
    isNexus.set(false)
    allyTeam.set({})
    enemyTeam.set({})
    isNexusEndGameDebriefing.set(false)
  }
},
{
  comps_rq = [ "nexus_mode" ]
}, { tags = "gameClient" })

ecs.register_es("detect_nexus_wave_mode_es", {
    onInit = @(...) isNexusWaveMode.set(true)
    onDestroy = @(...) isNexusWaveMode.set(false)
},
{
    comps_rq = [ "nexus_wave_mode" ]
}, { tags = "gameClient" })

ecs.register_es("detect_nexus_round_mode_es", {
  onInit = @(...) isNexusRoundMode.set(true)
  onDestroy = @(...) isNexusRoundMode.set(false)
},
{
  comps_rq = [ "nexus_round_mode" ]
}, { tags = "gameClient" })


let voiceRoomName = Watched("")
isNexus.subscribe_with_nasty_disregard_of_frp_update(function(v){
  if (v && voiceRoomName.get().len() == 0){
    let sessionId = get_session_id()
    let playerTeam = localPlayerTeam.get()
    if (playerTeam || playerTeam == TEAM_UNASSIGNED)
      return
    voiceRoomName.set($"__nexus_{sessionId}_room_{playerTeam}")
    voiceState.join_voice_chat(voiceRoomName.get())
  }
  else if (!v && voiceRoomName.get().len() > 0) {
    voiceState.leave_voice_chat(voiceRoomName.get())
    voiceRoomName.set("")
  }
})
localPlayerTeam.subscribe_with_nasty_disregard_of_frp_update(function(v){
  if (isNexus.get() && v != TEAM_UNASSIGNED){
    let sessionId = get_session_id()
    voiceRoomName.set($"__nexus_{sessionId}_room_{v}")
    voiceState.join_voice_chat(voiceRoomName.get())
  }
})

ecs.register_es("nexus_track_is_hero_spawned_es", {
  [["onChange", "onInit"]] = function(_evt, _eid, comp){
    if (!comp.is_local)
      return
    isNexusPlayerExists.set(true)
    isNexusPlayerCanSpawn.set(comp.nexus_player__canSpawn)
    isNexusPlayerCanChangeLoadout.set(comp.nexus_player__canChangeLoadout)
    isNexusPlayerSpawned.set(comp.nexus_player__spawned)
    nexusPlayerSpawnCount.set(comp.nexus_player__spawnCount)
  }
  onDestroy = function(_eid, comp) {
    if (!comp.is_local)
      return
    isNexusPlayerExists.set(false)
    isNexusPlayerCanSpawn.set(false)
    isNexusPlayerCanChangeLoadout.set(false)
    isNexusPlayerSpawned.set(false)
    nexusPlayerSpawnCount.set(0)
  }
},
{
  comps_track = [
    ["nexus_player__canSpawn", ecs.TYPE_BOOL],
    ["nexus_player__canChangeLoadout", ecs.TYPE_BOOL],
    ["nexus_player__spawned", ecs.TYPE_BOOL],
    ["nexus_player__spawnCount", ecs.TYPE_INT],
    ["is_local", ecs.TYPE_BOOL]]
},
{ tags = "gameClient" })


let nexusStartGameState = Watched(null)
let nexusStartGameStateEndAll = Watched(-1.0)

function resetGameStartState(){
  nexusStartGameState.set(null)
  nexusStartGameStateEndAll.set(-1.0)
}
resetGameStartState()
ecs.register_es("nexus_game_start_track_state_es", {
  [["onChange", "onInit"]] = function(_evt, _eid, comp){
    resetGameStartState()
    nexusStartGameState.set(comp.nexus_game_start__state)
    nexusStartGameStateEndAll.set(comp.nexus_game_start__stateEndAt)
  }
  onDestroy = @(...) resetGameStartState()
},
{
  comps_track = [
    ["nexus_game_start__state", ecs.TYPE_INT],
    ["nexus_game_start__stateEndAt", ecs.TYPE_FLOAT],
  ]
},
{
  tags = "gameClient"
})

ecs.register_es("nexus_game_debriefing_es", {
  [[EventNexusGameDebriefing]] = function(_evt, _eid, comp) {
    if (!comp.is_local)
      return
    isNexusEndGameDebriefing.set(true)
  }
},
{
  comps_ro = [
    ["team", ecs.TYPE_INT],
    ["is_local", ecs.TYPE_BOOL],
  ]
},
{
  tags = "gameClient"
})

ecs.register_es("nexus_game_end_es", {
  [[EventNexusGameEnd]] = function(evt, _eid, comp){
    if (!comp.is_local)
      return
    nexusGameWinner.set(evt.winner)
  }
},
{
  comps_ro = [
    ["team", ecs.TYPE_INT],
    ["is_local", ecs.TYPE_BOOL],
  ]
},
{
  tags = "gameClient"
})

return {
  isNexus,
  isNexusWaveMode,
  isNexusRoundMode,
  isNexusGameStarted
  isNexusGameFinished,
  isNexusPlayerExists,
  isNexusPlayerCanSpawn,
  isNexusPlayerCanChangeLoadout,
  isNexusPlayerSpawned,
  isNexusEndGameDebriefing,
  nexusBeacons,
  nexusBeaconEids,
  nexusSpawnPoints,
  nexusModeTeamColors,
  nexusModeEnemiesColors,
  nexusModeTeamColorIndices,
  nexusGameWinner,
  nexusPlayerSpawnCount,
  nexusAllyTeam,
  nexusEnemyTeam,
  allyTeam,
  enemyTeam

  nexusStartGameState
  nexusStartGameStateEndAll
  NexusGameStartState
  nexusSelectedNames
  mutedNexusPlayersList
}
