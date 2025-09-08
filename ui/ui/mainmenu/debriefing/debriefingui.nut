import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *
import "%ui/components/colors.nut" as color

let { h1_txt, giant_txt, body_txt} = require("%ui/fonts_style.nut")
let {showDebriefing, computedDebriefingData, exitBattle } = require("debriefingState.nut")
let { deathCause } = require("death_cause.nut")
let { textButton } = require("%ui/components/button.nut")
let { playerProfileAMConvertionRate } = require("%ui/profile/profileState.nut")
let { mkText, mkTextArea } = require("%ui/components/commonComponents.nut")
let { localPlayerEid, localPlayerSpecTarget } = require("%ui/hud/state/local_player.nut")
let { sendNetEvent, CmdDebriefingUseRespawnDeviceRequest,
      CmdDebriefingSpectateRequest, EventNexusRequestReturnToSpawnQueue } = require("dasevents")
let { isNexus, isNexusRoundMode, isNexusWaveMode, isNexusGameFinished, nexusModeAdditionalWavesLeft } = require("%ui/hud/state/nexus_mode_state.nut")
let { nexusRoundModeRoundEndReason } = require("%ui/hud/state/nexus_round_mode_state.nut")
let { addInteractiveElement, removeInteractiveElement } = require("%ui/hud/state/interactive_state.nut")
let { NexusRoundFinishReason, GameEndReasons } = require("%sqGlob/dasenums.nut")
let { secondsToStringLoc } = require("%ui/helpers/time.nut")
let { endgameControllerDebriefingReason } = require("%ui/hud/state/endgame_controller_state.nut")
let { mkCountdownTimer, mkCountdownTimerPerSec } = require("%ui/helpers/timers.nut")
let { localResurrectionDevice, localResurrectionDeviceSelfDestroyAt } = require("%ui/hud/state/resurrect_device_state.nut")
let { get_sync_time } = require("net")
let colorize = require("%ui/components/colorize.nut")

let mkLocalResurrectionDeviceTimer = @() mkCountdownTimer(localResurrectionDeviceSelfDestroyAt)

let txt = function(text, style=null){
  return mkText(text, style ?? h1_txt)
}

let buttonWidth = hdpx(300)
let timeTillAutoSpectate = 5
let btnStyle = {
  size = [ buttonWidth, SIZE_TO_CONTENT ]
  halign = ALIGN_CENTER
}

let btnStyleRespawn = btnStyle.__merge({
  style = {
    BtnBgNormal = color.BtnPrimaryBgNormal
    TextNormal = color.BtnPrimaryTextNormal
  }
})

let closeButton = textButton(loc("gamemenu/btnExitBattle"), exitBattle, btnStyle)

let spectateButton = textButton(loc("briefing/spectate"), function() {
  ecs.g_entity_mgr.sendEvent(localPlayerEid.get(), CmdDebriefingSpectateRequest())
}, btnStyleRespawn)

let nexusRespawnButton = textButton(loc("briefing/respawn"), function() {
  ecs.g_entity_mgr.sendEvent(localPlayerEid.get(), CmdDebriefingSpectateRequest())
  if (isNexusWaveMode.get() && !isNexusGameFinished.get())
    ecs.g_entity_mgr.sendEvent(localPlayerEid.get(), EventNexusRequestReturnToSpawnQueue())
}, btnStyleRespawn)

function mkSpectateOnTimer() {
  let timer = mkCountdownTimerPerSec(Watched(timeTillAutoSpectate + get_sync_time()))
  return function() {
    if (timer.get() == 0)
      ecs.g_entity_mgr.sendEvent(localPlayerEid.get(), CmdDebriefingSpectateRequest())
    return {
      watch = timer
      size = [flex(), SIZE_TO_CONTENT]
      children = mkTextArea(loc("briefing/autoSpectateTimer", { time = colorize(color.InfoTextValueColor, timer.get()) }),
        { halign = ALIGN_CENTER }.__update(body_txt))
    }
  }
}


let nexusSpectateBlock = @() {
  watch = localPlayerEid
  size = [ buttonWidth, SIZE_TO_CONTENT ]
  flow = FLOW_VERTICAL
  gap = hdpx(20)
  children = [
    nexusRespawnButton
    localPlayerEid.get() != ecs.INVALID_ENTITY_ID ? mkSpectateOnTimer() : null
  ]
}

let btnStyleWait = btnStyle.__merge({
  style = {
    BtnBgNormal = color.BtnBgDisabled
    TextNormal = color.TextDisabled
  }
})

let waitSpecButton = textButton(loc("briefing/wait_spectate"), @() null, btnStyleWait)

let spectateOrWaitButton = @() {
  size = [ buttonWidth, SIZE_TO_CONTENT ]
  watch = localPlayerSpecTarget
  children = (localPlayerSpecTarget.get() != ecs.INVALID_ENTITY_ID) ? spectateButton : waitSpecButton
}

let mkRespawnDeviceButton = function() {
  let timer = mkLocalResurrectionDeviceTimer()
  return function(){
    let watch = [ localResurrectionDevice, endgameControllerDebriefingReason ]
    if (localResurrectionDevice.get() == ecs.INVALID_ENTITY_ID || endgameControllerDebriefingReason.get() == GameEndReasons.YOU_EXTRACTED)
      return { watch }

    return {
      size = [ buttonWidth, SIZE_TO_CONTENT ]
      watch = [ timer, localResurrectionDevice, endgameControllerDebriefingReason ]
      children = textButton(
        @() loc("briefing/respawn_device", {
          timeLeft=(localResurrectionDeviceSelfDestroyAt.get() != null ? $"({secondsToStringLoc(timer.get())})" : "")
        }),
        function() {
          sendNetEvent(localPlayerEid.get(), CmdDebriefingUseRespawnDeviceRequest())
        },
        btnStyleRespawn.__merge({ additionalWatched=[timer] })
      )
    }
  }
}

let nexusRoundEndReasonMap = {
  [NexusRoundFinishReason.ALL_DIED] = loc("nexus_round_mode_round_finish/all_died"),
  [NexusRoundFinishReason.TEAM_DIED] = loc("nexus_round_mode_round_finish/team_died"),
  [NexusRoundFinishReason.CAPTURE] = loc("nexus_round_mode_round_finish/capture"),
  [NexusRoundFinishReason.CAPTURE_ADVANTAGE] = loc("nexus_round_mode_round_finish/capture_advantage"),
  [NexusRoundFinishReason.POINTS] = loc("nexus_round_mode_round_finish/points"),
  [NexusRoundFinishReason.POINTS_ADVANTAGE] = loc("nexus_round_mode_round_finish/points_advantage"),
  [NexusRoundFinishReason.POINTS_DRAW] = loc("nexus_round_mode_round_finish/points_draw"),
  [NexusRoundFinishReason.TIME_OUT] = loc("nexus_round_mode_round_finish/time_out")
}

function altNexusRoundEndReasonComponent() {
  if (!isNexus.get())
    return { watch = isNexus }
  return {
    watch = [nexusRoundModeRoundEndReason, isNexus]
    children = nexusRoundEndReasonMap?[nexusRoundModeRoundEndReason.get()] != null ? [
      mkText(nexusRoundEndReasonMap?[nexusRoundModeRoundEndReason.get()], h1_txt)
    ] : null
  }
}

let debriefingAnims = [
  { prop=AnimProp.opacity, from=0, to=1, duration=0.75, play=true, easing=OutCubic }
  { prop=AnimProp.scale, from=[1,1], to=[1,0.01], duration=0.75, playFadeOut=true, easing=OutCubic }
  { prop=AnimProp.opacity, from=1, to=0, duration=0.75, playFadeOut=true, easing=OutCubic }
]

let debriefing = function(){
  let debriefingV = computedDebriefingData.value
  let allowSpectate = debriefingV?.allowSpectate ?? true
  let success = debriefingV?.result.success
  let fail = debriefingV?.result.fail ?? false
  let resurrectionTipAllowed = !isNexus.get()
  let result = loc(debriefingV?.result.result ?? (
    success ? "Success" : "Failed"
  ))
  let showButtons = debriefingV?.showButtons ?? true
  return {
    rendObj = ROBJ_SOLID
    watch = [computedDebriefingData, deathCause, playerProfileAMConvertionRate, isNexusGameFinished, isNexusWaveMode, isNexusRoundMode]
    color = Color(0, 0, 0, 240)
    size = [sw(100), sh(100)]
    stopMouse = true
    stopHotkeys = true
    animations = debriefingAnims
    behavior = DngBhv.ActivateActionSet
    actionSet = "StopInput"
    hotkeys = showButtons ? [
      ["^Esc", function() {
        if (debriefingV?.allowSpectate ?? true)
          ecs.g_entity_mgr.sendEvent(localPlayerEid.get(), CmdDebriefingSpectateRequest())
        else
          exitBattle()
      }]
    ] : null
    children = {
      size = [ hdpx(500), hdpx(300) ]
      flow = FLOW_VERTICAL
      hplace = ALIGN_CENTER
      vplace = ALIGN_CENTER
      halign = ALIGN_CENTER
      children = [
        txt(loc(result)).__update(giant_txt, {color = fail ? Color(190,20,20) : Color(60,235,145)}),
        altNexusRoundEndReasonComponent,
        fail && deathCause.value?.cause != null
          ? txt($"{loc("debriefing/deathCause")}: {loc(deathCause.value.cause, deathCause.value?.causeArgs)}")
          : null,
        { size = flex() },
        allowSpectate && fail && resurrectionTipAllowed ? txt(loc("ressurection_tip")).__update(h1_txt, {color = Color(60,235,145)}) : null,
        { size = flex() },
        showButtons ? {
          valign = ALIGN_TOP
          halign = ALIGN_CENTER
          flow = FLOW_HORIZONTAL
          gap = hdpx(10)
          children = [
            mkRespawnDeviceButton(),
            allowSpectate
              ? (isNexusRoundMode.get() || (isNexusWaveMode.get() && (nexusModeAdditionalWavesLeft.get() > 0)) ? nexusSpectateBlock : spectateOrWaitButton)
              : null,
            ((isNexus.get()) && !isNexusGameFinished.get()) ? null : closeButton, 
          ]
          onAttach = @() addInteractiveElement("debriefing")
          onDetach = @() removeInteractiveElement("debriefing")
        } : null
      ]
    }
  }
}

return {
  debriefingUi = @() {
    watch = showDebriefing
    children = showDebriefing.value ? debriefing : null
  }
}