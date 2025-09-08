import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let { h2_txt, sub_txt, body_txt } = require("%ui/fonts_style.nut")
let console = require("console")
let { panelBgColor, largePadding, commonBtnHeight, defTxtColor, midPadding, smallPadding, bigPadding,
  maxContentWidth, titleTxtColor, accentColor
} = require("designConst.nut")
let { textButton, fontIconButton, textButtonSmall } = require("%ui/components/button.nut")
let { BtnBgActive } = require("%ui/components/colors.nut")

let { tipCmp } = require("%ui/hud/tips/tipComponent.nut")
let { replayCurTime, replayPlayTime, replayTimeSpeed, canShowReplayHud, isTpsFreeCamera,
  isFreeInput, FPS_CAMERA, TPS_CAMERA, TPS_FREE_CAMERA, activeCameraId, OPERATOR_CAMERA,
  TRACK_CAMERA
} = require("replayState.nut")
let camera = require("camera")
let { format } = require("string")
let { ReplaySetFpsCamera, ReplaySetFreeTpsCamera, ReplaySetTpsCamera,
  ReplayToggleFreeCamera, NextReplayTarget, ReplaySetOperatorCamera,
  ReplaySetTrackCamera, CmdReplayRewind
} = require("dasevents")
let { addInteractiveElement, removeInteractiveElement } = require("%ui/hud/state/interactive_state.nut")
let { secondsToString } = require("%ui/helpers/time.nut")
let { isReplay } = require("%ui/hud/state/replay_state.nut")
let mkReplayTimeLine = require("%ui/hud/replay/mkReplayTimeLine.nut")
let faComp = require("%ui/components/faComp.nut")
let cursors = require("%ui/components/cursors.nut")
let { addModalWindow, removeModalWindow } = require("%ui/components/modalWindows.nut")
let mkToggle = require("mkToggle.nut")
let mkCheckbox = require("mkCheckbox.nut")
let mkReplaySlider = require("%ui/hud/replay/mkReplaySlider.nut")
let mkPopupBlock = require("%ui/hud/replay/mkReplayPopup.nut")
let { replayBgColor } = require("%ui/hud/replay/replayConst.nut")
let { utf8ToUpper } = require("%sqstd/string.nut")
let { makeVertScrollExt } = require("%ui/components/scrollbar.nut")
let { levelTimeOfDay, changeDayTime, changeCameraFov, cameraFov, isRain, isSnow, isLightning,
  isCinematicModeActive, changeBloom, changeAbberation, changeFilmGrain, changeMotionBlur,
  changeVignette, motionBlur, bloomEffect, filmGrain, abberation, vigneteEffect, weatherPreset,
  weatherPresetList, dofFocusDist, dofFocalLength, dofStop, dofBokeCount, dofBokeSize,
  changeBoke, changeBokeSize, changeStop, changeFocalLength, changeFocusDist,
  isDofFilmic, isDofFocalActive, setRandomWeather, hasSnow, hasRain, hasLightning,
  lenseFlareIntensity, changeLenseFlareIntensity, changeCameraLerpFactor, cameraLerpFactor,
  hasCameraLerpFactor, cameraStopLerpFactor, changeCameraStopLerpFactor
} = require("%ui/hud/replay/replayCinematicState.nut")
let { mkSmallSelection } = require("mkSelection.nut")
let JB = require("%ui/control/gui_buttons.nut")
let { watchedHeroEid } = require("%ui/hud/state/watched_hero.nut")
let vehicleSeats = require("%ui/hud/state/vehicle_seats.nut")
let { isGamepad } = require("%ui/control/active_controls.nut")
let { safeAreaVerPadding, safeAreaHorPadding } = require("%ui/options/safeArea.nut")

let pressedButton = @(text, cb, params={}) textButton(text, cb, {style={BtnBgNormal=BtnBgActive}}.__update(params))

let timeSpeedVariants = [0, 0.125, 0.25, 0.5, 1, 2, 4, 8, 16]
let isAdvancedSettingsActive = Watched(false)
let isNavigationBlockHidden = Watched(false)
let showAdvancedSettings = keepref( Computed(@() canShowReplayHud.value && isAdvancedSettingsActive.value))

const CINEMATIC_SETTINGS_WND = "CINEMATIC_MODE_WND"
local lastReplayTimeSpeed = 1
let bottomMargin = [0, 0, hdpx(32), 0]

let isAllSettingsEnabled = WatchedRo(true)

let isSnowAvailable = Computed(@() hasSnow.value && isAllSettingsEnabled.value )
let isRainAvailable = Computed(@() hasRain.value && isAllSettingsEnabled.value )
let isLightningAvailable = Computed(@() hasLightning.value && isAllSettingsEnabled.value )

let needShowCursor = Computed(@() (canShowReplayHud.value) && !(isGamepad.value && isFreeInput.value))




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

let hideReplayHudBtn = fontIconButton("chevron-down", @() canShowReplayHud(false), {
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
  text = $"{secondsToString(replayCurTime.value)} / {secondsToString(replayPlayTime.value)}"
}.__update(brightTxtStyle)


let replayTopBlock = @() {
  watch = replayPlayTime
  size = [flex(), SIZE_TO_CONTENT]
  flow = FLOW_VERTICAL
  gap = bigPadding
  children = [
    {
      size = [flex(), SIZE_TO_CONTENT]
      flow = FLOW_HORIZONTAL
      children = [
        replayTiming
      ]
    }
    mkReplayTimeLine(replayCurTime, {
      min = 0
      max = replayPlayTime.value
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
    replayTimeSpeed.value <= 0
      ? mkSquareBtn("play", @() console.command($"app.timeSpeed {lastReplayTimeSpeed}"),
        "Replay.Pause")
      : mkSquareBtn("pause", function(){
          lastReplayTimeSpeed = replayTimeSpeed.value
          console.command("app.timeSpeed 0")
        }, "Replay.Pause")
    {
      flow = FLOW_HORIZONTAL
      gap = midPadding
      valign = ALIGN_BOTTOM
      children = [
        mkSquareBtn("minus", @() timeSpeedDecrese(replayTimeSpeed.value), "Replay.SpeedDown")
        {
          rendObj = ROBJ_TEXT
          text = format("x%.3f", replayTimeSpeed.value)
          size = [SIZE_TO_CONTENT, commonBtnHeight]
          valign = ALIGN_CENTER
        }.__update(defTxtStyle)
        mkSquareBtn("plus", @() timeSpeedIncrease(replayTimeSpeed.value), "Replay.SpeedUp")
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
  let seat = vehicleSeats.value.data.findvalue(@(s) s?.owner.eid == watchedHeroEid.value)
  return seat?.order?.canPlaceManually ?? true
})

function setFirstCameraActive() {
  if (canUseFPSCam.value)
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
  let curCameraIdx = camerasList.findindex(@(v) v.id == activeCameraId.value)
  if (curCameraIdx == null)
    return
  let newIdx = curCameraIdx + delta
  if (camerasList?[newIdx] != null)
    camerasList[newIdx].action()
}

let wndEventHandlers = {
  ["Replay.PrevCamera"] = @(_event) changeCamera(-1),
  ["Replay.NextCamera"] = @(_event) changeCamera(1),
  ["Replay.AdvancedSettings"] =
    @(_event) isAdvancedSettingsActive(!isAdvancedSettingsActive.value),
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
  size = [flex(), SIZE_TO_CONTENT]
  children = [
    {
      flow = FLOW_HORIZONTAL
      gap = hdpx(94)
      size = [flex(), SIZE_TO_CONTENT]
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
        let isPressed = activeCameraId.value == cam.id
        let btnParams = squareButtonStyle.__merge({
          hotkeys = [[cam.hotkey, cam.action]]
          isEnabled = cam?.isEnabled.value ?? true
          eventHandlers = { ["Replay.AdvancedSettings"] =
            @(_event) isAdvancedSettingsActive(!isAdvancedSettingsActive.value) }
        })
        return isPressed
          ? pressedButton(cam.text, cam.action, btnParams)
          : textButton(cam.text, cam.action, btnParams)
      })
    }
    bottomHint(loc("replay/camera", {
      camera = loc($"replay/cameraType/{activeCameraId.value}") }))
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
      !isBtnEnabled.value ? textButton(text, action, { isEnabled = false })
        : isBtnSelected.value ? pressedButton(text, action)
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
    text = loc("replay/tracking")
    action = @() ecs.g_entity_mgr.broadcastEvent(ReplayToggleFreeCamera())
    btnHint = "Replay.ToggleCamera"
    actionDesc = loc("replay/trackingHint")
    isBtnSelected = isFreeInput
    isBtnEnabled = isTpsFreeCamera
  }
  {
    text = loc("replay/advancedSettings")
    action = @() isAdvancedSettingsActive(!isAdvancedSettingsActive.value)
    btnHint = "Replay.AdvancedSettings"
    eventHandlers = { ["Replay.AdvancedSettings"] =
      @(_event) isAdvancedSettingsActive(!isAdvancedSettingsActive.value) }
    actionDesc = loc("replay/advancedSettingsHint")
    isBtnSelected = isAdvancedSettingsActive
    isBtnEnabled = Watched(true)
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
  size = [flex(), SIZE_TO_CONTENT]
  margin = bottomMargin
  valign = ALIGN_CENTER
  flow = FLOW_HORIZONTAL
  gap = bigPadding
  children = [
    {
      size = [flex(), SIZE_TO_CONTENT]
      rendObj = ROBJ_TEXTAREA
      behavior = Behaviors.TextArea
      text = loc("replay/cinematicMode")
    }.__update(headerTxtStyle)
    mkToggle(isCinematicModeActive, isAllSettingsEnabled.value)
  ]
}


let mkSettingsHeader = @(text) {
  rendObj = ROBJ_TEXTAREA
  behavior = Behaviors.TextArea
  size = [flex(), SIZE_TO_CONTENT]
  text = utf8ToUpper(text)
}.__update(titleTxtStyle)


let enviromentSettings = {
  size = [flex(), SIZE_TO_CONTENT]
  flow = FLOW_VERTICAL
  gap = bigPadding
  children = [
    mkSettingsHeader(loc("replay/environment"))
      @() {
        watch = [levelTimeOfDay, isAllSettingsEnabled]
        size = [flex(), SIZE_TO_CONTENT]
        children = mkReplaySlider(levelTimeOfDay, loc("replay/dayTime"), {
            max = 24
            setValue = @(newTime) changeDayTime(newTime)
            valueToShow = secondsToString(levelTimeOfDay.value * 60)
            isEnabled = isAllSettingsEnabled.value
          })
      }
    function() {
      let wPreset = weatherPreset.value
      let wHeader = wPreset != null
        ? loc("replay/wPreset", { preset = loc($"weatherPreset/{wPreset}")})
        : loc("replay/chooseWeather")
      return {
        watch = [weatherPresetList, weatherPreset, isAllSettingsEnabled]
        size = [flex(), SIZE_TO_CONTENT]
        children = mkSmallSelection(weatherPresetList.value, weatherPreset, {
          header = wHeader
          isEnabled = isAllSettingsEnabled.value
        })
      }
    }
    @() {
      watch = [isSnowAvailable, isRainAvailable, isLightningAvailable]
      size = [flex(), SIZE_TO_CONTENT]
      flow = FLOW_HORIZONTAL
      gap = { size = flex() }
      children = [
        mkCheckbox(isSnow, loc("replay/weatherSnow"), {
          isActive = isSnowAvailable.value
          textParams = hintTxtStyle
          size = [flex(), SIZE_TO_CONTENT]
        })
        mkCheckbox(isRain, loc("replay/weatherRain"), {
          isActive = isRainAvailable.value
          textParams = hintTxtStyle
          size = [flex(), SIZE_TO_CONTENT]
        })
        mkCheckbox(isLightning, loc("replay/weatherLightning"), {
          isActive = isLightningAvailable.value
          textParams = hintTxtStyle
          size = [flex(), SIZE_TO_CONTENT]
        })
      ]
    }
    @() {
      watch = [weatherPresetList, isAllSettingsEnabled]
      children = textButtonSmall(loc("replay/randomWeather"), setRandomWeather, {
        isEnabled = isAllSettingsEnabled.value && weatherPresetList.value.len() > 1
      })
    }
  ]
}


let cameraSettingsBlock = @() {
  watch = [cameraFov, isAllSettingsEnabled, cameraLerpFactor, hasCameraLerpFactor]
  size = [flex(), SIZE_TO_CONTENT]
  margin = bottomMargin
  flow = FLOW_VERTICAL
  gap = bigPadding
  children = [
    mkSettingsHeader(loc("replay/cameraSettings"))
    mkReplaySlider(cameraFov, loc("replay/cameraFov"), {
      setValue = @(newVal) changeCameraFov(newVal)
      min = 10
      max = 130
      isEnabled = isAllSettingsEnabled.value
    })
    mkReplaySlider(cameraLerpFactor, loc("replay/cameraLerpFactor"), {
      setValue = @(newVal) changeCameraLerpFactor(newVal)
      min = 1
      max = 10
      isEnabled = isAllSettingsEnabled.value && hasCameraLerpFactor.value
    })
    mkReplaySlider(cameraStopLerpFactor, loc("replay/cameraStopLerpFactor"), {
      setValue = @(newVal) changeCameraStopLerpFactor(newVal)
      min = 0.75
      max = 0.99
      step = 0.01
      isEnabled = isAllSettingsEnabled.value && isTpsFreeCamera.value
    })
  ]
}


let dofToggleBlock = @() {
  watch = isAllSettingsEnabled
  size = [flex(), SIZE_TO_CONTENT]
  valign = ALIGN_CENTER
  margin = bottomMargin
  flow = FLOW_HORIZONTAL
  gap = bigPadding
  children = [
    {
      size = [flex(), SIZE_TO_CONTENT]
      rendObj = ROBJ_TEXTAREA
      behavior = Behaviors.TextArea
      text = loc("replay/dofMode")
    }.__update(headerTxtStyle)
    mkToggle(isDofFilmic, isAllSettingsEnabled.value)
  ]
}

let dofSettings = @() {
  watch = [isDofFocalActive, isAllSettingsEnabled]
  size = [flex(), SIZE_TO_CONTENT]
  flow = FLOW_VERTICAL
  gap = bigPadding
  children =  [
    mkSettingsHeader(loc("replay/dofSettings"))
    mkReplaySlider(dofFocusDist, loc("replay/focusDist"), {
      min = 0.1
      max = 20
      setValue = @(newVal) changeFocusDist(newVal)
      isEnabled = isAllSettingsEnabled.value
    })
    mkReplaySlider(dofStop, loc("replay/focusStop"), {
      min = 1
      max = 22
      setValue = @(newVal) changeStop(newVal)
      isEnabled = isAllSettingsEnabled.value
    })
    mkReplaySlider(dofBokeCount, loc("replay/bokeCount"), {
      min = 3
      max = 15
      setValue = @(newVal) changeBoke(newVal)
      isEnabled = isAllSettingsEnabled.value
    })
    mkReplaySlider(dofBokeSize, loc("replay/bokeSize"), {
      min = 1
      max = 16
      setValue = @(newVal) changeBokeSize(newVal)
      isEnabled = isAllSettingsEnabled.value
    })
    mkCheckbox(isDofFocalActive, loc("replay/isFocalActive"), {
      isActive = isAllSettingsEnabled.value
    })
    mkReplaySlider(dofFocalLength, loc("replay/focalLength"), {
      min = 12
      max = 300
      setValue = @(newVal) changeFocalLength(newVal)
      isEnabled = isDofFocalActive.value && isAllSettingsEnabled.value
    })
  ]
}

let postProcessinSettings = @() {
  watch = [isAllSettingsEnabled, motionBlur, bloomEffect, filmGrain, abberation, vigneteEffect, lenseFlareIntensity]
  size = [flex(), SIZE_TO_CONTENT]
  flow = FLOW_VERTICAL
  gap = bigPadding
  children = [
    mkSettingsHeader(loc("replay/postProcessing"))
    mkReplaySlider(motionBlur, loc("replay/motionBlur"), {
      setValue = @(newVal) changeMotionBlur(newVal)
      step = 0.1
      isEnabled = isAllSettingsEnabled.value
    })
    mkReplaySlider(bloomEffect, loc("replay/bloomEffect"), {
      setValue = @(newVal) changeBloom(newVal)
      step = 0.1
      isEnabled = isAllSettingsEnabled.value
    })
    mkReplaySlider(filmGrain, loc("replay/filmicNoise"), {
      setValue = @(newVal) changeFilmGrain(newVal)
      step = 0.1
      isEnabled = isAllSettingsEnabled.value
    })
    mkReplaySlider(abberation, loc("replay/chromaticAbb"), {
      setValue = @(newVal) changeAbberation(newVal)
      step = 0.1
      isEnabled = isAllSettingsEnabled.value
    })
    mkReplaySlider(vigneteEffect, loc("replay/vignette"), {
      setValue = @(newVal) changeVignette(newVal)
      step = 0.1
      isEnabled = isAllSettingsEnabled.value
    })
    mkReplaySlider(lenseFlareIntensity, loc("replay/lensFlare"), {
      setValue = @(newVal) changeLenseFlareIntensity(newVal)
      step = 0.1
      isEnabled = isAllSettingsEnabled.value
    })
  ]
}


let mkSettingsBlock = @(watchedFlag, content) @(){
  watch = watchedFlag
  size = [flex(), SIZE_TO_CONTENT]
  transform = { scale = watchedFlag.value ? [1, 1] : [1, 0] }
  transitions = [ { prop = AnimProp.scale, duration = 0.4, easing = OutQuintic } ]
  margin = watchedFlag.value ? bottomMargin : 0
  children = watchedFlag.value ? content : null
}

let advancedSettingsWnd = {
  key = CINEMATIC_SETTINGS_WND
  rendObj = ROBJ_WORLD_BLUR_PANEL
  fillColor = replayBgColor
  size = [fsh(42), SIZE_TO_CONTENT]
  margin = hdpx(62)
  hplace = ALIGN_RIGHT
  vplace = ALIGN_TOP
  onClick = @() null
  hotkeys = [[$"^{JB.B} | Esc", @() isAdvancedSettingsActive(false)]]
  children = makeVertScrollExt(
    {
      flow = FLOW_VERTICAL
      size = [flex(), SIZE_TO_CONTENT]
      padding = [hdpx(18), hdpx(32)]
      children = [
        cameraSettingsBlock
        cinematicToggleBlock
        mkSettingsBlock(isCinematicModeActive, enviromentSettings)
        mkSettingsBlock(isCinematicModeActive, postProcessinSettings)
        dofToggleBlock
        mkSettingsBlock(isDofFilmic, dofSettings)
      ]
    }, {
      size = [fsh(42), SIZE_TO_CONTENT],
      maxHeight = sh(70)
      rootBase = {
        behavior = [Behaviors.Pannable]
        wheelStep = 1
      }
  })
}

showAdvancedSettings.subscribe(@(v) v
  ? addModalWindow(advancedSettingsWnd)
  : removeModalWindow(CINEMATIC_SETTINGS_WND))



let replayBottomBlock = {
  size = [flex(), SIZE_TO_CONTENT]
  flow = FLOW_HORIZONTAL
  valign = ALIGN_BOTTOM
  children = [
    {
      size = [flex(), SIZE_TO_CONTENT]
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
  size = [fsh(170), fsh(21)]
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


let hiddenNavigationBlock = watchElemState(function(sf) {
  let res = {
    watch = isNavigationBlockHidden
    onDetach = @() isNavigationBlockHidden(false)
  }
  if (isNavigationBlockHidden.value)
    return res

  return res.__update({
    rendObj = ROBJ_WORLD_BLUR_PANEL
    fillColor = sf & S_HOVER ? accentColor : replayBgColor
    padding = [midPadding, hdpx(12)]
    halign = ALIGN_CENTER
    flow = FLOW_VERTICAL
    gap = smallPadding
    transform = {}
    animations = [
      { prop = AnimProp.opacity, from = 1, to = 0, duration = 1, delay = 4,
        play = true, onFinish = @() isNavigationBlockHidden(true) }
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
  })
})

let replayNavigationBlock = @() {
  watch = canShowReplayHud
  children = canShowReplayHud.value
    ? replayNavigation
    : hiddenNavigationBlock
}


foreach(s in [isReplay, canShowReplayHud])
  s.subscribe(@(...) (isReplay.value && canShowReplayHud.value ? addInteractiveElement : removeInteractiveElement)("ReplayHud"))


return function() {
  camerasList.each(function(v) {
    let bindedKey = v.handlers.keys()[0]
    let bindedAction = v.handlers.values()[0]
    wndEventHandlers[bindedKey] <- bindedAction
  })
  return {
    watch = [needShowCursor, isFreeInput, isGamepad, safeAreaHorPadding, safeAreaVerPadding]
    size = flex()
    maxWidth = maxContentWidth
    padding = [safeAreaVerPadding.value, safeAreaHorPadding.value]
    flow = FLOW_VERTICAL
    key = "ReplayHud"
    eventHandlers = wndEventHandlers
    hplace = ALIGN_CENTER
    halign = ALIGN_CENTER
    cursor = needShowCursor.value ? cursors.normal : (isGamepad.value ? gamepad_cursors_hide : null)
    valign = ALIGN_BOTTOM
    behavior = isFreeInput.value ? DngBhv.ReplayFreeCameraControl : DngBhv.MenuCameraControl
    children = [mkPopupBlock({
      hplace = ALIGN_LEFT
    }), {size=flex()}, replayNavigationBlock]
  }
}