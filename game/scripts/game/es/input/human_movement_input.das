require ecs
require ecs.common
require app
require math.base
require math.ang
require game.events.events
require game.es.action_common
require DagorMath
require DagorMathUtils
require DagorInput
require DagorDriver3D
require TouchInput
require HumanPhys
require DngHuman
require DngInputControls
require DngCamera
require game.es.states_common
require game.es.grav_zones_common


let DEFAULT_RESET_SPRINT_MOVEMENT_THRESHOLD = 0.7
let DEFAULT_RESET_SPRINT_MOVE_THRESHOLD = -0.1


def calc_sens_mult(human_net_phys : HumanActor; aiming_sens_mult : float; is_in_vehicle : bool) : double
  var result = 1.0lf
  let isZoomView = human_net_phys.phys.appliedCT |> is_control_bit_set(HumanPhysControlType.HCT_ZOOM_VIEW)
  let isAim = human_net_phys.phys.appliedCT |> is_control_bit_set(HumanPhysControlType.HCT_AIM)
  if isZoomView || isAim
    result = double(get_sens_scale().humanAiming * aiming_sens_mult)
  elif is_in_vehicle
    result = double(get_sens_scale().vehicleCam)
  elif get_cur_cam_entity() |> get_bool("isTpsView") ?? false
    result = double(get_sens_scale().humanTpsCam)
  else
    result = double(get_sens_scale().humanFpsCam)
  return result


def is_shoot_dir_blocked(human_net_phys : HumanActor)
  let isDowned = human_net_phys.phys.currentState |> human_phys_state_get_is_downed()
  let revivingCount = human_net_phys.eid |> get_int("hitpoints__revivingCount") ?? 0
  return isDowned && revivingCount > 0

def update_look_dir(var human_net_phys : HumanActor&;
                    var aim_angle : float2&;
                    var aim_angle_old : float2&; //Might need to change them if root dir changes
                    var prev_root_direction : float3&;
                    var prev_vert_direction : float3&;
                    aim_offset : float2;
                    vert_look_angle_limit : float2;
                    human_input__gunToAimAngleLimit : float2;
                    human_input__gunToAimAngleCrawlLimit : float2;
                    gun_angles : float2;
                    persp_wk : float;
                    ax : double = 0.0lf;
                    ay : double = 0.0lf;
                    lx : float = 0.0;
                    ly : float = 0.0)
  let vertLookAngleLimit = float2(max(vert_look_angle_limit.x, -SAFE_HALF_PI),
                                  min(vert_look_angle_limit.y, SAFE_HALF_PI))
  let aimAngleUnbounded = aim_angle + float2(ax, ay) * safeinv(persp_wk)
  aim_angle.x = norm_s_ang(aimAngleUnbounded.x)
  aim_angle.y = clamp(aimAngleUnbounded.y, vertLookAngleLimit.x, vertLookAngleLimit.y)
  var angleLimit : float2
  if human_net_phys.phys.currentState.isCrawl
    angleLimit = deg_to_rad(human_input__gunToAimAngleCrawlLimit)
  else
    angleLimit = deg_to_rad(human_input__gunToAimAngleLimit)
  let gunDir = angles_to_dir(gun_angles)
  let gunAnglesLocal = basis_aware_dir_to_angles(gunDir, prev_vert_direction, prev_root_direction)
  aim_angle.x = clamp_s_ang(aim_angle.x, gunAnglesLocal.x, -angleLimit.x, angleLimit.y)

  var lookAngle = aim_angle + float2(lx, ly)
  lookAngle.y = clamp(lookAngle.y, vertLookAngleLimit.x, vertLookAngleLimit.y)

  let curVertDirection = human_net_phys.phys.currentState.vertDirection
  let prevVertDirection = human_net_phys.phys.previousState.vertDirection
  let interpK = get_phys_interpk_clamped(human_net_phys.phys, get_sync_time())

  //See how vert changed since the last time and rotate root the same way
  let rotationBetweenStates = quat_rotation_arc(prevVertDirection, curVertDirection)
  let identQuat = quat(0.f, 0.f, 0.f, 1.f)
  let interpQuat = slerp(identQuat, rotationBetweenStates, interpK)
  let instantVertDirection = interpQuat * prevVertDirection

  let vertRotation = quat_rotation_arc(prev_vert_direction, instantVertDirection)
  let startingVertDir = prev_vert_direction
  let startingRootDir = prev_root_direction
  prev_root_direction = vertRotation * prev_root_direction
  prev_vert_direction = instantVertDirection

  // wish shoot dir
  if !is_shoot_dir_blocked(human_net_phys)
    let shootAngle = aim_angle + aim_offset
    let dir = basis_aware_angles_to_dir(shootAngle, prev_vert_direction, prev_root_direction)
    human_net_phys.phys.producedCT |> human_control_state_set_wish_shoot_dir(dir)

  // wish look dir
  let ldir = basis_aware_angles_to_dir(lookAngle, prev_vert_direction, prev_root_direction)
  human_net_phys.phys.producedCT |> human_control_state_set_wish_look_dir(ldir)

  //rebase aimAngles to deterministic basis
  //rawAngleDir and rawOldAngleDir use different roots because
  //we want out look dir to change when gravity changes
  //but aim_angle_old we simply want to rebase and keep as it was
  let rawAngleDir = basis_aware_angles_to_dir(aim_angle, prev_vert_direction, prev_root_direction)
  let rawOldAngleDir = basis_aware_angles_to_dir(aim_angle_old, startingVertDir, startingRootDir)
  let newRoot = get_some_normal(prev_vert_direction)
  aim_angle = basis_aware_dir_to_angles(rawAngleDir, prev_vert_direction, newRoot)
  aim_angle_old = basis_aware_dir_to_angles(rawOldAngleDir, prev_vert_direction, newRoot)
  prev_root_direction = newRoot


def update_walk_dir(var human_net_phys : HumanActor&;
                    move : double = 0.0lf;
                    strafe : double = 0.0lf)
  human_net_phys.phys.producedCT |> human_control_state_set_walk_dir(float2(move, -strafe))


def update_movement_directions(human_input__aim : int;
                               human_input__aimDelta : int;
                               human_input__look : int;
                               human_input__move : int;
                               human_input__sprint : int;
                               human_input__perspWk : float;
                               aim_offset : float2&;
                               human_input__gunToAimAngleLimit : float2;
                               human_input__gunToAimAngleCrawlLimit : float2;
                               human_weap__prevGunAngles : float2;
                               vehicle_input__aim : int const?;
                               human__sneaking : bool;
                               human__sneakSpeed : float;
                               sensMult : double;
                               vert_look_angle_limit : float2;
                               need_update_look_dir : bool;
                               need_update_walk_dir : bool;
                               look_axis_value_clamp : float2;
                               human_input__resetSprintMovementThreshold : float;
                               human_input__resetSprintMoveThreshold : float;
                               var prev_root_direction : float3&;
                               var prev_vert_direction : float3&;
                               var human_net_phys : HumanActor&;
                               var aim_angle : float2&;
                               var aim_angle_old : float2&;
                               var human_input__lookAngle : float2&)
  if need_update_look_dir
    let inputDotAim = vehicle_input__aim != null ? *vehicle_input__aim : human_input__aim
    let asAim = get_analog_stick_action_state(uint16(inputDotAim))
    let asLook = get_analog_stick_action_state(uint16(human_input__look))
    let touchAim = get_stick_value(uint16(human_input__aim))

    var ax = asAim.bActive ? double(asAim.x + touchAim.x) : 0.0lf
    var ay = asAim.bActive ? double(asAim.y + touchAim.y) : 0.0lf

    ax *= sensMult
    ay *= sensMult

    // Aim delta
    let asAimDelta = get_analog_stick_action_state(uint16(human_input__aimDelta))
    if asAimDelta.bActive
      ax += double(asAimDelta.x)
      ay += double(asAimDelta.y)

    // Look
    let prevLookAngle = human_input__lookAngle
    human_input__lookAngle = float2(0, 0)
    if asLook.bActive
      if human_net_phys.phys |> human_phys_isAiming()
        ax += double(asLook.x)
        ay += double(asLook.y)
      else
        human_input__lookAngle.x = clamp(prevLookAngle.x + asLook.x,
                                            -look_axis_value_clamp.x,
                                            look_axis_value_clamp.x)
        human_input__lookAngle.y = clamp(prevLookAngle.y + asLook.y,
                                            -look_axis_value_clamp.y,
                                            look_axis_value_clamp.y)

    update_look_dir(human_net_phys,
                    aim_angle,
                    aim_angle_old,
                    prev_root_direction,
                    prev_vert_direction,
                    aim_offset,
                    vert_look_angle_limit,
                    human_input__gunToAimAngleLimit,
                    human_input__gunToAimAngleCrawlLimit,
                    human_weap__prevGunAngles,
                    human_input__perspWk,
                    ax * double(PI),
                    ay * double(PI),
                    human_input__lookAngle.x * PI,
                    human_input__lookAngle.y * PI)

  if need_update_look_dir && !need_update_walk_dir
    return

  var strafe = 0.0lf
  var move = 0.0lf
  if need_update_walk_dir
    let asMove = get_analog_stick_action_state(uint16(human_input__move))
    let touchMove = get_stick_value(uint16(human_input__move))
    move = clamp(double(asMove.y + touchMove.y), -1.0lf, 1.0lf)
    strafe = clamp(double(asMove.x + touchMove.x), -1.0lf, 1.0lf)

  let sneakMod = human__sneaking ? double(human__sneakSpeed) : double(1.0)
  update_walk_dir(human_net_phys, move * sneakMod, strafe * sneakMod)

  if (abs(move) + abs(strafe) < double(human_input__resetSprintMovementThreshold) ||
      move < double(human_input__resetSprintMoveThreshold))
    reset_digital_action_sticky_toggle(uint16(human_input__sprint))


def fix_changed_hero_input(var human_net_phys : HumanActor&)
  assume phys = human_net_phys.phys
  assume ct = phys.producedCT
  ct |> human_control_state_set_control_bit(HumanPhysControlType.HCT_JUMP, false)
  ct |> human_control_state_set_control_bit(HumanPhysControlType.HCT_CRAWL, phys.previousState.isCrawl)
  ct |> human_control_state_set_control_bit(HumanPhysControlType.HCT_CROUCH, phys.previousState.isCrouch)
  ct |> human_control_state_set_control_bit(HumanPhysControlType.HCT_RELOAD, false)
  ct |> human_control_state_set_throw_state(false, HumanControlThrowSlot.HCTS_SLOT0)
  ct |> human_control_state_set_control_bit(HumanPhysControlType.HCT_THROW_BACK, false)
  ct |> human_control_state_set_control_bit(HumanPhysControlType.HCT_MELEE, false)


def set_ct_controlbit(var human_net_phys : HumanActor&;
                      state : HumanPhysControlType;
                      action : uint16)
  if is_action_active(action)
    let value = get_digital_action_state(action).bState || is_button_pressed(action)
    human_net_phys.phys.producedCT |> human_control_state_set_control_bit(state, value)


[es(tag=input, on_appear, track=human_anim__vehicleSelected, before=human_input_es)]
def human_input_init_follow_vehicle_es(evt : Event;
                                       human_anim__vehicleSelected : EntityId;
                                       var human_input__lastVehicleAngle : float&;
                                       var human_input__lastVehicleAngleDelta : float&)
  human_input__lastVehicleAngleDelta = 0.0
  human_input__lastVehicleAngle = 0.0
  query(human_anim__vehicleSelected) <| $ [es] (transform : float3x4)
    human_input__lastVehicleAngle = dir_to_angles(transform[0]).x


[es(tag=input, before=human_input_es)]
def human_input_set_vertical_angle_limits(info : UpdateStageUpdateInput;
                                          eid : EntityId;
                                          human_net_phys : HumanActor;
                                          human_input__defaultVertLookAngleLimit : float2;
                                          var human_input__vertLookAngleLimit : float2&;
                                          var human_input__vertLookAngleLimitChanged : bool&;
                                          human_input__vertLookAngleLimitOnLadder : float2 const?;
                                          human_input__vertLookAngleLimitCrawl : float2 const?;
                                          human_input__vertLookAngleLimitViscosity : float = 0.2;
                                          human_freefall__isFreefall = false;
                                          human_freefall__vertLookAngleLimit : float2 const?)
  var newAngleLimit = human_input__vertLookAngleLimit

  if human_freefall__vertLookAngleLimit != null && human_freefall__isFreefall
    newAngleLimit = *human_freefall__vertLookAngleLimit
  elif human_input__vertLookAngleLimitOnLadder != null && human_net_phys.phys.currentState.isAttachedToLadder
    newAngleLimit = *human_input__vertLookAngleLimitOnLadder
  elif human_input__vertLookAngleLimitCrawl != null && human_net_phys.phys.currentState.isCrawl
    newAngleLimit = *human_input__vertLookAngleLimitCrawl
  else
    newAngleLimit = human_input__defaultVertLookAngleLimit

  find_query() <| $ [es] (game_effect__attachedTo : EntityId; game_effect__vertLookAngleLimit : float2)
    if game_effect__attachedTo != eid
      return false
    newAngleLimit = game_effect__vertLookAngleLimit
    return true

  newAngleLimit = approach(human_input__vertLookAngleLimit, newAngleLimit, info.dt, human_input__vertLookAngleLimitViscosity)

  if newAngleLimit != human_input__vertLookAngleLimit
    human_input__vertLookAngleLimit = newAngleLimit
    human_input__vertLookAngleLimitChanged = true


[es(tag=input, no_order, REQUIRE=human_input__aim, on_event=UpdateStageInfoBeforeRender)]
def human_input_persp_es(evt : Event;
                         camera_input__disabled : bool = false;
                         var human_input__perspWk : float&)
  if camera_input__disabled
    return
  get_Driver3dPerspective() <| $(pers : Driver3dPerspective#)
    human_input__perspWk = pers.wk


[es(on_appear, REQUIRE=override_input)]
def reset_ct_on_input_override(evt : Event;
                               human_input__move : int;
                               var human_net_phys : HumanActor&)
  reset_digital_action_sticky_toggle(uint16(human_input__move))
  human_net_phys.phys.producedCT |> human_control_state_set_walk_dir(float2(0, 0))
  human_net_phys.phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType.HCT_SHOOT, false)
  human_net_phys.phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType.HCT_MELEE, false)


[es(tag=input, REQUIRE_NOT=(deadEntity, override_input))]
def human_input_es(info : UpdateStageUpdateInput;
                   eid : ecs::EntityId;
                   human_input__aim : int;
                   human_input__aimDelta : int;
                   human_input__look : int;
                   human_input__move : int;
                   human_input__sprint : int;
                   human_input__leanLeft : int;
                   human_input__leanRight : int;
                   human_input__aim1 : int;
                   human_input__aim2 : int;
                   human_input__zoom : int;
                   human_input__holdBreath : int;
                   isInVehicle : bool;
                   human_input__jump : int;
                   human_input__wishMelee : bool;
                   human_anim__vehicleSelected : EntityId;
                   human_anim__vehicleFollowDirCoef : float = 1.003;
                   human_input__lastWeaponChangeInput : float;
                   human_input__aimAngleOffset : float2&;
                   human_weap__throwMode : bool;
                   human_input__shoot : int = 0;
                   state_counter__disableMovementInAir : int;
                   human_net_phys__isInAir : bool;
                   human_net_phys__isSwimming : bool;
                   mainAttackIsMelee : bool = false;
                   human_input__gunToAimAngleLimit : float2;
                   human_input__gunToAimAngleCrawlLimit : float2;
                   human_weap__prevGunAngles : float2;
                   human_input__lookDirClamp : float2 = float2(90.f, 90.f);
                   human_input__vertLookAngleLimit : float2&;
                   human_input__perspWk : float;
                   human_input__aimingSensMult : float = 1.0f;
                   human_input__crawlingReject : bool = true;
                   human_input__resetSprintMovementThreshold : float = DEFAULT_RESET_SPRINT_MOVEMENT_THRESHOLD;
                   human_input__resetSprintMoveThreshold : float = DEFAULT_RESET_SPRINT_MOVE_THRESHOLD;
                   human_input__sprintMoveThreshold : float = 0.7;
                   human_input__crawlToAnyTransitionHeight : float = -0.9;
                   human_input__crawlToCrouchTransitionHeight : float = -0.4;
                   human__sneakSpeed : float = 0.5;
                   isTpsView : bool = false;
                   var human_net_phys__prevRootDir : float3&;
                   var human_net_phys__prevVertDir : float3&;
                   var human_input__hasValidState : bool&;
                   var human_input__standState : int&;
                   var human_input__aimAngle : float2&;
                   var human_input__oldAimAngle : float2&;
                   var human_input__lastShootInput : float&;
                   var human_net_phys : HumanActor&;
                   var human_input__vertLookAngleLimitChanged : bool&;
                   var human_input__lookAngle : float2&;
                   var human__sneaking : bool&;
                   var human_input__lastVehicleAngle : float&;
                   var human_input__lastVehicleAngleDelta : float&)
  assume phys = human_net_phys.phys
  var vehicleInputAim : int const? = null
  if isInVehicle
    query(human_anim__vehicleSelected) <| $ [es] (vehicle_input__aim : int const?;
                                                  transform : float3x4)
      vehicleInputAim = vehicle_input__aim

      human_input__lastVehicleAngleDelta = 0.0
      let vehicleAngle = dir_to_angles(transform[0])
      if !isTpsView
        human_input__lastVehicleAngleDelta = angle_diff(human_input__lastVehicleAngle, vehicleAngle.x)
        human_input__lastVehicleAngleDelta *= human_anim__vehicleFollowDirCoef
        human_input__aimAngle.x = norm_s_ang(human_input__aimAngle.x + human_input__lastVehicleAngleDelta)
      human_input__lastVehicleAngle = vehicleAngle.x

  human_input__oldAimAngle = human_input__aimAngle

  let sensMult = calc_sens_mult(human_net_phys, human_input__aimingSensMult, isInVehicle)

  if !human_input__hasValidState
    fix_changed_hero_input(human_net_phys)
    update_movement_directions(human_input__aim,
                              human_input__aimDelta,
                              human_input__look,
                              human_input__move,
                              human_input__sprint,
                              human_input__perspWk,
                              human_input__aimAngleOffset,
                              human_input__gunToAimAngleLimit,
                              human_input__gunToAimAngleCrawlLimit,
                              human_weap__prevGunAngles,
                              vehicleInputAim,
                              human__sneaking,
                              human__sneakSpeed,
                              sensMult,
                              deg_to_rad(human_input__vertLookAngleLimit),
                              true, // need_update_look_dir
                              true, // need_update_walk_dir
                              human_input__lookDirClamp / 180.f,
                              human_input__resetSprintMovementThreshold,
                              human_input__resetSprintMoveThreshold,
                              human_net_phys__prevRootDir,
                              human_net_phys__prevVertDir,
                              human_net_phys,
                              human_input__aimAngle,
                              human_input__oldAimAngle,
                              human_input__lookAngle)
    human_input__hasValidState = true

  var shouldUpdateWalkDir = is_action_active(uint16(human_input__move))

  var crawl = (human_input__standState == int(HumanPhysControlType.HCT_CRAWL))
  var crouch = (human_input__standState == int(HumanPhysControlType.HCT_CROUCH))

  // Min height of a soldier at which allow him to move when changing states to aim.
  let crawlToAnyTransitionHeight = human_input__crawlToAnyTransitionHeight
  let crawlToCrouchTransitionHeight = human_input__crawlToCrouchTransitionHeight

  // Reset move when transferring to/from crawl in aim mode while we move
  // Why: To prevent the sight of the weapon from getting under the ground.
  let isCrawlHeight = phys.currentState.height <= crawlToAnyTransitionHeight
  let isBelowCrawlToCrouchHeight = phys.currentState.height <= crawlToCrouchTransitionHeight
  let transitionFromCrawlToCrouch = (crouch && isBelowCrawlToCrouchHeight)
  if ((human_input__crawlingReject &&
      is_action_active(uint16(human_input__move)) &&
      (isCrawlHeight || transitionFromCrawlToCrouch || crawl)) ||
     (has_state_by_counter(state_counter__disableMovementInAir) && human_net_phys__isInAir))
    shouldUpdateWalkDir = false
    reset_digital_action_sticky_toggle(uint16(human_input__move))
    phys.producedCT |> human_control_state_set_walk_dir(float2(0, 0))

  let shouldUpdateLookDir = (is_action_active(uint16(human_input__aim)) ||
                            is_action_active(uint16(human_input__aimDelta)) ||
                            is_action_active(uint16(human_input__look)) ||
                            human_input__vertLookAngleLimitChanged)
  human_input__vertLookAngleLimitChanged = false

  update_movement_directions(human_input__aim,
                             human_input__aimDelta,
                             human_input__look,
                             human_input__move,
                             human_input__sprint,
                             human_input__perspWk,
                             human_input__aimAngleOffset,
                             human_input__gunToAimAngleLimit,
                             human_input__gunToAimAngleCrawlLimit,
                             human_weap__prevGunAngles,
                             vehicleInputAim,
                             human__sneaking,
                             human__sneakSpeed,
                             sensMult,
                             deg_to_rad(human_input__vertLookAngleLimit),
                             shouldUpdateLookDir,
                             shouldUpdateWalkDir,
                             human_input__lookDirClamp / 180.f,
                             human_input__resetSprintMovementThreshold,
                             human_input__resetSprintMoveThreshold,
                             human_net_phys__prevRootDir,
                             human_net_phys__prevVertDir,
                             human_net_phys, human_input__aimAngle, human_input__oldAimAngle,
                             human_input__lookAngle)

  if !mainAttackIsMelee && is_action_active(uint16(human_input__shoot))
    // We block shooting right after we drop a weapon, so we'll not shoot with our 'not dropped weapon' on the client, while we
    // still wait for server reply.
    let isShootBlocked = info.curTime - human_input__lastWeaponChangeInput < get_interp_delay_time(human_net_phys)
    let shoot = get_digital_action_state(uint16(human_input__shoot)).bState || is_button_pressed(uint16(human_input__shoot)) || phys.producedCT.haveUnenqueuedHctShoot
    let shootFlag = (shoot && !isShootBlocked)
    if shootFlag != phys.producedCT.lastEnqueuedHctShoot
      phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType.HCT_SHOOT, shootFlag)
    if shootFlag
      human_input__lastShootInput = info.curTime
      // Reset sprinting when started shooting
      reset_digital_action_sticky_toggle(uint16(human_input__sprint))
      phys.producedCT.haveUnenqueuedHctShoot = true

  let aim1 = (is_action_active(uint16(human_input__aim1))
             ? (get_digital_action_state(uint16(human_input__aim1)).bState || is_button_pressed(uint16(human_input__aim1)))
             : false)
  let aim2 = (is_action_active(uint16(human_input__aim2))
             ? get_digital_action_state(uint16(human_input__aim2)).bState
             : false)
  var aim = aim1 || aim2

  let isSprintAction = (get_digital_action_state(uint16(human_input__sprint)).bState || is_button_pressed(uint16(human_input__sprint)))
  let isSprintingMove = (get_analog_stick_action_state(uint16(human_input__move)).y > human_input__sprintMoveThreshold ||
                         get_stick_value(uint16(human_input__move)).y > human_input__sprintMoveThreshold)
  let isSprinting = (is_action_active(uint16(human_input__move)) &&
                     is_action_active(uint16(human_input__sprint)) &&
                     isSprintingMove && isSprintAction)
  var sprint = isSprinting && !aim2

  let isQuickLadder = (phys.currentState.isAttachedToLadder &&
                      is_action_active(uint16(human_input__move)) &&
                      is_action_active(uint16(human_input__sprint)) &&
                      (abs(get_analog_stick_action_state(uint16(human_input__move)).y) > 0f ||
                      abs(get_stick_value(uint16(human_input__move)).y) > 0f) &&
                      isSprintAction)

  // Reset sprinting when aiming
  if aim && phys.producedCT |> is_control_bit_set(HumanPhysControlType.HCT_SPRINT)
    reset_digital_action_sticky_toggle(uint16(human_input__sprint))

  // Reset aiming when transferring to sprint
  if sprint && phys.producedCT |> is_control_bit_set(HumanPhysControlType.HCT_AIM)
    reset_digital_action_sticky_toggle(uint16(human_input__aim1))
    reset_digital_action_sticky_toggle(uint16(human_input__aim2))

  if human_weap__throwMode
    aim = false

  // Reset sprinting when we want to crouch/crawl
  if (crawl || crouch) && phys.producedCT |> is_control_bit_set(HumanPhysControlType.HCT_SPRINT)
    reset_digital_action_sticky_toggle(uint16(human_input__sprint))
    sprint = false

  if sprint
    human__sneaking = false
    if !aim
      human_input__standState = 0
      crawl = false
      crouch = false
    reset_digital_action_sticky_toggle(uint16(human_input__aim1))

  if sprint && !(crouch || crawl)
    aim = false
    reset_digital_action_sticky_toggle(uint16(human_input__holdBreath))

  phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType.HCT_AIM, aim)
  phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType.HCT_CRAWL, crawl)
  phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType.HCT_CROUCH, crouch)

  human_net_phys |> set_ct_controlbit(HumanPhysControlType.HCT_JUMP, uint16(human_input__jump))

  phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType.HCT_MELEE, human_input__wishMelee)

  // Clear melee, but apply it if we press shoot
  if mainAttackIsMelee && is_action_active(uint16(human_input__shoot))
    let value = get_digital_action_state(uint16(human_input__shoot)).bState || is_button_pressed(uint16(human_input__shoot))
    phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType.HCT_MELEE, value)

  if aim
    human_net_phys |> set_ct_controlbit(HumanPhysControlType.HCT_SPRINT, uint16(human_input__holdBreath))
  else
    phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType.HCT_SPRINT, isSprinting || isQuickLadder)
    reset_digital_action_sticky_toggle(uint16(human_input__zoom))

  human_net_phys |> set_ct_controlbit(HumanPhysControlType.HCT_ZOOM_VIEW, uint16(human_input__zoom))

  if !aim && (does_action_block_sprint(eid) || phys.producedCT |> is_control_bit_set(HumanPhysControlType.HCT_MELEE))
    phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType.HCT_SPRINT, false)

  if phys.currentState |> human_phys_state_stoppedSprint()
    reset_digital_action_sticky_toggle(uint16(human_input__sprint))

  let leanLeft = (is_action_active(uint16(human_input__leanLeft))
            ? get_digital_action_state(uint16(human_input__leanLeft)).bState
            : false)

  let leanRight = (is_action_active(uint16(human_input__leanRight))
          ? get_digital_action_state(uint16(human_input__leanRight)).bState
          : false)

  let curLean = phys.currentState.leanPosition

  if (sprint
      || phys.producedCT |> is_control_bit_set(HumanPhysControlType.HCT_JUMP)
      || isInVehicle
      || human_net_phys__isSwimming
      || human_net_phys__isInAir
      || crawl)
    reset_digital_action_sticky_toggle(uint16(human_input__leanLeft))
    reset_digital_action_sticky_toggle(uint16(human_input__leanRight))
    phys.producedCT |> human_control_state_set_lean_position(0.0)
  elif leanLeft && leanRight
    phys.producedCT |> human_control_state_set_lean_position(0.0)
    reset_digital_action_sticky_toggle(uint16(human_input__leanLeft))
    reset_digital_action_sticky_toggle(uint16(human_input__leanRight))
  elif curLean < 0.0 && leanRight
    phys.producedCT |> human_control_state_set_lean_position(1.0)
    reset_digital_action_sticky_toggle(uint16(human_input__leanLeft))
  elif curLean > 0.0 && leanLeft
    phys.producedCT |> human_control_state_set_lean_position(-1.0)
    reset_digital_action_sticky_toggle(uint16(human_input__leanRight))
  else
    let leanDir = leanLeft && leanRight ? 0.0 : leanLeft ? -1.0 : leanRight ? 1.0 : 0.0
    phys.producedCT |> human_control_state_set_lean_position(leanDir)


[es(tag=input, on_disappear, REQUIRE=locked_weapon__aim)]
def locked_weapon_aim_input_disappear(evt : Event;
                                      game_effect__attachedTo : EntityId)
  query(game_effect__attachedTo) <| $ [es(REQUIRE=hero)] (human_input__aim1 : int;
                                                          human_input__aim2 : int)
    reset_digital_action_sticky_toggle(uint16(human_input__aim1))
    reset_digital_action_sticky_toggle(uint16(human_input__aim2))


[es(tag=input, on_appear, on_event=EventOnEntityReset)]
def human_input_entity_reset_es(evt : Event;
                                transform : float3x4&;
                                human_input__perspWk : float;
                                human_input__defaultVertLookAngleLimit : float2;
                                human_input__gunToAimAngleLimit : float2;
                                human_input__gunToAimAngleCrawlLimit : float2;
                                var human_weap__prevGunAngles : float2&;
                                var human_net_phys__prevRootDir : float3&;
                                var human_net_phys__prevVertDir : float3&;
                                var human_net_phys : HumanActor&;
                                var human_input__aimAngle : float2&;
                                var human_input__oldAimAngle : float2&)
  human_input__aimAngle = dir_to_angles(transform[0])
  human_weap__prevGunAngles = human_input__aimAngle

  update_look_dir(human_net_phys,
                  human_input__aimAngle,
                  human_input__oldAimAngle,
                  human_net_phys__prevRootDir,
                  human_net_phys__prevVertDir,
                  float2(0, 0),
                  deg_to_rad(human_input__defaultVertLookAngleLimit),
                  human_input__gunToAimAngleLimit,
                  human_input__gunToAimAngleCrawlLimit,
                  human_weap__prevGunAngles,
                  human_input__perspWk)
  update_walk_dir(human_net_phys)


[es(tag=input)]
def human_input_entity_teleported_es(evt : EventOnEntityTeleported;
                                     human_input__defaultVertLookAngleLimit : float2;
                                     human_input__perspWk : float;
                                     human_input__gunToAimAngleLimit : float2;
                                     human_input__gunToAimAngleCrawlLimit : float2;
                                     var human_weap__prevGunAngles : float2&;
                                     var human_net_phys__prevRootDir : float3&;
                                     var human_net_phys__prevVertDir : float3&;
                                     var human_net_phys : HumanActor&;
                                     var human_input__aimAngle : float2&;
                                     var human_input__oldAimAngle : float2&)
  human_net_phys__prevVertDir = evt.newtm[1]
  human_net_phys.phys.currentState.vertDirection = evt.newtm[1]
  human_net_phys__prevRootDir = evt.newtm[0]
  human_input__aimAngle = float2()
  let rawAngleDir = basis_aware_angles_to_dir(human_input__aimAngle, human_net_phys__prevVertDir, human_net_phys__prevRootDir)
  human_weap__prevGunAngles = dir_to_angles(rawAngleDir)

  update_look_dir(human_net_phys,
                  human_input__aimAngle,
                  human_input__oldAimAngle,
                  human_net_phys__prevRootDir,
                  human_net_phys__prevVertDir,
                  float2(0, 0),
                  deg_to_rad(human_input__defaultVertLookAngleLimit),
                  human_input__gunToAimAngleLimit,
                  human_input__gunToAimAngleCrawlLimit,
                  human_weap__prevGunAngles,
                  human_input__perspWk)
  update_walk_dir(human_net_phys)
