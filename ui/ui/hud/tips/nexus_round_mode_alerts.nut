from "%ui/ui_library.nut" import *
from "app" import get_current_scene
import "%dngscripts/ecs.nut" as ecs

let { giant_txt, body_txt } = require("%ui/fonts_style.nut")
let { RedWarningColor, TextHighlight, ControlBg, VictoryColor } = require("%ui/components/colors.nut")
let { nexusRoundModeRoundNumber, nexusRoundModeRoundEnded, nexusRoundModeRoundEndWinner, nexusRoundModeRoundStartAt,
  nexusRoundModeRoundEndReason, nexusRoundModeAllyTeam, nexusRoundModeEnemyTeam, nexusRoundModeGameWinner,
  isNesusEndGameDebriefing } = require("%ui/hud/state/nexus_round_mode_state.nut")
let { isNexus, nexusStartGameStateEndAll, nexusStartGameState
} = require("%ui/hud/state/nexus_mode_state.nut")
let { mkText } = require("%ui/components/commonComponents.nut")
let { utf8ToUpper } = require("%sqstd/string.nut")
let { sound_play } = require("%dngscripts/sound_system.nut")
let { getRomanNumeral } = require("%sqstd/math.nut")
let { nexusPlayersConnected, nexusPlayersExpected } = require("%ui/hud/state/nexus_players_state.nut")
let { EventNexusRoundModeRoundFinished, EventNexusRoundModeRoundStarted, EventNexusGameEnd } = require("dasevents")
let { NexusGameStartState } = require("%sqGlob/dasenums.nut")
let { nexusRoundEndReasonMap } = require("%ui/hud/tips/nexus_round_mode_round_result.nut")
let { mkCountdownTimerPerSec } = require("%ui/helpers/timers.nut")
let { localPlayerTeam } = require("%ui/hud/state/local_player.nut")

const ALERT_ANIM_DURATION = 5
const SHORT_ANIM_DURATION = 0.4
const TEXT_ANIM_TRIGGER = "startTextAnim"

enum NexusUiStages {
  RoundStart
  RoundEnd
  GameEnd
}

let bgSize = [hdpxi(400), hdpxi(150)]
let topFromAnim = [0, hdpx(100)]
let botFromAnim = [0, -hdpx(100)]

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
function hideInfoToShow(state){
  gui_scene.resetTimeout(ALERT_ANIM_DURATION, function() {
    if (infoToShow.get() == state)
      infoToShow.set(null)
  })
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

let wrapperAnimations = const [
  { prop = AnimProp.opacity, from = 0, to = 1, duration = 0.2, play = true, easing = OutCubic }
  { prop = AnimProp.opacity, from = 1, to = 1, duration = ALERT_ANIM_DURATION, play = true }
  { prop = AnimProp.opacity, from = 1, to = 0, duration = SHORT_ANIM_DURATION,
    delay = ALERT_ANIM_DURATION - SHORT_ANIM_DURATION, play = true, easing = OutCubic }
]

let mkAlertWrapper = @(topBlock, bottomBlock) {
  rendObj = ROBJ_IMAGE
  size = const [bgSize[0] * 2, bgSize[1] * 2]
  color = const Color(0, 15, 30)
  padding = const [0, hdpx(300)]
  image = Picture(const $"!ui/skin#round_grad.svg:{bgSize[0]}:{bgSize[1]}:K")
  halign = ALIGN_CENTER
  hplace = ALIGN_CENTER
  vplace = ALIGN_CENTER
  opacity = 0
  transform = const {}
  animations = wrapperAnimations
  children = [
    alertSeparator
    {
      flow = FLOW_VERTICAL
      gap = hdpx(20)
      halign = ALIGN_CENTER
      pos = const [0, bgSize[1] / 2 - hdpx(10)]
      children = [
        topBlock
        bottomBlock
      ]
    }
  ]
}

let mkAnimText = @(txt, animations, override = const {}) {
  clipChildren = true
  children = mkText(txt, (const {
    opacity = 0
    transform = {}
    animations
  }.__update(defTextStyle)).__merge(override))
}



function mkNewRoundAlert() {
  let needToShow = Computed(@() infoToShow.get() == NexusUiStages.RoundStart)
  return function() {
    if (!needToShow.get())
      return const { watch = needToShow }
    hideInfoToShow(NexusUiStages.RoundStart)

    return {
      watch = [nexusRoundModeRoundNumber, needToShow]
      children = mkAlertWrapper(
        mkAnimText(loc("raidInfo/pvp/short"), mkBlockAnimations(botFromAnim), giant_txt),
        @() {
          watch = nexusRoundModeRoundNumber
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

  let text = nexusRoundModeRoundEndWinner.get() == nexusRoundModeAllyTeam.get() ? loc("nexus/victory")
    : nexusRoundModeRoundEndWinner.get() == nexusRoundModeEnemyTeam.get() ? loc("nexus/defeat")
    : loc("nexus/draw")
  let color = nexusRoundModeRoundEndWinner.get() == nexusRoundModeAllyTeam.get() ? VictoryColor
    : nexusRoundModeRoundEndWinner.get() == nexusRoundModeEnemyTeam.get() ? RedWarningColor
    : TextHighlight
  return {
    watch = [nexusRoundModeRoundEnded, nexusRoundModeRoundEndWinner,nexusRoundModeAllyTeam, nexusRoundModeEnemyTeam]
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
    let watch = needToShow
    if (!needToShow.get())
      return const{ watch }
    hideInfoToShow(NexusUiStages.RoundEnd)

    return {
      watch
      children = mkAlertWrapper(winnerBlock, reasonBlock)
    }
  }
}



let winDefeatBgSize = const [hdpxi(868), hdpxi(70)]

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
  let needToShow = Computed(@() !isNesusEndGameDebriefing.get() && infoToShow.get() == NexusUiStages.GameEnd)
  return function() {
    if (!needToShow.get())
      return const { watch = needToShow }
    let isWinner = localPlayerTeam.get() == nexusRoundModeGameWinner.get()
    return {
      watch = [nexusRoundModeGameWinner, needToShow, localPlayerTeam]
      rendObj = ROBJ_WORLD_BLUR_PANEL
      size = flex()
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      color = ControlBg
      children = {
        flow = FLOW_VERTICAL
        halign = ALIGN_CENTER
        transform = {}
        animations = [
          { prop = AnimProp.opacity, from = 0, to = 1, duration = 0.2, play = true, easing = OutCubic,
            onStart = @() sound_play("ui_sounds/round_mode_alert", 0.4) }
          { prop = AnimProp.opacity, from = 1, to = 0.5, duration = 0.4, delay = 0.2, play = true, easing = InOutCubic }
          { prop = AnimProp.opacity, from = 0.5, to = 0.8, duration = 0.2, delay = 0.6, play = true, easing = OutCubic }
          { prop = AnimProp.opacity, from = 0.8, to = 0, duration = 0.4, play = true, delay = 1, easing = InOutCubic }
          { prop = AnimProp.opacity, from = 0, to = 1, duration = 1, play = true, delay = 1.4, easing = InOutCubic }
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

let back = const {
  rendObj = ROBJ_IMAGE
  size = const [bgSize[0] * 2, bgSize[1]*2]
  color = const Color(0, 15, 30)
  image = Picture(const $"!ui/skin#round_grad.svg:{hdpxi(200)}:{hdpxi(150)}:K")
}

function gameInfo() {
  let state = nexusStartGameState.get()
  let waitStage = state in const {[NexusGameStartState.WaitingForPlayers]=1, [NexusGameStartState.WarmUp]=1}
  if ( !waitStage && nexusRoundModeRoundStartAt.get() <= 0)
     return const { watch = [nexusStartGameState, nexusRoundModeRoundStartAt], size = [bgSize[0] * 2, bgSize[1]]}
  return {
    watch = const [nexusStartGameState, nexusStartGameStateEndAll, nexusRoundModeRoundStartAt]
    halign = ALIGN_CENTER
    key = state
    children = [
      const {size = flex() children = back valign = ALIGN_CENTER halign = ALIGN_CENTER pos = [0, sh(3)]}
      {
        flow = FLOW_VERTICAL
        gap = hdpx(10)
        halign = ALIGN_CENTER
        children = [
          const {size = sh(3)},
          mkText(
            waitStage ? const utf8ToUpper(loc("nexus_game_start/waitForPlayers")) : const utf8ToUpper(loc("nexus/loadoutStage")),
            const {transform = {}, animations = [{ prop = AnimProp.translate, from = [0, hdpx(100)], to = [0, 0], duration = SHORT_ANIM_DURATION, play = true, easing = OutCubic}]}.__update(giant_txt)
          ),
          const alertSeparator.__merge({animations=[{ prop = AnimProp.opacity, from = 0, to = 1, duration = 0.2, play = true, easing = OutCubic }], opacity=1}),
          @() {
            watch = [nexusPlayersConnected, nexusPlayersExpected]
            clipChildren = true
            children = {
              flow = FLOW_HORIZONTAL
              valign = ALIGN_CENTER
              gap = const hdpx(2)
              transform = const {}
              animations = const [{ prop = AnimProp.translate, from = [0, -hdpx(100)], to = [0, 0], duration = SHORT_ANIM_DURATION, play = true, easing = OutCubic}]
              children = !waitStage
                ? const mkText(loc("nexus_game_start/chooseLoadout"), defTextStyle)
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
  let timer = mkCountdownTimerPerSec(nexusRoundModeRoundStartAt)
  return @() timer.get() <= 0 || timer.get() > 10 ? { watch = timer } : {
    watch = timer
    vplace = ALIGN_CENTER
    hplace = ALIGN_CENTER
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
    return const { watch }
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
          const {size=sh(5)}
          gameInfo
          {
            halign = ALIGN_CENTER
            valign = ALIGN_CENTER
            children = [
              mkNewRoundAlert()
              mkNexusRoundResultBlock()
            ]
          }
          const {size=flex(3)}
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
