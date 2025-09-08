require ecs
require app
require game.events.events
require HumanPhys
require DngHuman
require DagorMath
require GamePhys
require DagorMathUtils
require math.base
require math.shooter_phys_common
require game.es.ecs_common
require game.es.grav_zones_common


def monster_pre_flight(phys;
                       var cur_state;
                       grav : float3;
                       dt;
                       blk : block<(prev_ccd_pos : float3; prev_vel : float3) : void>)
  human_phys_state_set_useSecondaryCcd(cur_state, false)

  // revert to prev pos
  let prevVelocity : float3 = cur_state.velocity
  let deltaPos = cur_state.velocity * dt
  cur_state.location.P = cur_state.location.P - DPoint3(deltaPos)

  var tm : float3x4
  location_toTM(cur_state.location, tm)
  let prevCcdPos = phys.ccdPos
  let prevWorldCcdPos = tm * prevCcdPos

  // antigrav
  cur_state.velocity -= gravity() * grav * dt

  invoke(blk, prevWorldCcdPos, prevVelocity)


def monster_post_flight(var phys;
                        cur_state;
                        prev_ccd_pos)
  var tm : float3x4
  location_toTM(cur_state.location, tm)
  let curCcdPos = phys.ccdPos
  let curWorldPos = tm * curCcdPos
  let offset = curWorldPos - prev_ccd_pos
  human_phys_processCcdOffset(phys, tm, curWorldPos, offset, phys.collRad - phys.ccdRad, 1.f, human_phys_state_useSecondaryCcd(cur_state), curCcdPos)


[es(before=net_phys_update_es)]
def monster_freeflight_update_stamina(act : UpdateStageInfoAct;
                                      monster_flight_mode__enabled : bool;
                                      monster_flight_mode__staminaFlightConsumption : float;
                                      monster_flight_mode__maxStamina : float;
                                      monster_flight_mode__staminaRegen : float;
                                      monster_flight_mode__sprintBrakeTime : float;
                                      monster_flight_mode__sprintBrakeKoef : float = 0.85;
                                      var human_net_phys : HumanActor;
                                      var monster_flight_mode__stamina : float&;
                                      var monster_flight_mode__isSprinting : bool&;
                                      var monster_flight_mode__sprintBrakeUntil : float&)
  if !monster_flight_mode__enabled
    return

  assume phys = human_net_phys.phys
  assume curState = phys.currentState
  assume ct = phys.appliedCT

  let staminaRequiredForSprint = monster_flight_mode__staminaFlightConsumption * act.dt
  let isSprintEnabled = monster_flight_mode__stamina < staminaRequiredForSprint

  let isSprintInput = is_control_bit_set(ct, HumanPhysControlType.HCT_SPRINT)
  monster_flight_mode__isSprinting = isSprintInput && !isSprintEnabled

  if monster_flight_mode__isSprinting
    monster_flight_mode__stamina -= staminaRequiredForSprint
  elif !isSprintInput
    monster_flight_mode__stamina = min(monster_flight_mode__stamina + monster_flight_mode__staminaRegen * act.dt, monster_flight_mode__maxStamina)
  elif monster_flight_mode__stamina > 0.0
    monster_flight_mode__stamina = 0.0
    monster_flight_mode__sprintBrakeUntil = act.curTime + monster_flight_mode__sprintBrakeTime
    curState.velocity = curState.velocity * float3(monster_flight_mode__sprintBrakeKoef)


[es(before=human_first_contact_dispatcher)]
def monster_freeflight_mode(evt : CmdPostPhysUpdate;
                            monster_flight_mode__accel : float;
                            monster_flight_mode__fricThresSpd : float;
                            monster_flight_mode__fric : float;
                            monster_flight_mode__speedDefault : float;
                            monster_flight_mode__speedSprint : float;
                            monster_flight_mode__enabled : bool;
                            monster_flight_mode__isSprinting : bool;
                            monster_flight_mode__isImmobilized : bool;
                            monster_flight_mode__forceVelocity : float3 = float3();
                            monster_flight_mode__forceVelocityEnabled : bool = false;
                            transform : float3x4;
                            var human_net_phys : HumanActor)
  if !monster_flight_mode__enabled
    return
  assume phys = human_net_phys.phys
  assume curState = phys.currentState
  let dt = evt.dt

  let grav = get_grav_dir(transform[3])

  monster_pre_flight(phys, curState, grav, dt) <| $(prev_ccd_pos : float3; prev_vel : float3)
    assume ct = phys.appliedCT

    let wishShootDir = ct.wishShootDir
    let wishQuat = dir_and_up_to_quat(wishShootDir, curState.vertDirection)

    let curWalkDirLS = float3(ct.walkDir.x, 0.0, ct.walkDir.y)
    let curWalkDirWS = wishQuat * curWalkDirLS

    let isMoving = phys.appliedCT.isMoving && !monster_flight_mode__isImmobilized
    let isCrouching = is_control_bit_set(ct, HumanPhysControlType.HCT_CROUCH)
    let isJumping = is_control_bit_set(ct, HumanPhysControlType.HCT_JUMP)

    let movingDir = isMoving ? curWalkDirWS : float3(0.0)
    let movingDirKoef = 0.5 // To give a vert flight more priority
    let vertFlightDir = isCrouching ? +grav : (isJumping ? -grav : float3(0.0))
    let wishLocalMoveDir = normalize(movingDir * movingDirKoef + vertFlightDir)
    let wishMoveDir = wishLocalMoveDir

    if monster_flight_mode__forceVelocityEnabled
      curState.velocity = monster_flight_mode__forceVelocity
    else
      var wishResSpd = 0.0
      if !monster_flight_mode__isImmobilized
        wishResSpd = monster_flight_mode__isSprinting ? monster_flight_mode__speedSprint : monster_flight_mode__speedDefault
      let accel = monster_flight_mode__accel

      curState.velocity = phys_apply_omni_friction(curState.velocity, monster_flight_mode__fricThresSpd, monster_flight_mode__fric, dt)
      curState.velocity = phys_accelerate_directional(curState.velocity, wishMoveDir, wishResSpd, accel * wishResSpd, dt)

    curState.acceleration = (curState.velocity - prev_vel) * safeinv(dt)

    var deltaFinalPos = curState.velocity * dt
    if human_phys_state_get_is_swimming(curState) && !human_phys_state_get_is_underwater(curState) && wishMoveDir.y > 0f
      deltaFinalPos.y = max(deltaFinalPos.y, phys.swimmingLevelBias)
    curState.location.P = curState.location.P + DPoint3(deltaFinalPos)

    monster_post_flight(phys, curState, prev_ccd_pos)


[es(track=monster_flight_mode__enabled)]
def monster_unset_flight_mode(evt : Event;
                              monster_flight_mode__enabled : bool;
                              var human_net_phys : HumanActor)
  if !monster_flight_mode__enabled
    human_phys_state_set_useSecondaryCcd(human_net_phys.phys.currentState, true)