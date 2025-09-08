import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

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

let activeCameraId = Computed(@() isTrackCamera.value ? TRACK_CAMERA
  : isOperatorCamera.value ? OPERATOR_CAMERA
  : isTpsFreeCamera.value ? TPS_FREE_CAMERA
  : isTpsCamera.value ? TPS_CAMERA
  : isFpsCamera.value ? FPS_CAMERA
  : null)

ecs.register_es("replay_state_time_ui_es", {
    [[ "onInit", "onChange" ]] = function(_evt, _eid, comp) {
      replayTimeSpeed(comp["replay__speed"])
      replayCurTime(comp["replay__curTime"])
      replayPlayTime(comp["replay__playTime"])
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
  [["onInit", "onChange"]] = @(_, comp) isTpsFreeCamera(comp.camera__active)
}, {
  comps_track = [["camera__active", ecs.TYPE_BOOL], ["camera__target", ecs.TYPE_EID]]
  comps_rq = [["replay_camera__tpsFree"]]
}, { tags = "playingReplay" })

ecs.register_es("replay_camera_is_tps", {
  [["onInit", "onChange"]] = @(_, comp) isTpsCamera(comp.camera__active)
}, {
  comps_track = [["camera__active", ecs.TYPE_BOOL]]
  comps_rq = [["camera__input_enabled"]],
  comps_no = [["replay_camera__tpsFree"]]
}, { tags = "playingReplay" })

ecs.register_es("replay_camera_is_fps", {
  [["onInit", "onChange"]] = @(_, comp) isFpsCamera(comp.isHeroCockpitCam && comp.camera__active)
}, {
  comps_track = [["camera__active", ecs.TYPE_BOOL]]
  comps_ro = [["isHeroCockpitCam", ecs.TYPE_BOOL]]
  comps_no = [["camera__input_enabled"]]
}, { tags = "playingReplay" })

ecs.register_es("replay_camera_is_operator", {
  [["onInit", "onChange"]] = @(_, comp) isOperatorCamera(comp.camera__active)
}, {
  comps_track = [["camera__active", ecs.TYPE_BOOL]]
  comps_rq = [["replay_camera__operator"]]
}, { tags = "playingReplay" })

ecs.register_es("replay_camera_is_track", {
  [["onInit", "onChange"]] = @(_, comp) isTrackCamera(comp.camera__active)
}, {
  comps_track = [["camera__active", ecs.TYPE_BOOL]]
  comps_rq = [["replay_camera__track"]]
}, { tags = "playingReplay" })

ecs.register_es("replay_camera_free_input", {
  [["onInit", "onChange"]] = @(_, comp) isFreeInput(comp.camera__input_enabled)
}, {
  comps_track = [["camera__input_enabled", ecs.TYPE_BOOL]],
  comps_rq = ["replayCamera"]
}, { tags = "playingReplay" })


ecs.register_es("ui_replay_acceleration_to", {
  onInit = @(_, _comp) isReplayAccelerationTo(true),
  onDestroy = @(_, _comp) isReplayAccelerationTo(false)
}, {
  comps_rq = ["replay__accelerationSpeed"]
}, { tags = "playingReplay" })

return {
  replayCurTime
  replayPlayTime
  replayTimeSpeed
  isReplayStopped = Computed(@() replayTimeSpeed.value == 0)
  canShowReplayHud
  isTpsFreeCamera
  isTrackCamera
  isFreeInput
  FPS_CAMERA
  TPS_CAMERA
  TPS_FREE_CAMERA
  OPERATOR_CAMERA
  TRACK_CAMERA
  activeCameraId
  isReplayAccelerationTo
}
