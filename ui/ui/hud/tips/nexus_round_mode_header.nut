from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { h2_txt, body_txt, tiny_txt } = require("%ui/fonts_style.nut")
let { RedWarningColor, OrangeHighlightColor, TextHighlight, ModalBgTint } = require("%ui/components/colors.nut")
let { isNexusGameStarted, nexusBeacons, nexusBeaconEids, isNexusRoundMode,
  nexusModeTeamColors, nexusStartGameState, nexusStartGameStateEndAll, NexusGameStartState} = require("%ui/hud/state/nexus_mode_state.nut")
let { nexusRoundModeRoundsToWin, nexusRoundModeTeamScores, nexusRoundModeTeamPoints, nexusRoundModePointsToWin,
  nexusRoundModeRoundStartAt, nexusRoundModeRoundDrawAt, nexusRoundModeRoundEnded,
  nexusRoundModeAllyTeam, nexusRoundModeEnemyTeam, nexusRoundModeRoundNumber, nexusRoundModeAbandonedTimer,
  nexusRoundModeDebriefingAt } = require("%ui/hud/state/nexus_round_mode_state.nut")
let { localPlayerTeam } = require("%ui/hud/state/local_player.nut")
let { mkText, mkMonospaceTimeComp} = require("%ui/components/commonComponents.nut")
let { mkCountdownTimerPerSec } = require("%ui/helpers/timers.nut")
let { NexusBeaconState } = require("%sqGlob/dasenums.nut")
let { TEAM_UNASSIGNED } = require("team")
let is_teams_friendly = require("%ui/hud/state/is_teams_friendly.nut")
let { ceil, getRomanNumeral } = require("%sqstd/math.nut")
let faComp = require("%ui/components/faComp.nut")
let { nexusPlayersConnected, nexusPlayersNeedToStart } = require("%ui/hud/state/nexus_players_state.nut")
let { sound_play } = require("%dngscripts/sound_system.nut")

let beaconHeight = hdpxi(31)
let timerSize = [hdpx(100), hdpx(33)]

let playersStatus = Watched({})
let bgParams = {
  rendObj = ROBJ_WORLD_BLUR_PANEL
  fillColor = 0x220A0A0A
  color = 0xFFFFFFFF
}

ecs.register_es("players_status_ui_es",
  {
    [["onInit", "onChange"]] = function(eid, comp) {
      playersStatus.mutate(function(v) {
        if (comp.team not in v)
          v[comp.team] <- {}
        v[comp.team].__update({ [eid] = comp.isAlive })
      })
      if (comp.possessedByPlr == ecs.INVALID_ENTITY_ID || comp.possessedByPlr == null)
        if (eid in (playersStatus.get()?[comp.team] ?? {}))
          playersStatus.mutate(@(v) v[comp.team].$rawdelete(eid))
    }
    onDestroy = @(eid, comp) playersStatus.mutate(@(v) v[comp.team].$rawdelete(eid))
  },
  {
    comps_track = [
      ["isAlive", ecs.TYPE_BOOL],
      ["team", ecs.TYPE_INT],
      ["possessedByPlr", ecs.TYPE_EID, ecs.INVALID_ENTITY_ID]
    ]
  }
)

let mkPlayerStatusIcon = function(isAlive, color) {
  let size = const hdpx(18)
  return isAlive
    ? faComp("heartbeat.svg", {color, size})
    : const faComp("skull.svg", {color = Color(20,20,20,140), size})
}

function mkBar(watch, statuses, getColor=null){
  return function() {
    let color = getColor?() ?? RedWarningColor
    return {
      watch
      size = const [flex(), SIZE_TO_CONTENT]
      flow = FLOW_HORIZONTAL
      gap = const hdpx(4)
      halign = getColor == null ? ALIGN_RIGHT : ALIGN_LEFT
      children = statuses.get().map(@(v) mkPlayerStatusIcon(v, color))
    }
  }
}
function mkAlliesBlock() {
  let statuses = Computed(@() playersStatus.get()
    .reduce(@(res, v, k) k == localPlayerTeam.get() ? res.extend(v.values()) : res, [])
    .sort(@(a, b) a <=> b))
  return mkBar([statuses, nexusModeTeamColors], statuses, @() nexusModeTeamColors.get()[1])
}

function mkEnemiesBlock() {
  let enemyStatuses = Computed(@() playersStatus.get()
    .reduce(@(res, v, k) k != localPlayerTeam.get() ? res.extend(v.values()) : res, [])
    .sort(@(a, b) b <=> a))
  return mkBar(enemyStatuses, enemyStatuses)
}

let beaconPic = Picture($"ui/skin#hexagon.svg:{beaconHeight}:{beaconHeight}:P")
let mkBeacon = @(dataWatched, sf = Watched(0)) function() {
  if (dataWatched.get().len() <= 0)
    return { watch = [ dataWatched, nexusModeTeamColors ] }
  let playerTeam = localPlayerTeam.get()
  let { activationProgress, controllingTeam, state, symbol } = dataWatched.get()
  let isHover = sf.get() & S_HOVER
  let isControlled = controllingTeam != TEAM_UNASSIGNED
  let isFriendly = is_teams_friendly(playerTeam, controllingTeam)
  let color = isHover
                ? OrangeHighlightColor
                : !isControlled
                  ? TextHighlight
                  : isFriendly
                    ? nexusModeTeamColors.get()[1]
                    : RedWarningColor
  let curProgress = state == NexusBeaconState.INACTIVE ? 0.0
    : state == NexusBeaconState.CAPTURED ? 1.0
    : activationProgress.tofloat()
  let trigger = dataWatched.get().eid
  return {
    watch = [localPlayerTeam, dataWatched, sf]
    size = [beaconHeight, beaconHeight]
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    transform = const {}
    key = dataWatched.get().eid
    opacity = 1.0
    animations = const [
      { prop=AnimProp.scale, from=[1.0, 1.0], to=[1.2, 1.2], duration=0.2, delay=0.0, play=true, easing=InCirc }
      { prop=AnimProp.scale, from=[1.2, 1.2], to=[1.0, 1.0], duration=0.2, delay=0.2, play=true, easing=OutCirc }
      { prop=AnimProp.opacity, from=0.0, to=1.0, duration=0.4, delay=0.0, play=true, easing=InOutCirc }
    ]
    children = [
      {
        size = const [1.4 * beaconHeight, 1.4 * beaconHeight]
        rendObj = ROBJ_IMAGE
        image = beaconPic
        color = ModalBgTint
        opacity = 0.0
        animations = const [
          { prop=AnimProp.scale, from=[0.0, 0.0], to=[1.0, 1.0], duration=1.6, easing=InQuad, trigger }
          { prop=AnimProp.opacity, from=1.0, to=0.0, duration=1.6, easing=InBounce, trigger }
        ]
      }
      {
        size = [beaconHeight, beaconHeight]
        rendObj = ROBJ_IMAGE
        image = beaconPic
        color = ModalBgTint
      }
      {
        rendObj = ROBJ_PROGRESS_CIRCULAR
        size = const [beaconHeight, beaconHeight]
        fgColor = color
        bgColor = const Color(0,0,0,0)
        image = beaconPic
        fValue = curProgress
      }
      mkText(symbol, const {}.__merge(body_txt, {
        fontFx = FFT_BLUR
        fontFxColor = Color(0,0,0, 125)
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        size = [beaconHeight, beaconHeight]
      }))
    ]
  }
}

function nexusBeaconsBlock() {
  let sortedBeacons = nexusBeaconEids.get().sort(@(a, b) a <=> b)
  let beaconsDataWatches = sortedBeacons.map(@(beaconId) Computed(@() nexusBeacons.get()?[beaconId] ?? {}))
  return {
    watch = nexusBeaconEids
    flow = FLOW_HORIZONTAL
    gap = const hdpx(4)
    valign = ALIGN_CENTER
    hplace = ALIGN_CENTER
    children = beaconsDataWatches.map(@(data) mkBeacon(data))
  }
}
let pointsBarWidth = hdpx(300)
function mkTeamPoints(team, fillColor, isLeftAlign) {
  let ratio = Computed(@() nexusRoundModeTeamPoints.get()[team] / nexusRoundModePointsToWin.get())
  let pointsLeft = Computed(@() nexusRoundModePointsToWin.get() - nexusRoundModeTeamPoints.get()[team])
  return {
    rendObj = ROBJ_SOLID
    color = const Color(60, 60, 60)
    size = const [ pointsBarWidth, hdpx(17) ]
    children = @() {
      watch = [ratio, pointsLeft]
      size = flex()
      valign = ALIGN_CENTER
      halign = isLeftAlign ? ALIGN_LEFT : ALIGN_RIGHT
      children = [
        {
          rendObj = ROBJ_SOLID
          size = [pw(100 - 100 * ratio.get()), flex() ]
          key = $"progress_{team}_{ratio.get()}"
          transform = {}
          animations = 1 - ratio.get() > 0.15 ? null
            : [{ prop = AnimProp.color, from = fillColor, to = 0x00000000, duration = 0.5,
              play = true, easing = CosineFull, onStart = @() sound_play("ui_sounds/access_denied") }]
          color = fillColor
          margin = [0, 0, hdpx(2), 0]
        }
        mkText(ceil(pointsLeft.get()), const {
          fontFx = FFT_BLUR
          fontFxColor = Color(0,0,0, 125)
          color = TextHighlight
          padding = [0, hdpx(4)]
        }.__update(tiny_txt))
      ]

    }
  }
}

function mkNexusTimer(timeWatched, text, animations = null) {
  let timer = mkCountdownTimerPerSec(timeWatched)
  return function() {
    if (timer.get() <= 0)
      return { watch = [timer, timeWatched] }
    return {
      watch = [timer, timeWatched]
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      flow = FLOW_HORIZONTAL
      gap = const hdpx(10)
      padding = const [0, hdpx(4)]
      transform = {}
      animations
      children = [
        mkText(text, const { color = TextHighlight }.__update(body_txt))
        mkMonospaceTimeComp(timer.get(), body_txt, const mul_color(TextHighlight, Color(220,120,120)))
      ]
    }.__update(bgParams)
  }
}

let abandonTimerAnimtions = const [
  {
    prop = AnimProp.fillColor, from = 0x220A0A0A, to = Color(20, 100, 20, 220), duration = 2,
    play = true, easing = CosineFull
  }
  {
    prop = AnimProp.fillColor, from = 0x220A0A0A, to = Color(20, 100, 20, 220), duration = 2, delay = 2,
    play = true, easing = CosineFull
  }
  {
    prop = AnimProp.fillColor, from = 0x220A0A0A, to = Color(20, 100, 20, 220), duration = 2, delay = 4,
    play = true, easing = CosineFull
  }
]

function mkTimerBlock() {
  return function() {
    let state = nexusStartGameState.get()
    let gameStateEnd = nexusStartGameStateEndAll.get()
    let res = nexusRoundModeRoundEnded.get() ? null
      : nexusRoundModeDebriefingAt.get() > 0 ? mkNexusTimer(nexusRoundModeDebriefingAt, loc("nexus_game_start/debriefingTimer"))
      : nexusRoundModeAbandonedTimer.get() > 0 ? mkNexusTimer(nexusRoundModeAbandonedTimer,
        loc("nexus_game_start/abandonedTimer"), abandonTimerAnimtions)
      : nexusRoundModeRoundStartAt.get() > 0 ? mkNexusTimer(nexusRoundModeRoundStartAt, loc("nexus_game_start/startTimer"))
      : nexusRoundModeRoundDrawAt.get() > 0 ? mkNexusTimer(nexusRoundModeRoundDrawAt,
        loc("nexus/roundNumber",{ number = getRomanNumeral(nexusRoundModeRoundNumber.get())}))
      : ( state == NexusGameStartState.WarmUp || state == NexusGameStartState.WaitingForPlayers ) && gameStateEnd > 0 ? mkNexusTimer(nexusStartGameStateEndAll,
          state == NexusGameStartState.WaitingForPlayers ? loc("nexus_game_start/waitForPlayersTimer", {
          connected = nexusPlayersConnected.get()
          needed = nexusPlayersNeedToStart.get()
        }) : loc("nexus_game_start/waitForPlayers"))
      : null

    return {
      watch = [nexusRoundModeRoundStartAt, nexusRoundModeRoundDrawAt, nexusRoundModeRoundEnded,
        localPlayerTeam, nexusStartGameStateEndAll, nexusStartGameState, nexusRoundModeDebriefingAt,
        nexusRoundModeRoundNumber, nexusPlayersConnected, nexusPlayersNeedToStart, nexusRoundModeAbandonedTimer]
      size = [SIZE_TO_CONTENT, timerSize[1]]
      children = res
    }
  }
}

let mkTeamScore = @(score, color) {
  padding = const [0, hdpx(5)]
  children = mkText(score, { color }.__update(h2_txt))
}.__update(bgParams)


let bottomHeaderBlock = @() {
  size = const [flex(), SIZE_TO_CONTENT]
  hplace = ALIGN_CENTER
  halign = ALIGN_CENTER
  flow = FLOW_HORIZONTAL
  gap = const hdpx(20)
  valign = ALIGN_CENTER
  children = mkTimerBlock()
}

let topHeaderBlock = @() {
  size = const [flex(), SIZE_TO_CONTENT]
  hplace = ALIGN_CENTER
  halign = ALIGN_CENTER
  flow = FLOW_HORIZONTAL
  gap = const hdpx(20)
  valign = ALIGN_CENTER
  children = [mkAlliesBlock(), mkEnemiesBlock()]
}

function altNexusScoreTip() {
  if (nexusRoundModeAllyTeam.get() == -1)
    return const { watch = nexusRoundModeAllyTeam}

  return {
    watch = nexusRoundModeAllyTeam
    children = [
      topHeaderBlock
      @() {
        watch = const [nexusRoundModeAllyTeam, nexusRoundModeEnemyTeam, isNexusGameStarted]
        flow = FLOW_VERTICAL
        gap = const hdpx(4)
        children = [
          {
            flow = FLOW_HORIZONTAL
            gap = const hdpx(6)
            valign = ALIGN_BOTTOM
            margin = const [hdpx(6), 0, 0,0]
            halign = ALIGN_CENTER
            minWidth = pointsBarWidth*2
            children = [
              !isNexusGameStarted.get() ? null
                : mkTeamPoints(nexusRoundModeEnemyTeam.get(), nexusModeTeamColors.get()[1], true)
              @() {
                watch = const [nexusRoundModeTeamScores, nexusRoundModeRoundsToWin]
                hplace = ALIGN_CENTER
                flow = FLOW_HORIZONTAL
                gap = const hdpx(10)
                valign = ALIGN_CENTER
                children = [
                  nexusRoundModeRoundsToWin.get() > 1 ? mkTeamScore(nexusRoundModeTeamScores.get()[nexusRoundModeAllyTeam.get()], nexusModeTeamColors.get()[1]) : null
                  nexusBeaconsBlock
                  nexusRoundModeRoundsToWin.get() > 1 ? mkTeamScore(nexusRoundModeTeamScores.get()[nexusRoundModeEnemyTeam.get()], RedWarningColor) : null
                ]
              }
              !isNexusGameStarted.get()? null
                : mkTeamPoints(nexusRoundModeAllyTeam.get(), RedWarningColor, false)
            ]
          }
          bottomHeaderBlock
        ]
      }
    ]
  }
}

function nexusHeaderBlock() {
  let watch = isNexusRoundMode
  if (!isNexusRoundMode.get())
    return const { watch }
  return {
    watch
    halign = ALIGN_CENTER
    children = altNexusScoreTip
  }
}

return {
  nexusHeaderBlock
  mkBeacon
}
