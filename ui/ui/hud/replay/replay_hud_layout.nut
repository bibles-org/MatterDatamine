from "%sqstd/string.nut" import utf8ToUpper

from "dasevents" import CmdChangeTimeOfDay, CmdSetCameraFov, CmdSetBloomThreshold, CmdSetChromaticAberrationOffset,
  CmdSetCinematicModeEnabled, CmdSetFilmGrain, CmdSetMotionBlurScale, CmdSetVignetteStrength,
  CmdSetDofIsFilmic, CmdSetDofBokehCorners, CmdSetDofBokehSize, CmdSetDofFStop,
  CmdSetDofFocalLength, CmdSetDofFocusDistance, CmdSetCameraDofEnabled, CmdWeather,
  CmdSetRain, CmdSetSnow, CmdSetLightning, CmdSetLenseFlareIntensity,
  CmdSetCameraLerpFactor, CmdSetCinematicPostFxBloom, CmdSetCameraStopLerpFactor, ReplaySetFpsCamera,
  ReplaySetFreeTpsCamera, ReplaySetTpsCamera, ReplayToggleFreeCamera, NextReplayTarget,
  ReplaySetOperatorCamera, ReplaySetTrackCamera, CmdReplayRewind, CmdSetCameraShake, CmdSetLocalGravity,
  ReplayResetFreeCamera

from "%ui/fonts_style.nut" import h2_txt, sub_txt, body_txt
import "console" as console
from "%ui/components/button.nut" import textButton, fontIconButton, textButtonSmall
from "%ui/components/colors.nut" import BtnBgActive
from "%ui/hud/tips/tipComponent.nut" import tipCmp
import "camera" as camera
from "string" import format
from "%ui/hud/state/interactive_state.nut" import addInteractiveElement, removeInteractiveElement
from "%ui/helpers/time.nut" import secondsToString
import "%ui/components/faComp.nut" as faComp
from "%ui/components/modalWindows.nut" import addModalWindow, removeModalWindow
from "%ui/hud/replay/replayComponents.nut" import mkSlider, mkToggle, mkCheckbox, mkTimeline, panelBgColor, defTxtColor, smallPadding, titleTxtColor, accentColor
from "%ui/components/scrollbar.nut" import makeVertScrollExt, thinAndReservedPaddingStyle
from "%ui/components/mkSelection.nut" import mkSmallSelection
from "%ui/popup/popupsState.nut" import getPopups

import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *


let cursors = require("%ui/components/cursors.nut")
let JB = require("%ui/control/gui_buttons.nut")
let { watchedHeroEid } = require("%ui/hud/state/watched_hero.nut")
let vehicleSeats = require("%ui/hud/state/vehicle_seats.nut")
let { isGamepad } = require("%ui/control/active_controls.nut")
let { safeAreaVerPadding, safeAreaHorPadding } = require("%ui/options/safeArea.nut")
let { popupsGen } = require("%ui/popup/popupsState.nut")
let { chooseRandom } = require("%sqstd/rand.nut")

let isReplay = Watched(false)

ecs.register_es("replay_state_ui_es", {
    onInit = @(...) isReplay.set(true),
    onDestroy = @(...) isReplay.set(false)
  },
  { comps_rq=["replayIsPlaying"] },
  { tags="playingReplay" }
)

let canShowReplayHud = Watched(true)
let isTrackCamera = Watched(false)
let isFpsCamera = Watched(false)
let isOperatorCamera = Watched(false)
let isTpsCamera = Watched(false)
let isTpsFreeCamera = Watched(false)
let isFreeInput = Watched(false)
let isReplayAccelerationTo = Watched(false)
let replayTimeSpeed = Watched(0.0)
let replayCurTime = Watched(0.0)
let replayPlayTime = Watched(0.0)

const FPS_CAMERA = "FPS_CAMERA"
const TPS_CAMERA = "TPS_CAMERA"
const TPS_FREE_CAMERA = "TPS_FREE_CAMERA"
const OPERATOR_CAMERA = "OPERATOR_CAMERA"
const TRACK_CAMERA = "TRACK_CAMERA"

let activeCameraId = Computed(@() isTrackCamera.get() ? TRACK_CAMERA
  : isOperatorCamera.get() ? OPERATOR_CAMERA
  : isTpsFreeCamera.get() ? TPS_FREE_CAMERA
  : isTpsCamera.get() ? TPS_CAMERA
  : isFpsCamera.get() ? FPS_CAMERA
  : null)

ecs.register_es("replay_state_time_ui_es", {
    [[ "onInit", "onChange" ]] = function(_evt, _eid, comp) {
      replayTimeSpeed.set(comp["replay__speed"])
      replayCurTime.set(comp["replay__curTime"])
      replayPlayTime.set(comp["replay__playTime"])
    }
  },
  {
    comps_track = [
      ["replay__curTime", ecs.TYPE_FLOAT],
      ["replay__speed", ecs.TYPE_FLOAT],
    ],
    comps_ro = [
      ["replay__playTime", ecs.TYPE_FLOAT],
    ],
  }
)


ecs.register_es("replay_camera_is_free_tps", {
  [["onInit", "onChange"]] = @(_, comp) isTpsFreeCamera.set(comp.camera__active)
}, {
  comps_track = [["camera__active", ecs.TYPE_BOOL], ["camera__target", ecs.TYPE_EID]]
  comps_rq = [["replay_camera__tpsFree"]]
}, { tags = "playingReplay" })

ecs.register_es("replay_camera_is_tps", {
  [["onInit", "onChange"]] = @(_, comp) isTpsCamera.set(comp.camera__active)
}, {
  comps_track = [["camera__active", ecs.TYPE_BOOL]]
  comps_rq = [["camera__input_enabled"]],
  comps_no = [["replay_camera__tpsFree"]]
}, { tags = "playingReplay" })

ecs.register_es("replay_camera_is_fps", {
  [["onInit", "onChange"]] = @(_, comp) isFpsCamera.set(comp.isHeroCockpitCam && comp.camera__active)
}, {
  comps_track = [["camera__active", ecs.TYPE_BOOL]]
  comps_ro = [["isHeroCockpitCam", ecs.TYPE_BOOL]]
  comps_no = [["camera__input_enabled"]]
}, { tags = "playingReplay" })

ecs.register_es("replay_camera_is_operator", {
  [["onInit", "onChange"]] = @(_, comp) isOperatorCamera.set(comp.camera__active)
}, {
  comps_track = [["camera__active", ecs.TYPE_BOOL]]
  comps_rq = [["replay_camera__operator"]]
}, { tags = "playingReplay" })

ecs.register_es("replay_camera_is_track", {
  [["onInit", "onChange"]] = @(_, comp) isTrackCamera.set(comp.camera__active)
}, {
  comps_track = [["camera__active", ecs.TYPE_BOOL]]
  comps_rq = [["replay_camera__track"]]
}, { tags = "playingReplay" })

ecs.register_es("replay_camera_free_input", {
  [["onInit", "onChange"]] = @(_, comp) isFreeInput.set(comp.camera__input_enabled)
}, {
  comps_track = [["camera__input_enabled", ecs.TYPE_BOOL]],
  comps_rq = ["replayCamera"]
}, { tags = "playingReplay" })


ecs.register_es("ui_replay_acceleration_to", {
  onInit = @(_, _comp) isReplayAccelerationTo.set(true),
  onDestroy = @(_, _comp) isReplayAccelerationTo.set(false)
}, {
  comps_rq = ["replay__accelerationSpeed"]
}, { tags = "playingReplay" })







let levelTimeOfDay = Watched(0)
let cameraFov = Watched(0)
let cameraLerpFactor = Watched(0)
let cameraStopLerpFactor = Watched(0)
let hasCameraLerpFactor = Watched(false)
let motionBlur = Watched(0)
let bloomEffect = Watched(0)
let filmGrain = Watched(0)
let abberation = Watched(0)
let vigneteEffect = Watched(0)
let isDofCameraEnabled = WatchedImmediate(false)
let updateIsDofEnabled = function(v) {
  ecs.g_entity_mgr.broadcastEvent(CmdSetCameraDofEnabled({ enabled = v }))
  isDofCameraEnabled.set(v)
}
let isDofFilmic = Watched(false)
function setDofFilmic(v) {
  isDofFilmic.set(v)
  ecs.g_entity_mgr.broadcastEvent( CmdSetDofIsFilmic({ isFilmic = v }))
}
function setDofFilmicAndUpdateIsDofEnabled(v) {
  updateIsDofEnabled(v)
  setDofFilmic(v)
}
let isCameraShaking = Watched(false)
function setCameraShake(v) {
  isCameraShaking.set(v)
  ecs.g_entity_mgr.broadcastEvent( CmdSetCameraShake({ isCameraShaking = v }))
}
let isLocalGravity = Watched(true)
function setLocalGravity(v) {
  isLocalGravity.set(v)
  ecs.g_entity_mgr.broadcastEvent( CmdSetLocalGravity({ isLocalGravity = v }))
}
let isDofFocalActive = Watched(false)
let dofFocusDist = Watched(0)
let dofFocalLength = Watched(0)
let dofStop = Watched(0)
let dofBokeCount = Watched(0)
let dofBokeSize = Watched(0)
let dofFocalValToSafe = Watched(-1)
let weatherPresetList = Watched([])
let weatherPreset = Watched(null)
let isSnow = Watched(false)
let isRain = Watched(false)
let isLightning = Watched(false)
let isCinematicModeActive = Watched(false)
let updateCinematicMode = function(enabled) {
  ecs.g_entity_mgr.broadcastEvent(CmdSetCinematicModeEnabled({ enabled }))
  isCinematicModeActive.set(enabled)
}
let changeRain = function(enabled) {
  ecs.g_entity_mgr.broadcastEvent(CmdSetRain({ enabled }))
  isRain.set(enabled)
}
let changeSnow = function(enabled) {
  ecs.g_entity_mgr.broadcastEvent(CmdSetSnow({ enabled }))
  isSnow.set(enabled)
}
let changeLightning = function(enabled) {
  ecs.g_entity_mgr.broadcastEvent(CmdSetLightning({ enabled }))
  isLightning.set(enabled)
}


let hasSnow = Watched(false)
let hasRain = Watched(false)
let hasLightning = Watched(false)
let lenseFlareIntensity = Watched(0)
let enablePostBloom = Watched(false)
let changePostBloom = function(enabled) {
  ecs.g_entity_mgr.broadcastEvent(CmdSetCinematicPostFxBloom({ enabled }))
  enablePostBloom.set(enabled)
}
let isCinemaRecording = Watched(false)
let isCustomSettings = Watched(false)
let isSettingsChecked = Watched(false)

ecs.register_es("ui_time_of_day_track_es",
  {
    [["onInit","onChange"]] = @(_eid, comp) levelTimeOfDay.set(comp.cinematic_mode__dayTime)
  },
  {
    comps_track=[["cinematic_mode__dayTime", ecs.TYPE_FLOAT]]
  }
)

ecs.register_es("ui_get_is_rain_or_snow_es",
  {
    [["onInit","onChange"]] = function(_eid, comp) {
      changeRain(comp.cinematic_mode__rain)
      changeSnow(comp.cinematic_mode__snow)
      changeLightning(comp.cinematic_mode__lightning)
      hasRain.set(comp.cinematic_mode__hasRain)
      hasSnow.set(comp.cinematic_mode__hasSnow)
      hasLightning.set(comp.cinematic_mode__hasLightning)
    }
  },
  {
    comps_track=[
      ["cinematic_mode__rain", ecs.TYPE_BOOL],
      ["cinematic_mode__snow", ecs.TYPE_BOOL],
      ["cinematic_mode__lightning", ecs.TYPE_BOOL],
      ["cinematic_mode__hasRain", ecs.TYPE_BOOL],
      ["cinematic_mode__hasSnow", ecs.TYPE_BOOL],
      ["cinematic_mode__hasLightning", ecs.TYPE_BOOL],
    ]
  }
)


ecs.register_es("ui_camera_fov_track_es",
  {
    [["onInit","onChange"]] = function(_eid, comp) {
      if (!comp.camera__active)
        return
      cameraFov.set(comp.fovSettings)
      cameraStopLerpFactor.set(comp.replay_camera__stopInertia ?? cameraStopLerpFactor.get())
      cameraLerpFactor.set(comp.replay_camera__tpsLerpFactor ?? cameraLerpFactor.get())
      hasCameraLerpFactor.set(comp.replay_camera__tpsLerpFactor != null)
    }
  },
  {
    comps_track=[
      ["fovSettings", ecs.TYPE_FLOAT],
      ["camera__active", ecs.TYPE_BOOL],
      ["replay_camera__stopInertia", ecs.TYPE_FLOAT, null],
      ["replay_camera__tpsLerpFactor", ecs.TYPE_FLOAT, null],
    ]
  }
)

ecs.register_es("ui_dof_track_es",
  {
    [["onInit","onChange"]] = function(_eid, comp) {
      updateIsDofEnabled(comp.dof__on)
      setDofFilmic(comp.dof__is_filmic)
      dofFocusDist.set(comp.dof__focusDistance)
      dofFocalLength.set(comp.dof__focalLength_mm)
      dofStop.set(comp.dof__fStop)
      dofBokeCount.set(comp.dof__bokehShape_bladesCount)
      dofBokeSize.set(17.0 - comp.dof__bokehShape_kernelSize)
    }
  },
  {
    comps_track=[
      ["dof__on", ecs.TYPE_BOOL],
      ["dof__is_filmic", ecs.TYPE_BOOL],
      ["dof__focusDistance", ecs.TYPE_FLOAT],
      ["dof__focalLength_mm", ecs.TYPE_FLOAT],
      ["dof__fStop", ecs.TYPE_FLOAT],
      ["dof__bokehShape_bladesCount", ecs.TYPE_FLOAT],
      ["dof__bokehShape_kernelSize", ecs.TYPE_FLOAT],
    ]
  }
)

ecs.register_es("ui_cinematic_mode_es",
  {
    [["onInit","onChange"]] = function(_eid, comp) {
      motionBlur.set(comp.motion_blur__scale)
      
      abberation.set(1.0 - comp.cinematic_mode__chromaticAberration.z)
      filmGrain.set(comp.cinematic_mode__filmGrain.x)
      vigneteEffect.set(comp.cinematic_mode__vignetteStrength)
      weatherPreset.set(comp.cinematic_mode__weatherPreset)
      lenseFlareIntensity.set(comp.cinematic_mode__lenseFlareIntensity)
      changePostBloom(comp.cinematic_mode__enablePostBloom)
      isCinemaRecording.set(comp.cinematic_mode__recording)
      isCustomSettings.set(comp.settings_override__useCustomSettings)
      updateCinematicMode(true)
    },
    onDestroy = function(_eid, _comp) {
      motionBlur.set(0)
      bloomEffect.set(0)
      abberation.set(0)
      filmGrain.set(0)
      vigneteEffect.set(0)
      lenseFlareIntensity.set(0)
      changePostBloom(false)
      weatherPreset.set(null)
      isCustomSettings.set(isSettingsChecked.get())
      updateCinematicMode(false)
      isCinemaRecording.set(false)
    }
  },
  {
    comps_track=[
      ["cinematic_mode__lenseFlareIntensity", ecs.TYPE_FLOAT],
      ["motion_blur__scale", ecs.TYPE_FLOAT],
      
      ["cinematic_mode__chromaticAberration", ecs.TYPE_POINT3],
      ["cinematic_mode__filmGrain", ecs.TYPE_POINT3],
      ["cinematic_mode__vignetteStrength", ecs.TYPE_FLOAT],
      ["cinematic_mode__weatherPreset", ecs.TYPE_STRING],
      ["cinematic_mode__recording", ecs.TYPE_BOOL],
      ["settings_override__useCustomSettings", ecs.TYPE_BOOL],
      ["cinematic_mode__enablePostBloom", ecs.TYPE_BOOL],
    ],
    comps_rq = [
      "cinematic_mode_tag",
    ]
  }
)

function changeWeatherPreset(preset) {
  if (preset != null)
    ecs.g_entity_mgr.broadcastEvent( CmdWeather({ preset }))
}

ecs.register_es("ui_cinematic_weather_presets_es",
  {
    function onInit(_eid, comp){
      local res = comp.cinematic_mode__weatherPresetList.getAll() ?? []
      res = res.map(@(v) {
        locId = loc($"weatherPreset/{v}")
        preset = v
        setValue = @(_) changeWeatherPreset(v)
      })
      weatherPresetList.set(res)
    }
    onDestroy = @(_eid, _comp) weatherPresetList.set([])
  },
  {
    comps_ro=[
      ["cinematic_mode__weatherPresetList", ecs.TYPE_STRING_LIST]
    ]
  },
  {
    after="cinematic_mode_get_weathers_es"
  }
)

function setRandomWeather() {
  let presets = weatherPresetList.get()
  if (presets.len() <= 1)
    return
  let currentPreset = weatherPreset.get()
  local newPreset = ""
  while (currentPreset != newPreset && newPreset == "")
    newPreset = chooseRandom(presets).preset
  changeWeatherPreset(newPreset)
}


let changeDayTime = @(time)
  ecs.g_entity_mgr.broadcastEvent(CmdChangeTimeOfDay({ timeOfDay = time }))
let changeCameraFov = @(newVal)
  ecs.g_entity_mgr.broadcastEvent(CmdSetCameraFov({ fov = newVal.tointeger() }))
let changeCameraLerpFactor = @(newVal)
  ecs.g_entity_mgr.broadcastEvent(CmdSetCameraLerpFactor({ lerpFactor = newVal.tointeger() }))
let changeCameraStopLerpFactor = @(newVal)
  ecs.g_entity_mgr.broadcastEvent(CmdSetCameraStopLerpFactor({ stopLerpFactor = newVal }))
let changeBloom = @(newVal)
  ecs.g_entity_mgr.broadcastEvent(CmdSetBloomThreshold({ threshold = 1.0 - newVal }))
let changeAbberation = @(newVal)
  ecs.g_entity_mgr.broadcastEvent(CmdSetChromaticAberrationOffset({ offset = 1.0 - newVal }))
let changeFilmGrain = @(newVal)
  ecs.g_entity_mgr.broadcastEvent(CmdSetFilmGrain({ strength = newVal }))
let changeMotionBlur = @(newVal)
  ecs.g_entity_mgr.broadcastEvent(CmdSetMotionBlurScale({ scale = newVal }))
let changeVignette = @(newVal)
  ecs.g_entity_mgr.broadcastEvent(CmdSetVignetteStrength({ strength = newVal }))


let changeBoke = @(newVal)
  ecs.g_entity_mgr.broadcastEvent(CmdSetDofBokehCorners({ bokehCorners = newVal }))
let changeBokeSize = @(newVal)
  ecs.g_entity_mgr.broadcastEvent(CmdSetDofBokehSize({ bokehSize = 17.0 - newVal }))
let changeStop = @(newVal)
  ecs.g_entity_mgr.broadcastEvent(CmdSetDofFStop({ fStop = newVal }))
let changeFocalLength = @(newVal)
  ecs.g_entity_mgr.broadcastEvent(CmdSetDofFocalLength({ focalLength = newVal }))
let changeFocusDist = @(newVal)
  ecs.g_entity_mgr.broadcastEvent(CmdSetDofFocusDistance({ focusDistance = newVal }))
let changeLenseFlareIntensity = @(newVal)
  ecs.g_entity_mgr.broadcastEvent(CmdSetLenseFlareIntensity({ intensity = newVal }))

let replayBgColor = mul_color(panelBgColor, 0.8)

function mkPopupBlock(custom_style) {
  return function() {
    let children = []
    let popups = getPopups()
    foreach (idx, p in popups) {
      let popup = p
      let prevVisIdx = popup.visibleIdx.get()
      let curVisIdx = popups.len() - idx
      if (prevVisIdx != curVisIdx) {
        let prefix = curVisIdx > prevVisIdx ? "popupMoveTop" : "popupMoveBottom"
        anim_start(prefix + popup.id)
      }

      children.append({
        size = SIZE_TO_CONTENT
        key = $"popup_{popup.uid}"
        transform = {}
        behavior = Behaviors.RecalcHandler
        onRecalcLayout = @(_initial) popup.visibleIdx(curVisIdx)

        children = {
          rendObj = ROBJ_SOLID
          size = static [hdpx(300), hdpx(100)]
          color = replayBgColor
          valign = ALIGN_CENTER
          halign = ALIGN_CENTER
          children = {
            rendObj = ROBJ_TEXT
            text = popup.text
          }.__update(body_txt)
          key = $"popup_block_{popup.uid}"
        }
        animations = [
          { prop=AnimProp.opacity, from=0.0, to=1.0, duration=1.5, play=true, easing=OutCubic }
          { prop=AnimProp.translate, from=[0,-50], to=[0, 0], duration=1, trigger = $"popupMoveTop{popup.id}", play = true, easing=OutCubic }
          { prop=AnimProp.translate, from=[0,0], to=[0,-50], duration=1, trigger = $"popupMoveBottom{popup.id}", easing=OutCubic }
        ]
      })
    }
    return {
      watch = popupsGen
      size = SIZE_TO_CONTENT
      flow = FLOW_VERTICAL
      children = children
    }.__update(custom_style)
  }
}

let midPadding = hdpxi(8)
let bigPadding = hdpxi(12)
let largePadding = hdpxi(16)
let commonBtnHeight = hdpx(48)

let pressedButton = @(text, cb, params={}) textButton(text, cb, {style={BtnBgNormal=BtnBgActive}}.__update(params))

let timeSpeedVariants = [0, 0.125, 0.25, 0.5, 1, 2, 4, 8, 16]
let isAdvancedSettingsActive = Watched(false)
let isNavigationBlockHidden = Watched(false)
let showAdvancedSettings = keepref( Computed(@() canShowReplayHud.get() && isAdvancedSettingsActive.get()))

const CINEMATIC_SETTINGS_WND = "CINEMATIC_MODE_WND"
local lastReplayTimeSpeed = 1
let bottomMargin = [0, 0, hdpx(32), 0]

let isAllSettingsEnabled = WatchedRo(true)

let isSnowAvailable = Computed(@() hasSnow.get() && isAllSettingsEnabled.get() )
let isRainAvailable = Computed(@() hasRain.get() && isAllSettingsEnabled.get() )
let isLightningAvailable = Computed(@() hasLightning.get() && isAllSettingsEnabled.get() )

let needShowCursor = Computed(@() (canShowReplayHud.get()) && !(isGamepad.get() && isFreeInput.get()))




let gamepad_cursors_hide = Cursor(@() null)

let replayBlockPadding = [largePadding, hdpx(34)]
let hideHudBtnSize = [hdpx(30), hdpxi(56)]



let squareButtonStyle = { btnWidth = commonBtnHeight }
let defTxtStyle = { color = defTxtColor }.__update(h2_txt)
let titleTxtStyle = { color = titleTxtColor }.__update(body_txt)
let brightTxtStyle = { color = titleTxtColor }.__update(h2_txt)
let hintTxtStyle = { color = defTxtColor }.__update(sub_txt)
let headerTxtStyle = { color = titleTxtColor }.__update(body_txt)

function timeSpeedIncrease(curTimeSpeed) {
  foreach (timeSpeed in timeSpeedVariants)
    if (curTimeSpeed < timeSpeed) {
      console.command($"app.timeSpeed {timeSpeed}")
      return
    }
}


function timeSpeedDecrese(curTimeSpeed) {
  for (local i = timeSpeedVariants.len() - 1; i >= 0; --i)
    if (curTimeSpeed > timeSpeedVariants[i]) {
      console.command($"app.timeSpeed {timeSpeedVariants[i]}")
      return
    }
}

let hideReplayHudBtn = fontIconButton("chevron-down", @() canShowReplayHud.set(false), {
  btnHeight = hideHudBtnSize[0]
  btnWidth = hideHudBtnSize[1]
  style = { defBgColor = panelBgColor }
})

let hideReplayBlock = {
  hplace = ALIGN_CENTER
  flow = FLOW_VERTICAL
  gap = smallPadding
  halign = ALIGN_CENTER
  pos = [0, -hideHudBtnSize[0] / 2]
  children = [
    hideReplayHudBtn
    tipCmp({ inputId = "Replay.DisableHUD", style = { rendObj = null } })
  ]
}


let replayTiming = @() {
  watch = [replayCurTime, replayPlayTime]
  rendObj = ROBJ_TEXT
  text = $"{secondsToString(replayCurTime.get())} / {secondsToString(replayPlayTime.get())}"
}.__update(brightTxtStyle)


let replayTopBlock = @() {
  watch = replayPlayTime
  size = FLEX_H
  flow = FLOW_VERTICAL
  gap = bigPadding
  children = [
    {
      size = FLEX_H
      flow = FLOW_HORIZONTAL
      children = [
        replayTiming
      ]
    }
    mkTimeline(replayCurTime, {
      min = 0
      max = replayPlayTime.get()
      canChangeVal = true
      setValue = @(time) ecs.g_entity_mgr.broadcastEvent(CmdReplayRewind({ time = time * 1000 }))
    })
  ]
}

let bottomHint = @(text) {
  rendObj = ROBJ_TEXT
  text
}.__update(hintTxtStyle)

let mkSquareBtn = @(locId, action, btnHint) {
  flow = FLOW_VERTICAL
  gap = midPadding
  halign = ALIGN_CENTER
  children = [
    tipCmp({ inputId = btnHint, style = { rendObj = null } })
    fontIconButton(locId, action, {hplace=ALIGN_CENTER})
  ]
}


let replayTimeControl = @() {
  watch = replayTimeSpeed
  flow = FLOW_HORIZONTAL
  gap = largePadding
  children = [
    replayTimeSpeed.get() <= 0
      ? mkSquareBtn("play", @() console.command($"app.timeSpeed {lastReplayTimeSpeed}"),
        "Replay.Pause")
      : mkSquareBtn("pause", function(){
          lastReplayTimeSpeed = replayTimeSpeed.get()
          console.command("app.timeSpeed 0")
        }, "Replay.Pause")
    {
      flow = FLOW_HORIZONTAL
      gap = midPadding
      valign = ALIGN_BOTTOM
      children = [
        mkSquareBtn("minus", @() timeSpeedDecrese(replayTimeSpeed.get()), "Replay.SpeedDown")
        {
          rendObj = ROBJ_TEXT
          text = format("x%.3f", replayTimeSpeed.get())
          size = [SIZE_TO_CONTENT, commonBtnHeight]
          valign = ALIGN_CENTER
        }.__update(defTxtStyle)
        mkSquareBtn("plus", @() timeSpeedIncrease(replayTimeSpeed.get()), "Replay.SpeedUp")
      ]
    }
  ]
}

let replayTimeBlock = {
  flow = FLOW_VERTICAL
  gap = midPadding
  halign = ALIGN_CENTER
  children = [
    replayTimeControl
    bottomHint(loc("replay/timeBlockHint"))
  ]
}

let canUseFPSCam = Computed(function(){
  let seat = vehicleSeats.get().data.findvalue(@(s) s?.owner.eid == watchedHeroEid.get())
  return seat?.order?.canPlaceManually ?? true
})

function setFirstCameraActive() {
  if (canUseFPSCam.get())
    ecs.g_entity_mgr.broadcastEvent(ReplaySetFpsCamera())
}

let camerasList = [
  {
    text = "1"
    id = FPS_CAMERA
    action = setFirstCameraActive
    handlers = { ["Replay.Camera1"] = @(_event) setFirstCameraActive()}
    hotkey = "1"
    isEnabled = canUseFPSCam
  }
  {
    text = "2"
    id = TPS_CAMERA
    action = @() ecs.g_entity_mgr.broadcastEvent(ReplaySetTpsCamera())
    handlers = { ["Replay.Camera2"] =
      @(_event) ecs.g_entity_mgr.broadcastEvent(ReplaySetTpsCamera()) }
    hotkey ="2"
  }
  {
    text = "3"
    id = TPS_FREE_CAMERA
    action = @() ecs.g_entity_mgr.broadcastEvent(ReplaySetFreeTpsCamera())
    handlers = { ["Replay.Camera3"] =
      @(_event) ecs.g_entity_mgr.broadcastEvent(ReplaySetFreeTpsCamera()) }
    hotkey ="3"
  }
  {
    text = "4"
    id = OPERATOR_CAMERA
    action = @() ecs.g_entity_mgr.broadcastEvent(ReplaySetOperatorCamera())
    handlers = { ["Replay.Camera4"] =
      @(_event) ecs.g_entity_mgr.broadcastEvent(ReplaySetOperatorCamera()) }
    hotkey ="4"
  }
  {
    text = "5"
    id = TRACK_CAMERA
    action = @() ecs.g_entity_mgr.broadcastEvent(ReplaySetTrackCamera())
    handlers = { ["Replay.Camera5"] =
      @(_event) ecs.g_entity_mgr.broadcastEvent(ReplaySetTrackCamera()) }
    hotkey ="5"
  }
]


function changeCamera(delta) {
  let curCameraIdx = camerasList.findindex(@(v) v.id == activeCameraId.get())
  if (curCameraIdx == null)
    return
  let newIdx = curCameraIdx + delta
  if (camerasList?[newIdx] != null)
    camerasList[newIdx].action()
}

let wndEventHandlers = {
  ["Replay.DisableHUD"] = @(_event) canShowReplayHud.modify(@(v) !v),
  ["Replay.PrevCamera"] = @(_event) changeCamera(-1),
  ["Replay.NextCamera"] = @(_event) changeCamera(1),
  ["Replay.AdvancedSettings"] =
    @(_event) isAdvancedSettingsActive.set(!isAdvancedSettingsActive.get()),
  ["Replay.Next"] = @(_event) ecs.g_entity_mgr.sendEvent(camera.get_cur_cam_entity(),
    NextReplayTarget({ delta = 1 })),
  ["Replay.Prev"] = @(_event) ecs.g_entity_mgr.sendEvent(camera.get_cur_cam_entity(),
    NextReplayTarget({ delta = -1 })),
}


let replayCameraControl = @() {
  watch = [activeCameraId, canUseFPSCam]
  halign = ALIGN_CENTER
  flow = FLOW_VERTICAL
  gap = midPadding
  size = FLEX_H
  children = [
    {
      flow = FLOW_HORIZONTAL
      gap = hdpx(94)
      size = FLEX_H
      halign = ALIGN_CENTER
      children = [
        tipCmp({ inputId = "Replay.PrevCamera", style = { rendObj = null } })
        tipCmp({ inputId = "Replay.NextCamera", style = { rendObj = null } })
      ]
    }
    @() {
      watch = activeCameraId
      flow = FLOW_HORIZONTAL
      gap = bigPadding
      children = camerasList.map(function(cam) {
        let isPressed = activeCameraId.get() == cam.id
        let btnParams = squareButtonStyle.__merge({
          hotkeys = [[cam.hotkey, cam.action]]
          isEnabled = cam?.isEnabled.get() ?? true
          eventHandlers = { ["Replay.AdvancedSettings"] =
            @(_event) isAdvancedSettingsActive.set(!isAdvancedSettingsActive.get()) }
        })
        return isPressed
          ? pressedButton(cam.text, cam.action, btnParams)
          : textButton(cam.text, cam.action, btnParams)
      })
    }
    bottomHint(loc("replay/camera", {
      camera = loc($"replay/cameraType/{activeCameraId.get()}") }))
  ]
}


function mkBtnWithHint(btnParams) {
  let { text, action, btnHint, actionDesc, isBtnSelected = Watched(false),
    isBtnEnabled = Watched(true), eventHandlers = null } = btnParams
  return @() {
    watch = [isBtnSelected, isBtnEnabled]
    flow = FLOW_VERTICAL
    gap = midPadding
    halign = ALIGN_CENTER
    eventHandlers
    children = [
      tipCmp({ inputId = btnHint, style = { rendObj = null } })
      !isBtnEnabled.get() ? textButton(text, action, { isEnabled = false })
        : isBtnSelected.get() ? pressedButton(text, action)
        : textButton(text, action)
      {
        rendObj = ROBJ_TEXT
        text = actionDesc
      }.__update(hintTxtStyle)
    ]
  }
}

let buttons = [
  {
    text = loc("replay/resetFreeCamera")
    action = @() ecs.g_entity_mgr.broadcastEvent(ReplayResetFreeCamera())
    btnHint = "Replay.ResetCamera"
    actionDesc = loc("replay/resetFreeCameraHint")
    isBtnSelected = isFreeInput
    isBtnEnabled = isTpsFreeCamera
  }
  {
    text = loc("replay/tracking")
    action = @() ecs.g_entity_mgr.broadcastEvent(ReplayToggleFreeCamera())
    btnHint = "Replay.ToggleCamera"
    actionDesc = loc("replay/trackingHint")
    isBtnSelected = isFreeInput
    isBtnEnabled = isTpsFreeCamera
  }
  {
    text = loc("replay/advancedSettings")
    action = @() isAdvancedSettingsActive.set(!isAdvancedSettingsActive.get())
    btnHint = "Replay.AdvancedSettings"
    eventHandlers = { ["Replay.AdvancedSettings"] =
      @(_event) isAdvancedSettingsActive.set(!isAdvancedSettingsActive.get()) }
    actionDesc = loc("replay/advancedSettingsHint")
    isBtnSelected = isAdvancedSettingsActive
  }
]


let buttonsBlock = {
  flow = FLOW_HORIZONTAL
  gap = midPadding
  hplace = ALIGN_RIGHT
  valign = ALIGN_BOTTOM
  children = buttons.map(mkBtnWithHint)
}


let cinematicToggleBlock = @() {
  watch = isAllSettingsEnabled
  size = FLEX_H
  margin = bottomMargin
  valign = ALIGN_CENTER
  flow = FLOW_HORIZONTAL
  gap = bigPadding
  children = [
    {
      size = FLEX_H
      rendObj = ROBJ_TEXTAREA
      behavior = Behaviors.TextArea
      text = loc("replay/cinematicMode")
    }.__update(headerTxtStyle)
    mkToggle(isCinematicModeActive, isAllSettingsEnabled.get(), updateCinematicMode)
  ]
}

let cameraShakerToggleBlock = @() {
  watch = isAllSettingsEnabled
  size = FLEX_H
  margin = bottomMargin
  valign = ALIGN_CENTER
  flow = FLOW_HORIZONTAL
  gap = bigPadding
  children = [
    {
      size = FLEX_H
      rendObj = ROBJ_TEXTAREA
      behavior = Behaviors.TextArea
      text = loc("replay/cameraShaker")
    }.__update(headerTxtStyle)
    mkToggle(isCameraShaking, isAllSettingsEnabled.get(), setCameraShake)
  ]
}

let localGravityToggleBlock = @() {
  watch = isAllSettingsEnabled
  size = FLEX_H
  margin = bottomMargin
  valign = ALIGN_CENTER
  flow = FLOW_HORIZONTAL
  gap = bigPadding
  children = [
    {
      size = FLEX_H
      rendObj = ROBJ_TEXTAREA
      behavior = Behaviors.TextArea
      text = loc("replay/useLocalGravity")
    }.__update(headerTxtStyle)
    mkToggle(isLocalGravity, isAllSettingsEnabled.get(), setLocalGravity)
  ]
}


let mkSettingsHeader = @(text) {
  rendObj = ROBJ_TEXTAREA
  behavior = Behaviors.TextArea
  size = FLEX_H
  text = utf8ToUpper(text)
}.__update(titleTxtStyle)


let enviromentSettings = {
  size = FLEX_H
  flow = FLOW_VERTICAL
  gap = bigPadding
  children = [
    mkSettingsHeader(loc("replay/environment"))
      @() {
        watch = [levelTimeOfDay, isAllSettingsEnabled]
        size = FLEX_H
        children = mkSlider(levelTimeOfDay, loc("replay/dayTime"), {
            max = 24
            setValue = @(newTime) changeDayTime(newTime)
            valueToShow = secondsToString(levelTimeOfDay.get() * 60)
            isEnabled = isAllSettingsEnabled.get()
          })
      }
    function() {
      let wPreset = weatherPreset.get()
      let wHeader = wPreset != null
        ? loc("replay/wPreset", { preset = loc($"weatherPreset/{wPreset}")})
        : loc("replay/chooseWeather")
      return {
        watch = [weatherPresetList, weatherPreset, isAllSettingsEnabled]
        size = FLEX_H
        children = mkSmallSelection(weatherPresetList.get(), weatherPreset, {
          header = wHeader
          isEnabled = isAllSettingsEnabled.get()
        })
      }
    }
    @() {
      watch = [isSnowAvailable, isRainAvailable, isLightningAvailable]
      size = FLEX_H
      flow = FLOW_HORIZONTAL
      gap = static { size = flex() }
      children = [
        mkCheckbox(isSnow, loc("replay/weatherSnow"), isSnowAvailable.get(), changeSnow)
        mkCheckbox(isRain, loc("replay/weatherRain"), isRainAvailable.get(), changeRain)
        mkCheckbox(isLightning, loc("replay/weatherLightning"), isLightningAvailable.get(), changeLightning)
      ]
    }
    @() {
      watch = [weatherPresetList, isAllSettingsEnabled]
      children = textButtonSmall(loc("replay/randomWeather"), setRandomWeather, {
        isEnabled = isAllSettingsEnabled.get() && weatherPresetList.get().len() > 1
      })
    }
  ]
}


let cameraSettingsBlock = @() {
  watch = [cameraFov, isAllSettingsEnabled, cameraLerpFactor, hasCameraLerpFactor]
  size = FLEX_H
  margin = bottomMargin
  flow = FLOW_VERTICAL
  gap = bigPadding
  children = [
    mkSettingsHeader(loc("replay/cameraSettings"))
    mkSlider(cameraFov, loc("replay/cameraFov"), {
      setValue = @(newVal) changeCameraFov(newVal)
      min = 10
      max = 130
      isEnabled = isAllSettingsEnabled.get()
    })
    mkSlider(cameraLerpFactor, loc("replay/cameraLerpFactor"), {
      setValue = @(newVal) changeCameraLerpFactor(newVal)
      min = 1
      max = 10
      isEnabled = isAllSettingsEnabled.get() && hasCameraLerpFactor.get()
    })
    mkSlider(cameraStopLerpFactor, loc("replay/cameraStopLerpFactor"), {
      setValue = @(newVal) changeCameraStopLerpFactor(newVal)
      min = 0.75
      max = 0.99
      step = 0.01
      isEnabled = isAllSettingsEnabled.get() && isTpsFreeCamera.get()
    })
  ]
}


let dofToggleBlock = @() {
  watch = isAllSettingsEnabled
  size = FLEX_H
  valign = ALIGN_CENTER
  margin = bottomMargin
  flow = FLOW_HORIZONTAL
  gap = bigPadding
  children = [
    {
      size = FLEX_H
      rendObj = ROBJ_TEXTAREA
      behavior = Behaviors.TextArea
      text = loc("replay/dofMode")
    }.__update(headerTxtStyle)
    mkToggle(isDofFilmic, isAllSettingsEnabled.get(), setDofFilmicAndUpdateIsDofEnabled)
  ]
}

let dofSettings = @() {
  watch = [isDofFocalActive, isAllSettingsEnabled]
  size = FLEX_H
  flow = FLOW_VERTICAL
  gap = bigPadding
  children =  [
    mkSettingsHeader(loc("replay/dofSettings"))
    mkSlider(dofFocusDist, loc("replay/focusDist"), {
      min = 0.1
      max = 20
      setValue = @(newVal) changeFocusDist(newVal)
      isEnabled = isAllSettingsEnabled.get()
    })
    mkSlider(dofStop, loc("replay/focusStop"), {
      min = 1
      max = 22
      setValue = @(newVal) changeStop(newVal)
      isEnabled = isAllSettingsEnabled.get()
    })
    mkSlider(dofBokeCount, loc("replay/bokeCount"), {
      min = 3
      max = 15
      setValue = @(newVal) changeBoke(newVal)
      isEnabled = isAllSettingsEnabled.get()
    })
    mkSlider(dofBokeSize, loc("replay/bokeSize"), {
      min = 1
      max = 16
      setValue = @(newVal) changeBokeSize(newVal)
      isEnabled = isAllSettingsEnabled.get()
    })
    mkCheckbox(isDofFocalActive, loc("replay/isFocalActive"), isAllSettingsEnabled.get(),
      function(v) {
        isDofFocalActive.set(v)
        if (!v) {
          dofFocalValToSafe.set(dofFocalLength.get())
          changeFocalLength(-1)
        }
        else{
          changeFocalLength(dofFocalValToSafe.get())
          dofFocalLength.set(dofFocalValToSafe.get())
        }
      }
    )
    mkSlider(dofFocalLength, loc("replay/focalLength"), {
      min = 12
      max = 300
      setValue = @(newVal) changeFocalLength(newVal)
      isEnabled = isDofFocalActive.get() && isAllSettingsEnabled.get()
    })
  ]
}

let postProcessinSettings = @() {
  watch = [isAllSettingsEnabled, motionBlur, bloomEffect, filmGrain, abberation, vigneteEffect, lenseFlareIntensity]
  size = FLEX_H
  flow = FLOW_VERTICAL
  gap = bigPadding
  children = [
    mkSettingsHeader(loc("replay/postProcessing"))
    mkSlider(motionBlur, loc("replay/motionBlur"), {
      setValue = @(newVal) changeMotionBlur(newVal)
      step = 0.1
      isEnabled = isAllSettingsEnabled.get()
    })
    mkSlider(bloomEffect, loc("replay/bloomEffect"), {
      setValue = @(newVal) changeBloom(newVal)
      step = 0.1
      isEnabled = isAllSettingsEnabled.get()
    })
    mkSlider(filmGrain, loc("replay/filmicNoise"), {
      setValue = @(newVal) changeFilmGrain(newVal)
      step = 0.1
      isEnabled = isAllSettingsEnabled.get()
    })
    mkSlider(abberation, loc("replay/chromaticAbb"), {
      setValue = @(newVal) changeAbberation(newVal)
      step = 0.1
      isEnabled = isAllSettingsEnabled.get()
    })
    mkSlider(vigneteEffect, loc("replay/vignette"), {
      setValue = @(newVal) changeVignette(newVal)
      step = 0.1
      isEnabled = isAllSettingsEnabled.get()
    })
    mkSlider(lenseFlareIntensity, loc("replay/lensFlare"), {
      setValue = @(newVal) changeLenseFlareIntensity(newVal)
      step = 0.1
      isEnabled = isAllSettingsEnabled.get()
    })
  ]
}


let mkSettingsBlock = @(watchedFlag, content) @(){
  watch = watchedFlag
  size = FLEX_H
  transform = { scale = watchedFlag.get() ? static [1, 1] : static [1, 0] }
  transitions = static [ { prop = AnimProp.scale, duration = 0.4, easing = OutQuintic } ]
  margin = watchedFlag.get() ? bottomMargin : 0
  children = watchedFlag.get() ? content : null
}

let advancedSettingsWnd = {
  key = CINEMATIC_SETTINGS_WND
  rendObj = ROBJ_WORLD_BLUR_PANEL
  fillColor = replayBgColor
  size = static [fsh(42), flex()]
  margin = static hdpx(62)
  hplace = ALIGN_RIGHT
  vplace = ALIGN_TOP
  onClick = @() null
  hotkeys = [[$"^{JB.B} | Esc", @() isAdvancedSettingsActive.set(false)]]
  maxHeight = static sh(70)
  children = makeVertScrollExt(
    {
      flow = FLOW_VERTICAL
      size = FLEX_H
      padding = static [hdpx(18), hdpx(32)]
      children = [
        cameraSettingsBlock
        cameraShakerToggleBlock
        localGravityToggleBlock
        cinematicToggleBlock
        mkSettingsBlock(isCinematicModeActive, enviromentSettings)
        mkSettingsBlock(isCinematicModeActive, postProcessinSettings)
        dofToggleBlock
        mkSettingsBlock(isDofFilmic, dofSettings)
      ]
    }, {
      size = static flex(),
      styling = thinAndReservedPaddingStyle
      rootBase = {
        behavior = [Behaviors.Pannable]
        wheelStep = 1
      }
  })
}


showAdvancedSettings.subscribe_with_nasty_disregard_of_frp_update(@(v) v
  ? addModalWindow(advancedSettingsWnd)
  : removeModalWindow(CINEMATIC_SETTINGS_WND))


let replayBottomBlock = {
  size = FLEX_H
  flow = FLOW_HORIZONTAL
  valign = ALIGN_BOTTOM
  children = [
    {
      size = FLEX_H
      valign = ALIGN_BOTTOM
      flow = FLOW_HORIZONTAL
      gap = bigPadding
      children = [
        replayTimeBlock
        replayCameraControl
      ]
    }
    buttonsBlock
  ]
}


let replayNavigation = {
  size = static [fsh(170), fsh(21)]
  rendObj = ROBJ_WORLD_BLUR_PANEL
  fillColor = replayBgColor
  children = [
    hideReplayBlock
    {
      size = flex()
      flow = FLOW_VERTICAL
      gap = bigPadding
      padding = replayBlockPadding
      children = [
        replayTopBlock
        replayBottomBlock
      ]
    }
  ]
}


let mkHiddenNavigationBlock = function() {
  let stateFlags = Watched(0)
  return function() {
    let sf = stateFlags.get()
    if (isNavigationBlockHidden.get())
      return {
        watch = isNavigationBlockHidden
        onDetach = @() isNavigationBlockHidden.set(false)
      }
    return {
      watch = [stateFlags, isNavigationBlockHidden]
      onElemState = @(s) stateFlags.set(s)
      rendObj = ROBJ_WORLD_BLUR_PANEL
      fillColor = sf & S_HOVER ? accentColor : replayBgColor
      padding = [midPadding, hdpx(12)]
      halign = ALIGN_CENTER
      flow = FLOW_VERTICAL
      gap = smallPadding
      transform = {}
      animations = [
        { prop = AnimProp.opacity, from = 1, to = 0, duration = 1, delay = 4,
          play = true, onFinish = @() isNavigationBlockHidden.set(true) }
        { prop = AnimProp.opacity, from = 0, to = 0, delay = 4.9, duration = 1,
          play = true }
      ]
      children = [
        faComp("chevron-up", {
          fontSize = body_txt.fontSize
        })
        {
          flow = FLOW_HORIZONTAL
          gap = midPadding
          children = [
            tipCmp({ inputId = "Replay.DisableHUD", style = { rendObj = null } })
            {
              rendObj = ROBJ_TEXT
              text = loc("replay/showReplayUi")
            }.__update(hintTxtStyle)
          ]
        }
      ]
    }
  }
}

let replayNavigationBlock = @() {
  watch = canShowReplayHud
  children = canShowReplayHud.get()
    ? replayNavigation
    : mkHiddenNavigationBlock()
}

const ID = "ReplayHud"

function replayHudLayout() {
  camerasList.each(function(v) {
    let bindedKey = v.handlers.keys()[0]
    let bindedAction = v.handlers.values()[0]
    wndEventHandlers[bindedKey] <- bindedAction
  })
  return {
    watch = [needShowCursor, isFreeInput, isGamepad, safeAreaHorPadding, safeAreaVerPadding]
    size = flex()
    maxWidth = hdpx(1920)
    padding = [safeAreaVerPadding.get(), safeAreaHorPadding.get()]
    flow = FLOW_VERTICAL
    key = ID
    eventHandlers = wndEventHandlers
    hplace = ALIGN_CENTER
    halign = ALIGN_CENTER
    cursor = needShowCursor.get() ? cursors.normal : (isGamepad.get() ? gamepad_cursors_hide : null)
    valign = ALIGN_BOTTOM
    behavior = isFreeInput.get() ? DngBhv.ReplayFreeCameraControl : DngBhv.MenuCameraControl
    children = [
      mkPopupBlock({ hplace = ALIGN_LEFT }),
      replayNavigationBlock,
      function() {
        let watch = canShowReplayHud
        if (!canShowReplayHud.get())
          return { watch }
        return {
          watch
          onAttach = @() addInteractiveElement(ID)
          onDetach = @() removeInteractiveElement(ID)
        }
      }
    ]
  }
}
return {
  replayHudLayout
  isReplay
}