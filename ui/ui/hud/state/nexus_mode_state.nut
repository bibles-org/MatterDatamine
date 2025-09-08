from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { TEAM_UNASSIGNED } = require("team")
let { indexToColor } = require("%ui/mainMenu/ribbons_colors_state.nut")
let { IPoint2 } = require("dagor.math")
let { localPlayerTeam } = require("%ui/hud/state/local_player.nut")
let { NexusGameStartState } = require("%sqGlob/dasenums.nut")
let { nestWatched } = require("%dngscripts/globalState.nut")
let nexusSelectedNames = nestWatched("nexusSelectedNames", {})

let isNexus = Watched(false)
let isNexusWaveMode = Watched(false)
let isNexusRoundMode = Watched(false)

let nexusBeacons = Watched({})
let nexusBeaconEids = Watched([])
let nexusSpawnPoints = Watched({})

let isNexusGameStarted = Watched(false)
let isNexusGameFinished = Watched(false)
let isNexusPlayerExists = Watched(false)
let isNexusPlayerSpawned = Watched(false)
let nexusModeTeamColors = Watched(null)
let nexusModeTeamColorIndices = Watched(null)
let nexusModeMaxAdditionalWaves = Watched(0)
let nexusModeSpawnedAdditionalWaves = Watched(0)
let nexusModeAdditionalWavesLeft = Computed(@() nexusModeMaxAdditionalWaves.get() - nexusModeSpawnedAdditionalWaves.get())
let nexusModeNextAdditionalWaveAt = Watched(-1.0)


ecs.register_es("nexus_battle_track_team_colors_es", {
  [["onChange", "onInit"]] = function(_evt, _eid, comp) {
    if (!comp.is_local) {
      return
    }
    nexusModeTeamColors.set(comp.player_ribbons__curColors != IPoint2(-1, -1)
      ? [indexToColor(comp.player_ribbons__curColors.x), indexToColor(comp.player_ribbons__curColors.y)]
      : null)
    nexusModeTeamColorIndices.set(comp.player_ribbons__curColors != IPoint2(-1, -1) ? [comp.player_ribbons__curColors.x, comp.player_ribbons__curColors.y] : null)
  }
  onDestroy = function(...) {
    nexusModeTeamColors.set(null)
    nexusModeTeamColorIndices.set(null)
  }
}, {
  comps_track = [ ["player_ribbons__curColors", ecs.TYPE_IPOINT2] ],
  comps_ro = [ ["is_local", ecs.TYPE_BOOL] ],
  comps_rq = [ "nexus_player" ]
}, {tags = "gameClient"})

let updateNexusBattleAdditionalWavesState = function(comp) {
  nexusModeMaxAdditionalWaves.set(comp?.nexus_wave_mode_additional_waves_spawn_controller__numWaves ?? 0)
  nexusModeSpawnedAdditionalWaves.set(comp?.nexus_wave_mode_additional_waves_spawn_controller__wavesSpawned ?? 0)
  nexusModeNextAdditionalWaveAt.set(comp?.nexus_wave_mode_additional_waves_spawn_controller__spawnAt ?? -1.0)
}

let nexus_battle_additional_waves_comps = {
  comps_ro = [
    ["team", ecs.TYPE_INT],
    ["nexus_wave_mode_additional_waves_spawn_controller__numWaves", ecs.TYPE_INT]
  ],
  comps_track = [
    ["nexus_wave_mode_additional_waves_spawn_controller__wavesSpawned", ecs.TYPE_INT],
    ["nexus_wave_mode_additional_waves_spawn_controller__spawnAt", ecs.TYPE_FLOAT]
  ]
}

let nexus_battle_additional_waves_query = ecs.SqQuery("nexus_battle_additional_waves_query", nexus_battle_additional_waves_comps)

ecs.register_es("nexus_battle_track_additional_waves", {
  [["onChange", "onInit"]] = function(_evt, _eid, comp) {
    if (comp.team != localPlayerTeam.get()) {
      return
    }

    updateNexusBattleAdditionalWavesState(comp)
  }
  onDestroy = function(_evt, _eid, comp) {
    if (comp.team != localPlayerTeam.get()) {
      return
    }

    updateNexusBattleAdditionalWavesState({})
  }
}, nexus_battle_additional_waves_comps, {tags = "gameClient"})

localPlayerTeam.subscribe(function(team) {
  if (team == TEAM_UNASSIGNED) {
    nexusSelectedNames.set({})
    return
  }

  nexus_battle_additional_waves_query.perform(function(_eid, comp) {
    if (comp.team != team) {
      return
    }
    updateNexusBattleAdditionalWavesState(comp)
  })
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
  onDestroy = @(...) isNexus.set(false)
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


let { get_session_id } = require("app")
let voiceState = require("%ui/voiceChat/voiceState.nut")
let voiceRoomName = Watched("")
isNexus.subscribe(function(v){
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
localPlayerTeam.subscribe(function(v){
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
    isNexusPlayerSpawned.set(comp.nexus_player__spawned)
    isNexusPlayerExists.set(true)
  }
  onDestroy = function(_eid, comp) {
    if (!comp.is_local)
      return
    isNexusPlayerSpawned.set(false)
    isNexusPlayerExists.set(false)
  }
},
{ comps_track = [["nexus_player__spawned", ecs.TYPE_BOOL], ["is_local", ecs.TYPE_BOOL]]
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


return {
  isNexus,
  isNexusWaveMode,
  isNexusRoundMode,
  isNexusGameStarted
  isNexusGameFinished,
  isNexusPlayerExists,
  isNexusPlayerSpawned,
  nexusBeacons,
  nexusBeaconEids,
  nexusSpawnPoints,
  nexusModeTeamColors,
  nexusModeTeamColorIndices,
  nexusModeMaxAdditionalWaves,
  nexusModeSpawnedAdditionalWaves,
  nexusModeAdditionalWavesLeft,
  nexusModeNextAdditionalWaveAt,

  nexusStartGameState
  nexusStartGameStateEndAll
  NexusGameStartState
  nexusSelectedNames
}
