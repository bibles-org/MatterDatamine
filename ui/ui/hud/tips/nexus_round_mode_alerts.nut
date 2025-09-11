from "%dngscripts/sound_system.nut" import sound_play
from "%sqGlob/dasenums.nut" import NexusGameStartState
from "%sqstd/string.nut" import utf8ToUpper
from "%sqstd/math.nut" import getRomanNumeral
from "%ui/fonts_style.nut" import giant_txt, body_txt
from "%ui/components/colors.nut" import RedWarningColor, TextHighlight, ControlBg, VictoryColor
from "%ui/components/commonComponents.nut" import mkText
from "dasevents" import EventNexusRoundModeRoundFinished, EventNexusRoundModeRoundStarted, EventNexusGameEnd
from "%ui/helpers/timers.nut" import mkCountdownTimerPerSec
from "%ui/ui_library.nut" import *
from "app" import get_current_scene
import "%dngscripts/ecs.nut" as ecs

let { nexusRoundModeRoundNumber, nexusRoundModeRoundEnded, nexusRoundModeRoundEndWinner, nexusRoundModeRoundStartAt, nexusRoundModeRoundEndReason } = require("%ui/hud/state/nexus_round_mode_state.nut")
let { isNexus, nexusStartGameStateEndAll, nexusStartGameState, isNexusEndGameDebriefing, nexusGameWinner, nexusAllyTeam, nexusEnemyTeam } = require("%ui/hud/state/nexus_mode_state.nut")
let { nexusPlayersConnected, nexusPlayersExpected } = require("%ui/hud/state/nexus_players_state.nut")
let { nexusRoundEndReasonMap } = require("%ui/hud/tips/nexus_round_mode_round_result.nut")
let { localPlayerTeam } = require("%ui/hud/state/local_player.nut")

const ALERT_ANIM_DURATION = 5
const SHORT_ANIM_DURATION = 0.4
const TEXT_ANIM_TRIGGER = "startTextAnim"

enum NexusUiStages {
  RoundStart
  RoundEnd
  GameEnd
}

let bgSize = static [hdpxi(400), hdpxi(150)]
let topFromAnim = static [0, hdpx(100)]
let botFromAnim = static [0, -hdpx(100)]

let defTextStyle = { color = TextHighlight }.__update(body_txt)

let mkBlockAnimations = memoize(@(from) freeze([
  { prop = AnimProp.opacity, from = 1, to = 1, duration = ALERT_ANIM_DURATION,
    trigger = TEXT_ANIM_TRIGGER }
  { prop = AnimProp.translate, from, to = [0, 0], duration = SHORT_ANIM_DURATION,
    trigger = TEXT_ANIM_TRIGGER, easing = OutCubic }
  { prop = AnimProp.translate, from = [0, 0], to = from, duration = SHORT_ANIM_DURATION,
    delay = ALERT_ANIM_DURATION - SHORT_ANIM_DURATION, play = true, easing = OutCubic }
]))

let infoToShow = Watched(null)
function hideInfoToShow(state, id){
  gui_scene.resetTimeout(ALERT_ANIM_DURATION, function() {
    if (infoToShow.get() == state)
      infoToShow.set(null)
  }, id)
}
ecs.register_es("nexus_ui_stages_es",
  {
    [[EventNexusRoundModeRoundFinished]] = function(_evt, _eid, comp){
      if (!comp.is_local)
        return
      infoToShow.set(NexusUiStages.RoundEnd)
    },
    [[EventNexusRoundModeRoundStarted]] = function(_evt, _eid, comp) {
      if (!comp.is_local)
        return
      infoToShow.set(NexusUiStages.RoundStart)
    },
    [[EventNexusGameEnd]] = function(_evt, _eid, comp){
      if (!comp.is_local)
        return
      infoToShow.set(NexusUiStages.GameEnd)
    }
  },
  {
    comps_ro = [
      ["team", ecs.TYPE_INT],
      ["is_local", ecs.TYPE_BOOL],
    ],
  },
  {
    tags = "gameClient"
  }
)

ecs.register_es("nexus_ui_stages_reset_data_on_game_exit", {
  onDestroy = function(...) {
    infoToShow.set(null)
  }
},
{
  comps_rq = [ "nexus_round_mode" ]
},
{
  tags = "gameClient"
})

let alertSeparator = freeze({
  rendObj = ROBJ_IMAGE
  size = [bgSize[0] * 2, hdpx(4)]
  color = Color(250, 220, 170)
  vplace = ALIGN_CENTER
  transform = {}
  opacity = 0
  animations = [
    { prop = AnimProp.opacity, from = 1, to = 1, duration = ALERT_ANIM_DURATION, play = true }
    {
      prop = AnimProp.scale, from = [0.1, 1], to = [1, 1], duration = SHORT_ANIM_DURATION, play = true, easing = OutCubic,
      onFinish = @() anim_start(TEXT_ANIM_TRIGGER), onStart = @() sound_play("ui_sounds/round_mode_alert", 0.4)
    }
    {
      prop = AnimProp.scale, from = [1, 1], to = [0.1, 1], duration = SHORT_ANIM_DURATION, play = true, easing = OutCubic,
      delay = ALERT_ANIM_DURATION - SHORT_ANIM_DURATION
    }
  ]
  image = Picture($"ui/skin#round_strip.svg:{hdpxi(200)}:{hdpxi(4)}:K")
})

let wrapperAnimations = static [
  { prop = AnimProp.opacity, from = 0, to = 1, duration = 0.2, play = true, easing = OutCubic }
  { prop = AnimProp.opacity, from = 1, to = 1, duration = ALERT_ANIM_DURATION, play = true }
  { prop = AnimProp.opacity, from = 1, to = 0, duration = SHORT_ANIM_DURATION,
    delay = ALERT_ANIM_DURATION - SHORT_ANIM_DURATION, play = true, easing = OutCubic }
]

let mkAlertWrapper = @(topBlock, bottomBlock) {
  rendObj = ROBJ_IMAGE
  size = static [bgSize[0] * 2, bgSize[1] * 2]
  color = static Color(0, 15, 30)
  padding = static [0, hdpx(300)]
  image = Picture(static $"!ui/skin#round_grad.svg:{bgSize[0]}:{bgSize[1]}:K")
  halign = ALIGN_CENTER
  hplace = ALIGN_CENTER
  vplace = ALIGN_CENTER
  opacity = 0
  transform = static {}
  animations = wrapperAnimations
  children = [
    alertSeparator
    {
      flow = FLOW_VERTICAL
      gap = hdpx(20)
      halign = ALIGN_CENTER
      pos = static [0, bgSize[1] / 2 - hdpx(10)]
      children = [
        topBlock
        bottomBlock
      ]
    }
  ]
}

let mkAnimText = @(txt, animations, override = static {}) {
  clipChildren = true
  children = mkText(txt, ({
    opacity = 0
    transform = static {}
    animations
  }.__update(defTextStyle)).__merge(override))
}



function mkNewRoundAlert() {
  let needToShow = Computed(@() infoToShow.get() == NexusUiStages.RoundStart)
  return function() {
    if (!needToShow.get())
      return { watch = needToShow }

    return {
      watch = [needToShow, nexusRoundModeRoundNumber]
      children = mkAlertWrapper(
        mkAnimText(loc("missionInfo/pvp/short"), mkBlockAnimations(botFromAnim), giant_txt),
        @() {
          watch = nexusRoundModeRoundNumber
          onAttach = @() hideInfoToShow(NexusUiStages.RoundStart, $"newRound_{nexusRoundModeRoundNumber.get()}")
          children = mkAnimText(
            utf8ToUpper(loc("nexus/roundNumber" { number = getRomanNumeral(nexusRoundModeRoundNumber.get())})),
            mkBlockAnimations(topFromAnim)
          )
        },
      )
    }
  }
}



function winnerBlock() {
  if (!nexusRoundModeRoundEnded.get())
    return { watch = [nexusRoundModeRoundEnded, nexusRoundModeRoundEndWinner] }

  let text = nexusRoundModeRoundEndWinner.get() == nexusAllyTeam.get() ? loc("nexus/victory")
    : nexusRoundModeRoundEndWinner.get() == nexusEnemyTeam.get() ? loc("nexus/defeat")
    : loc("nexus/draw")
  let color = nexusRoundModeRoundEndWinner.get() == nexusAllyTeam.get() ? VictoryColor
    : nexusRoundModeRoundEndWinner.get() == nexusEnemyTeam.get() ? RedWarningColor
    : TextHighlight
  return {
    watch = [nexusRoundModeRoundEnded, nexusRoundModeRoundEndWinner,nexusAllyTeam, nexusEnemyTeam]
    children = mkAnimText(utf8ToUpper(text), mkBlockAnimations(topFromAnim), { color }.__update(giant_txt))
  }
}

function reasonBlock() {
  if (!nexusRoundModeRoundEnded.get())
    return { watch = [nexusRoundModeRoundEnded, nexusRoundModeRoundEndReason]  }

  let locKey = nexusRoundEndReasonMap?[nexusRoundModeRoundEndReason.get()]
  if (locKey == null)
    return { watch = [nexusRoundModeRoundEnded, nexusRoundModeRoundEndReason] }

  return {
    watch = [nexusRoundModeRoundEnded, nexusRoundModeRoundEndReason]
    children = mkAnimText(loc(locKey), mkBlockAnimations(botFromAnim))
  }
}

function mkNexusRoundResultBlock() {
  let needToShow = Computed(@() infoToShow.get() == NexusUiStages.RoundEnd)
  return function() {
    if (!needToShow.get())
      return { watch = needToShow }

    return {
      watch = [nexusRoundModeRoundNumber, needToShow]
      onAttach = @() hideInfoToShow(NexusUiStages.RoundEnd, $"roundEnd_{nexusRoundModeRoundNumber.get()}")
      children = mkAlertWrapper(winnerBlock, reasonBlock)
    }
  }
}



let winDefeatBgSize = static [hdpxi(868), hdpxi(70)]

function mkWinDefeatBg(isWinner) {
  let icon = isWinner ? "nexus_victory" : "nexus_defeat"
  return {
    rendObj = ROBJ_IMAGE
    size = winDefeatBgSize
    vplace = ALIGN_CENTER
    image = Picture($"!ui/nexus/{icon}.svg:{winDefeatBgSize[0]}:{winDefeatBgSize[1]}:K")
  }
}

function mkGameEndAlert() {
  let needToShow = Computed(@() !isNexusEndGameDebriefing.get() && infoToShow.get() == NexusUiStages.GameEnd)
  return function() {
    if (!needToShow.get())
      return { watch = needToShow }
    let isWinner = localPlayerTeam.get() == nexusGameWinner.get()
    return {
      watch = [nexusGameWinner, needToShow, localPlayerTeam]
      rendObj = ROBJ_WORLD_BLUR_PANEL
      size = flex()
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      color = ControlBg
      children = {
        flow = FLOW_VERTICAL
        halign = ALIGN_CENTER
        transform = static {}
        animations = static [
          static { prop = AnimProp.opacity, from = 0, to = 1, duration = 0.2, play = true, easing = OutCubic,
            onStart = @() sound_play("ui_sounds/round_mode_alert", 0.4) }
          static { prop = AnimProp.opacity, from = 1, to = 0.5, duration = 0.4, delay = 0.2, play = true, easing = InOutCubic }
          static { prop = AnimProp.opacity, from = 0.5, to = 0.8, duration = 0.2, delay = 0.6, play = true, easing = OutCubic }
          static { prop = AnimProp.opacity, from = 0.8, to = 0, duration = 0.4, play = true, delay = 1, easing = InOutCubic }
          static { prop = AnimProp.opacity, from = 0, to = 1, duration = 1, play = true, delay = 1.4, easing = InOutCubic }
        ]
        children = [
          mkText(utf8ToUpper(isWinner ? loc("nexus/victory") : loc("nexus/defeat")), {
            fontSize = hdpxi(140)
            color = isWinner ? VictoryColor : RedWarningColor
          })
          mkWinDefeatBg(isWinner)
        ]
      }
    }
  }
}

let back = freeze({
  rendObj = ROBJ_IMAGE
  size = static [bgSize[0] * 2, bgSize[1]*2]
  color = static Color(0, 15, 30)
  image = Picture(static $"!ui/skin#round_grad.svg:{hdpxi(200)}:{hdpxi(150)}:K")
})

function gameInfo() {
  let state = nexusStartGameState.get()
  let waitStage = state in static {[NexusGameStartState.WaitingForPlayers]=1, [NexusGameStartState.WarmUp]=1}
  if ( !waitStage && nexusRoundModeRoundStartAt.get() <= 0)
     return static { watch = [nexusStartGameState, nexusRoundModeRoundStartAt], size = [bgSize[0] * 2, bgSize[1]]}
  return {
    watch = static [nexusStartGameState, nexusStartGameStateEndAll, nexusRoundModeRoundStartAt]
    halign = ALIGN_CENTER
    key = state
    children = [
      static {size = flex() children = back valign = ALIGN_CENTER halign = ALIGN_CENTER pos = [0, sh(3)]}
      {
        flow = FLOW_VERTICAL
        gap = hdpx(10)
        halign = ALIGN_CENTER
        children = [
          static {size = sh(3)},
          mkText(
            waitStage ? static utf8ToUpper(loc("nexus_game_start/waitForPlayers")) : static utf8ToUpper(loc("nexus/loadoutStage")),
            static {transform = {}, animations = [{ prop = AnimProp.translate, from = [0, hdpx(100)], to = [0, 0], duration = SHORT_ANIM_DURATION, play = true, easing = OutCubic}]}.__update(giant_txt)
          ),
          static alertSeparator.__merge({animations=[{ prop = AnimProp.opacity, from = 0, to = 1, duration = 0.2, play = true, easing = OutCubic }], opacity=1}),
          @() {
            watch = [nexusPlayersConnected, nexusPlayersExpected]
            clipChildren = true
            children = {
              flow = FLOW_HORIZONTAL
              valign = ALIGN_CENTER
              gap = static hdpx(2)
              transform = static {}
              animations = static [{ prop = AnimProp.translate, from = [0, -hdpx(100)], to = [0, 0], duration = SHORT_ANIM_DURATION, play = true, easing = OutCubic}]
              children = !waitStage
                ? static mkText(loc("nexus_game_start/chooseLoadout"), defTextStyle)
                : state == NexusGameStartState.WaitingForPlayers
                  ? null
                  : mkText(loc("nexus_game_start/waitForPlayersTimer", {
                      connected = nexusPlayersConnected.get()
                      needed = nexusPlayersExpected.get()
                    }), body_txt)
            }
          }
        ]
      }
    ]
  }
}

function mkNextRoundTimer() {
  let timer = mkCountdownTimerPerSec(nexusRoundModeRoundStartAt, "nexusNewRound")
  return @() timer.get() <= 0 || timer.get() > 10 ? { watch = timer } : {
    watch = timer
    vplace = ALIGN_CENTER
    hplace = ALIGN_CENTER
    onDetach = @() gui_scene.clearTimer("nexusNewRound")
    children = mkText(timer.get(), {
      key = timer.get()
      onAttach = @() sound_play("ui_sounds/access_denied")
      fontSize = hdpxi(150)
    })
  }
}

function alertsUi() {
  let watch = isNexus
  if (!isNexus.get())
    return static { watch }
  return {
    watch
    size = flex()
    eventPassThrough = true
    halign = ALIGN_CENTER
    children = [
      {
        flow = FLOW_VERTICAL
        halign = ALIGN_CENTER
        children = [
          static {size=sh(5)}
          gameInfo
          {
            halign = ALIGN_CENTER
            valign = ALIGN_CENTER
            children = [
              mkNewRoundAlert()
              mkNexusRoundResultBlock()
            ]
          }
          static {size=flex(3)}
        ]
      }
      mkNextRoundTimer()
      mkGameEndAlert()
    ]
  }
}

return {
  alertsUi
}
