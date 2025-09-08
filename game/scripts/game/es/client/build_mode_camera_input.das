require ecs
require DagorInput
require game.events.input_events
require game.events.events_active_matter
require game.events.events
require DagorMath
require math.base
require game.es.client.build_mode_grid_common
require game.es.client.build_mode_preview_common


def init_actions(var build_mode_camera_input__slide : uint16&;
                 var build_mode_camera_input__enableRotate : uint16&;
                 var build_mode_camera_input__rotate : uint16&;
                 var build_mode_camera_input__zoomIn : uint16&;
                 var build_mode_camera_input__zoomOut : uint16&)
  build_mode_camera_input__slide = get_action_handle("BuildCamera.Slide", TYPEGRP_STICK)
  build_mode_camera_input__enableRotate = get_action_handle("BuildCamera.EnableRotate", TYPEGRP_DIGITAL)
  build_mode_camera_input__rotate = get_action_handle("BuildCamera.Rotate", TYPEGRP_STICK)
  build_mode_camera_input__zoomIn = get_action_handle("BuildCamera.ZoomIn", TYPEGRP_DIGITAL)
  build_mode_camera_input__zoomOut = get_action_handle("BuildCamera.ZoomOut", TYPEGRP_DIGITAL)


def reset_actions(var build_mode_camera_input__slide : uint16&;
                  var build_mode_camera_input__enableRotate : uint16&;
                  var build_mode_camera_input__rotate : uint16&;
                  var build_mode_camera_input__zoomIn : uint16&;
                  var build_mode_camera_input__zoomOut : uint16&)
  build_mode_camera_input__slide = BAD_ACTION_HANDLE
  build_mode_camera_input__enableRotate = BAD_ACTION_HANDLE
  build_mode_camera_input__rotate = BAD_ACTION_HANDLE
  build_mode_camera_input__zoomIn = BAD_ACTION_HANDLE
  build_mode_camera_input__zoomOut = BAD_ACTION_HANDLE


[es(tag=input, on_appear, on_event=EventLevelLoaded)]
def build_camera_input_appear(evt : Event;
                              var build_mode_camera_input__slide : uint16&;
                              var build_mode_camera_input__enableRotate : uint16&;
                              var build_mode_camera_input__rotate : uint16&;
                              var build_mode_camera_input__zoomIn : uint16&;
                              var build_mode_camera_input__zoomOut : uint16&)
  init_actions(build_mode_camera_input__slide,
               build_mode_camera_input__enableRotate,
               build_mode_camera_input__rotate,
               build_mode_camera_input__zoomIn,
               build_mode_camera_input__zoomOut)


[es(tag=input)]
def build_camera_input_init(evt : EventDaInputInit;
                            var build_mode_camera_input__slide : uint16&;
                            var build_mode_camera_input__enableRotate : uint16&;
                            var build_mode_camera_input__rotate : uint16&;
                            var build_mode_camera_input__zoomIn : uint16&;
                            var build_mode_camera_input__zoomOut : uint16&)
  if evt.init
    init_actions(build_mode_camera_input__slide,
                 build_mode_camera_input__enableRotate,
                 build_mode_camera_input__rotate,
                 build_mode_camera_input__zoomIn,
                 build_mode_camera_input__zoomOut)
  else
    reset_actions(build_mode_camera_input__slide,
                  build_mode_camera_input__enableRotate,
                  build_mode_camera_input__rotate,
                  build_mode_camera_input__zoomIn,
                  build_mode_camera_input__zoomOut)


[es(tag=input, before=build_camera_control)]
def build_camera_lerp_params(input : UpdateStageUpdateInput;
                             eid : EntityId;
                             build_mode_camera_target__position : float3;
                             build_mode_camera_target__offsetDistance : float;
                             build_mode_camera_target__oXzAngleDegrees : float;
                             build_mode_camera_target__OyAngleDegrees : float;
                             build_mode_camera_target__animationDuration : float;
                             build_mode_camera_target__exitOnAnimationFinish : bool;
                             var build_mode_camera_target__positionCurrent : float3&;
                             var build_mode_camera_target__offsetDistanceCurrent : float&;
                             var build_mode_camera_target__oXzAngleDegreesCurrent : float&;
                             var build_mode_camera_target__OyAngleDegreesCurrent : float&;
                             var build_mode_camera_target__animationTimePassed : float&;
                             var camera__input_enabled : bool&)
  if build_mode_camera_target__animationTimePassed >= build_mode_camera_target__animationDuration
    if build_mode_camera_target__exitOnAnimationFinish
      destroyEntity(eid)
      return
    camera__input_enabled = true // must return input if it was disabled

    build_mode_camera_target__positionCurrent = build_mode_camera_target__position
    build_mode_camera_target__offsetDistanceCurrent = build_mode_camera_target__offsetDistance
    build_mode_camera_target__oXzAngleDegreesCurrent = build_mode_camera_target__oXzAngleDegrees
    build_mode_camera_target__OyAngleDegreesCurrent = build_mode_camera_target__OyAngleDegrees
    return

  camera__input_enabled = false

  let interpK = float3(input.dt /
                       (build_mode_camera_target__animationDuration - build_mode_camera_target__animationTimePassed))

  build_mode_camera_target__positionCurrent = lerp(build_mode_camera_target__positionCurrent,
                                                   build_mode_camera_target__position,
                                                   interpK)
  build_mode_camera_target__offsetDistanceCurrent = lerp(build_mode_camera_target__offsetDistanceCurrent,
                                                         build_mode_camera_target__offsetDistance,
                                                         interpK.x)
  build_mode_camera_target__oXzAngleDegreesCurrent = lerp(build_mode_camera_target__oXzAngleDegreesCurrent,
                                                          build_mode_camera_target__oXzAngleDegrees,
                                                          interpK.x)
  build_mode_camera_target__OyAngleDegreesCurrent = lerp(build_mode_camera_target__OyAngleDegreesCurrent,
                                                         build_mode_camera_target__OyAngleDegrees,
                                                         interpK.x)
  build_mode_camera_target__animationTimePassed += input.dt


[es(tag=input, no_order)]
def build_camera_control(input : UpdateStageUpdateInput;
                         build_mode_camera_target__positionCurrent : float3;
                         build_mode_camera_target__offsetDistanceCurrent : float;
                         build_mode_camera_target__oXzAngleDegreesCurrent : float;
                         build_mode_camera_target__OyAngleDegreesCurrent : float;
                         var transform : float3x4&)
  let heading = deg_to_rad(build_mode_camera_target__oXzAngleDegreesCurrent)
  let elevation = deg_to_rad(build_mode_camera_target__OyAngleDegreesCurrent)

  var rotation : quat
  euler_to_quat(heading, elevation, 0.0, rotation)
  let forward = float3(1.0, 0.0, 0.0)
  let directionFromLookPos = rotation * forward
  let newPosition = build_mode_camera_target__positionCurrent + directionFromLookPos * build_mode_camera_target__offsetDistanceCurrent

  // Camera will look in -directionFromLookPos direction,
  // (0,1,0) will be "up" direction
  transform[2] = -directionFromLookPos
  transform[0] = cross(float3(0.0, 1.0, 0.0), transform[2])
  transform[1] = cross(transform[2], transform[0])
  transform[3] = newPosition


[es(tag=input)]
def build_camera_input_zoom(evt : EventDaInputActionTriggered;
                            eid : EntityId;
                            camera__input_enabled : bool;
                            build_mode_camera_input__zoomIn : uint16;
                            build_mode_camera_input__zoomOut : uint16)
  if !camera__input_enabled
    return
  if build_mode_camera_input__zoomIn == evt.action
    sendEvent(eid, CmdBuildModeCameraZoom(zoomIn = true))

  if build_mode_camera_input__zoomOut == evt.action
    sendEvent(eid, CmdBuildModeCameraZoom(zoomIn = false))


[es]
def build_camera_zoom(evt : CmdBuildModeCameraZoom;
                      build_mode_camera_target__minMaxOffsetDistance : float2;
                      build_mode_camera_target__offsetDistanceMultiplier : float;
                      var build_mode_camera_target__offsetDistance : float&)
  if evt.zoomIn
    build_mode_camera_target__offsetDistance /= build_mode_camera_target__offsetDistanceMultiplier
  else
    build_mode_camera_target__offsetDistance *= build_mode_camera_target__offsetDistanceMultiplier

  build_mode_camera_target__offsetDistance = clamp(build_mode_camera_target__offsetDistance,
                                                   build_mode_camera_target__minMaxOffsetDistance.x,
                                                   build_mode_camera_target__minMaxOffsetDistance.y)


[es(tag=input, before=build_camera_lerp_params)]
def build_camera_slide(input : UpdateStageUpdateInput;
                       camera__input_enabled : bool;
                       build_mode_camera_input__slide : uint16;
                       build_mode_camera__speed : float;
                       transform : float3x4;
                       build_mode_camera__rotateAroundSelf : bool;
                       var build_mode_camera_target__position : float3&)
  if !camera__input_enabled
    return
  let slide = get_analog_stick_action_state(build_mode_camera_input__slide)
  if slide.x != 0.0 || slide.y != 0.0
    var worldTransform = float3x3()
    worldTransform[0] = transform[0]
    worldTransform[1] = float3(0.0, 1.0, 0.0)
    worldTransform[2] = normalize(x0z(transform[2]))
    let moveDirection = normalize(worldTransform * float3(slide.x, 0.0, slide.y))
    let cameraMove = moveDirection * input.dt * build_mode_camera__speed
    let newTargetPosition = build_mode_camera_target__position + cameraMove
    find_query() <| $ [es] (base_build_mode__activePreview : EntityId; base_build_mode__activeGrid : EntityId; base_build_mode__isGizmoActive : bool)
      let aroundSelfInGrid = build_mode_camera__rotateAroundSelf && is_point_in_grid(base_build_mode__activeGrid, transform[3] + cameraMove)
      let aroundTargetInGrid = !build_mode_camera__rotateAroundSelf && is_point_in_grid(base_build_mode__activeGrid, newTargetPosition)
      if aroundSelfInGrid || aroundTargetInGrid
        build_mode_camera_target__position = newTargetPosition
        if base_build_mode__isGizmoActive
          query(base_build_mode__activePreview) <| $ [es] (var transform : float3x4&)
            move_preview(cameraMove, base_build_mode__activeGrid, transform)
      return true


[es(tag=input, before=build_camera_lerp_params, before=build_camera_slide)]
def build_camera_rotation(input : UpdateStageUpdateInput;
                          camera__input_enabled : bool;
                          build_mode_camera_input__enableRotate : uint16;
                          build_mode_camera_input__rotate : uint16;
                          build_mode_camera__rotationSensitivity : float;
                          build_mode_camera__rotateAroundSelf : bool;
                          build_mode_camera_target__minMaxOyAngleDegrees : float2;
                          transform : float3x4;
                          var build_mode_camera_target__offsetDistance : float&;
                          var build_mode_camera_target__OyAngleDegrees : float&;
                          var build_mode_camera_target__oXzAngleDegrees : float&;
                          var build_mode_camera_target__position : float3&;
                          var build_mode_camera_input__rotateEnabled : bool&)
  if !camera__input_enabled
    return

  build_mode_camera_input__rotateEnabled = get_digital_action_state(uint16(build_mode_camera_input__enableRotate)).bState

  if !build_mode_camera_input__rotateEnabled
    return
  let rotate = get_analog_stick_action_state(build_mode_camera_input__rotate)
  let angleStep = rotate.x * build_mode_camera__rotationSensitivity
  let verticalStep = -rotate.y * build_mode_camera__rotationSensitivity

  let oldVertAngle = deg_to_rad(build_mode_camera_target__OyAngleDegrees)
  build_mode_camera_target__OyAngleDegrees += verticalStep
  build_mode_camera_target__OyAngleDegrees = clamp(build_mode_camera_target__OyAngleDegrees,
                                                   build_mode_camera_target__minMaxOyAngleDegrees.x,
                                                   build_mode_camera_target__minMaxOyAngleDegrees.y)
  build_mode_camera_target__oXzAngleDegrees += angleStep
  if build_mode_camera__rotateAroundSelf
    let vectorToTarget = build_mode_camera_target__position - transform[3]
    var tm = IDENT_TM
    rotyTM(-deg_to_rad(angleStep), tm)
    build_mode_camera_target__position = transform[3] + tm * vectorToTarget

    let currentVertAngle = deg_to_rad(build_mode_camera_target__OyAngleDegrees)

    let targetMoveDir = normalize(x0z(transform[2]))
    let horDist = distance(x0z(transform[3]), x0z(build_mode_camera_target__position))
    var oldSin = 0.0
    var oldCos = 0.0
    var curSin = 0.0
    var curCos = 0.0
    sincos(oldVertAngle, oldSin, oldCos)
    sincos(currentVertAngle, curSin, curCos)
    let diff = horDist * (oldSin / oldCos) / (curSin / curCos) - horDist
    build_mode_camera_target__position += targetMoveDir * diff
    build_mode_camera_target__offsetDistance *= oldSin / curSin
