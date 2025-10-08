from "%sqGlob/dasenums.nut" import NexusGameFinishReason, GameEndReasons

from "dasevents" import sendNetEvent, CmdDebriefingUseRespawnDeviceRequest, CmdDebriefingSpectateRequest, RequestNexusChangeLoadoutPlayer

from "%ui/fonts_style.nut" import h1_txt, giant_txt, body_txt
from "%ui/mainMenu/debriefing/debriefingState.nut" import exitBattle
from "%ui/components/button.nut" import textButton, button, defButtonStyle
from "%ui/components/commonComponents.nut" import mkText, mkTextArea
from "%ui/hud/state/interactive_state.nut" import addInteractiveElement, removeInteractiveElement
from "%ui/helpers/time.nut" import secondsToStringLoc
from "%ui/helpers/timers.nut" import mkCountdownTimer, mkCountdownTimerPerSec
from "net" import get_sync_time
from "%ui/components/msgbox.nut" import showMsgbox
from "%ui/hud/hud_menus_state.nut" import openMenu

import "%ui/components/colorize.nut" as colorize

import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *
import "%ui/components/colors.nut" as color

let { showDebriefing, computedDebriefingData } = require("%ui/mainMenu/debriefing/debriefingState.nut")
let { deathCause } = require("%ui/mainMenu/debriefing/death_cause.nut")
let { playerProfileAMConvertionRate } = require("%ui/profile/profileState.nut")
let { localPlayerEid, localPlayerSpecTarget } = require("%ui/hud/state/local_player.nut")
let { isNexus, isNexusRoundMode, isNexusWaveMode, isNexusGameFinished, isNexusPlayerCanSpawn } = require("%ui/hud/state/nexus_mode_state.nut")
let { nexusRoundModeRoundEndReason } = require("%ui/hud/state/nexus_round_mode_state.nut")
let { endgameControllerDebriefingReason } = require("%ui/hud/state/endgame_controller_state.nut")
let { localResurrectionDevice, localResurrectionDeviceSelfDestroyAt } = require("%ui/hud/state/resurrect_device_state.nut")
let { NexusLoadoutSelectionId } = require("%ui/hud/nexus_mode_loadout_selection_screen.nut")

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

let closeButton = textButton(loc("gamemenu/btnExitBattle"), @() showMsgbox({
    text = loc("gamemenu/btnExitBattleApply")
    buttons = [
      { text = loc("Yes"), action = exitBattle}
      { text = loc("No"), isCancel = true }
    ]
  }),
  btnStyle)

let spectateButton = textButton(loc("briefing/spectate"), function() {
  ecs.g_entity_mgr.sendEvent(localPlayerEid.get(), CmdDebriefingSpectateRequest())
}, btnStyleRespawn)

let nexusSpectateButton = textButton(loc("briefing/spectate"),
  @() ecs.g_entity_mgr.sendEvent(localPlayerEid.get(), CmdDebriefingSpectateRequest()),
  btnStyleRespawn)

function mkSpectateOnTimer() {
  let timer = mkCountdownTimerPerSec(Watched(timeTillAutoSpectate + get_sync_time()))
  return function() {
    if (timer.get() == 0)
      ecs.g_entity_mgr.sendEvent(localPlayerEid.get(), CmdDebriefingSpectateRequest())
    return {
      watch = timer
      size = FLEX_H
      children = mkTextArea(loc("briefing/autoSpectateTimer", { time = colorize(color.InfoTextValueColor, timer.get()) }),
        { halign = ALIGN_CENTER }.__update(body_txt))
    }
  }
}

let nexusSpectateBlock = @() {
  watch = [localPlayerEid, isNexusPlayerCanSpawn, isNexusWaveMode]
  size = [ buttonWidth, SIZE_TO_CONTENT ]
  flow = FLOW_VERTICAL
  gap = hdpx(20)
  children = [
    nexusSpectateButton
    localPlayerEid.get() != ecs.INVALID_ENTITY_ID ? mkSpectateOnTimer() : null
  ]
}

function respawnNexusWaveMode() {
  ecs.g_entity_mgr.sendEvent(localPlayerEid.get(), CmdDebriefingSpectateRequest())
  openMenu(NexusLoadoutSelectionId)
}

let nexusWaveRespawnButton = textButton(loc("NexusLoadoutSelection"), respawnNexusWaveMode, btnStyleRespawn)

function mkRespawnOnTimer() {
  let timer = mkCountdownTimerPerSec(Watched(timeTillAutoSpectate + get_sync_time()))
  return function() {
    if (timer.get() == 0)
      respawnNexusWaveMode()
    return {
      watch = timer
      size = FLEX_H
      children = mkTextArea(loc("briefing/autoRespawnTimer", { time = colorize(color.InfoTextValueColor, timer.get()) }),
        { halign = ALIGN_CENTER }.__update(body_txt))
    }
  }
}

function waveNexusRespawnBlock() {
  if (!isNexusWaveMode.get() || !isNexusPlayerCanSpawn.get())
    return { watch = [isNexusWaveMode, isNexusPlayerCanSpawn]}
  return {
    watch = [localPlayerEid, isNexusPlayerCanSpawn, isNexusWaveMode]
    size = [ buttonWidth, SIZE_TO_CONTENT ]
    flow = FLOW_VERTICAL
    gap = hdpx(20)
    children = [
      nexusWaveRespawnButton
      mkRespawnOnTimer()
    ]
  }
}

let btnStyleWait = btnStyle.__merge({
  style = {
    BtnBgNormal = color.BtnBgDisabled
    TextNormal = color.TextDisabled
  }
})

let waitSpecButton = textButton(loc("briefing/wait_spectate"), @() null, btnStyleWait)

let spectateOrWaitButton = @() {
  watch = localPlayerSpecTarget
  size = [ buttonWidth, SIZE_TO_CONTENT ]
  children = (localPlayerSpecTarget.get() != ecs.INVALID_ENTITY_ID) ? spectateButton : waitSpecButton
}

let mkRespawnDeviceButton = function() {
  let timer = mkLocalResurrectionDeviceTimer()
  return function() {
    let watch = [localResurrectionDevice, endgameControllerDebriefingReason]
    if (localResurrectionDevice.get() == ecs.INVALID_ENTITY_ID
      || endgameControllerDebriefingReason.get() == GameEndReasons.YOU_EXTRACTED
    )
      return { watch }
    return {
      watch
      children = button(@() {
          watch = timer
          children = mkText(loc("briefing/respawn_device", { timeLeft = secondsToStringLoc(timer.get()) }),
            { margin = defButtonStyle.textMargin }.__merge(body_txt))
        },
        @() sendNetEvent(localPlayerEid.get(), CmdDebriefingUseRespawnDeviceRequest()),
        {
          size = static [buttonWidth, SIZE_TO_CONTENT]
        }.__merge(btnStyleRespawn)
      )
    }
  }
}

let nexusRoundEndReasonMap = {
  [NexusGameFinishReason.ALL_DIED] = loc("nexus_round_mode_round_finish/all_died"),
  [NexusGameFinishReason.TEAM_DIED] = loc("nexus_round_mode_round_finish/team_died"),
  [NexusGameFinishReason.CAPTURE] = loc("nexus_round_mode_round_finish/capture"),
  [NexusGameFinishReason.CAPTURE_ADVANTAGE] = loc("nexus_round_mode_round_finish/capture_advantage"),
  [NexusGameFinishReason.POINTS] = loc("nexus_round_mode_round_finish/points"),
  [NexusGameFinishReason.POINTS_ADVANTAGE] = loc("nexus_round_mode_round_finish/points_advantage"),
  [NexusGameFinishReason.POINTS_DRAW] = loc("nexus_round_mode_round_finish/points_draw"),
  [NexusGameFinishReason.TIME_OUT] = loc("nexus_round_mode_round_finish/time_out")
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

let debriefing = function() {
  if (computedDebriefingData.get() == null)
    return { watch = computedDebriefingData }
  let debriefingV = computedDebriefingData.get()
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
    size = static [sw(100), sh(100)]
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
      size = static [ hdpx(500), hdpx(300) ]
      flow = FLOW_VERTICAL
      hplace = ALIGN_CENTER
      vplace = ALIGN_CENTER
      halign = ALIGN_CENTER
      children = [
        txt(loc(result)).__update(giant_txt, {color = fail ? Color(190,20,20) : Color(60,235,145)}),
        altNexusRoundEndReasonComponent,
        fail && deathCause.get()?.cause != null
          ? txt($"{loc("debriefing/deathCause")}: {loc(deathCause.get().cause, deathCause.get()?.causeArgs)}")
          : null,
        static { size = flex() },
        allowSpectate && fail && resurrectionTipAllowed ? txt(loc("ressurection_tip")).__update(h1_txt, {color = Color(60,235,145)}) : null,
        static { size = flex() },
        showButtons ? {
          valign = ALIGN_TOP
          halign = ALIGN_CENTER
          flow = FLOW_HORIZONTAL
          gap = hdpx(10)
          children = [
            mkRespawnDeviceButton(),
            waveNexusRespawnBlock,
            !allowSpectate ? null
              : (isNexusRoundMode.get() || isNexusWaveMode.get() ? nexusSpectateBlock : spectateOrWaitButton),
            ((isNexus.get()) && !isNexusGameFinished.get()) ? null : closeButton 
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
    children = showDebriefing.get() ? debriefing : null
  }
}
