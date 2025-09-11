from "%sqGlob/dasenums.nut" import NexusBeaconState
from "%dngscripts/sound_system.nut" import sound_play

from "%sqstd/math.nut" import ceil

from "%ui/fonts_style.nut" import h2_txt, body_txt, tiny_txt
from "%ui/components/colors.nut" import RedWarningColor, OrangeHighlightColor, TextHighlight, ModalBgTint, TextNormal
from "%ui/components/commonComponents.nut" import mkText, mkTimeComp
from "%ui/helpers/timers.nut" import mkCountdownTimerPerSec
from "team" import TEAM_UNASSIGNED
import "%ui/hud/state/is_teams_friendly.nut" as is_teams_friendly
import "%ui/components/faComp.nut" as faComp

from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { nexusBeacons, nexusBeaconEids, nexusModeTeamColors, nexusEnemyTeam } = require("%ui/hud/state/nexus_mode_state.nut")
let { nexusPointsToWin, nexusTeamPoints } = require("%ui/hud/state/nexus_points_victory_state.nut")
let { localPlayerTeam } = require("%ui/hud/state/local_player.nut")

let beaconHeight = hdpxi(31)
let pointsBarWidth = hdpx(300)

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
  let size = static hdpx(18)
  return isAlive
    ? faComp("heartbeat.svg", {color, size})
    : static faComp("skull.svg", {color = Color(20,20,20,140), size})
}

function mkShortPlayersStatusBlock(statuses, color) {
  local order = ["alive", "dead"]
  let data = statuses.reduce(@(res, isAlive) isAlive
    ? res.__update({ alive = res.alive + 1 })
    : res.__update({ dead = res.dead + 1 }), { alive = 0, dead = 0 })
  let size = static hdpx(18)
  return {
    rendObj = ROBJ_WORLD_BLUR_PANEL
    flow = FLOW_HORIZONTAL
    gap = static {
      rendObj = ROBJ_SOLID
      size = static [hdpx(2), flex()]
      margin = static [hdpx(2), hdpx(10)]
      color = TextNormal
    }
    padding = static [0, hdpx(4)]
    valign = ALIGN_CENTER
    children = order.map(function(v) {
      local content = [
        v == "alive" ? faComp("heartbeat.svg", { color, size })
          : faComp("skull.svg", {color = Color(20,20,20,140), size})
        mkText(data[v], { color = TextHighlight })
      ]
      return {
        flow = FLOW_HORIZONTAL
        valign = ALIGN_CENTER
        gap = static hdpx(4)
        children = content
      }
    })
  }
}

function mkAlliesBlock() {
  let statuses = Computed(@() playersStatus.get()
    .reduce(@(res, v, k) k == localPlayerTeam.get() ? res.extend(v.values()) : res, [])
    .sort(@(a, b) a <=> b))
  return function() {
    let color = nexusModeTeamColors.get()[1]
    return {
      watch = [statuses, nexusModeTeamColors]
      size = FLEX_H
      flow = FLOW_HORIZONTAL
      gap = static hdpx(4)
      children = statuses.get().len() <= 7
        ? statuses.get().map(@(v) mkPlayerStatusIcon(v, color))
        : mkShortPlayersStatusBlock(statuses.get(), color)
    }
  }
}

let mkEnemiesCounter = @(count) {
  flow = FLOW_HORIZONTAL
  gap = static hdpx(4)
  children = [
    mkText(count, { color = TextHighlight })
    faComp("user", { color = RedWarningColor, size = static hdpx(18) })
  ]
}

function mkEnemiesBlock() {
  let enemyCount = Computed(function() {
    let enemiesList = playersStatus.get()?[nexusEnemyTeam.get()]
    return enemiesList == null ? 0 : enemiesList.len()
  })
  return @() {
    watch = enemyCount
    rendObj = ROBJ_WORLD_BLUR_PANEL
    padding = static [0, 0, 0, hdpx(4)]
    hplace = ALIGN_RIGHT
    flow = FLOW_HORIZONTAL
    gap = static hdpx(4)
    children = mkEnemiesCounter(enemyCount.get())
  }
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
    transform = static {}
    key = dataWatched.get().eid
    opacity = 1.0
    animations = static [
      { prop=AnimProp.scale, from=[1.0, 1.0], to=[1.2, 1.2], duration=0.2, delay=0.0, play=true, easing=InCirc }
      { prop=AnimProp.scale, from=[1.2, 1.2], to=[1.0, 1.0], duration=0.2, delay=0.2, play=true, easing=OutCirc }
      { prop=AnimProp.opacity, from=0.0, to=1.0, duration=0.4, delay=0.0, play=true, easing=InOutCirc }
    ]
    children = [
      {
        size = static [1.4 * beaconHeight, 1.4 * beaconHeight]
        rendObj = ROBJ_IMAGE
        image = beaconPic
        color = ModalBgTint
        opacity = 0.0
        animations = [
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
        size = static [beaconHeight, beaconHeight]
        fgColor = color
        bgColor = static Color(0,0,0,0)
        image = beaconPic
        fValue = curProgress
      }
      mkText(symbol, static {}.__merge(body_txt, {
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
    gap = static hdpx(4)
    valign = ALIGN_CENTER
    hplace = ALIGN_CENTER
    children = beaconsDataWatches.map(@(data) mkBeacon(data))
  }
}

function mkTeamPoints(team, fillColor, isLeftAlign) {
  let ratio = Computed(@() nexusTeamPoints.get()[team] / nexusPointsToWin.get())
  let pointsLeft = Computed(@() nexusPointsToWin.get() - nexusTeamPoints.get()[team])
  return {
    rendObj = ROBJ_SOLID
    color = static Color(60, 60, 60)
    size = static [ pointsBarWidth, hdpx(17) ]
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
          margin = static [0, 0, hdpx(2), 0]
        }
        mkText(ceil(pointsLeft.get()), static {
          fontFx = FFT_BLUR
          fontFxColor = Color(0,0,0, 125)
          color = TextHighlight
          padding = static [0, hdpx(4)]
        }.__update(tiny_txt))
      ]

    }
  }
}

function mkNexusTimer(timeWatched, text, animations = null) {
  let timer = mkCountdownTimerPerSec(timeWatched, text)
  return function() {
    if (timer.get() <= 0)
      return { watch = [timer, timeWatched] }
    return {
      watch = [timer, timeWatched]
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      flow = FLOW_HORIZONTAL
      gap = static hdpx(10)
      padding = static [0, hdpx(4)]
      transform = {}
      animations
      onDetach = @() gui_scene.clearTimer(text)
      children = [
        mkText(text, static { color = TextHighlight }.__update(body_txt))
        mkTimeComp(timer.get(), body_txt, static mul_color(TextHighlight, Color(220,120,120)))
      ]
    }.__update(bgParams)
  }
}

let abandonTimerAnimtions = static [
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

let topHeaderBlock = @() {
  size = FLEX_H
  hplace = ALIGN_CENTER
  halign = ALIGN_CENTER
  flow = FLOW_HORIZONTAL
  gap = static hdpx(20)
  valign = ALIGN_CENTER
  children = [mkAlliesBlock(), mkEnemiesBlock()]
}

return {
  topHeaderBlock
  nexusBeaconsBlock
  mkBeacon
  mkTeamPoints
  pointsBarWidth
  abandonTimerAnimtions
  mkNexusTimer
}
