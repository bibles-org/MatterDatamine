require ecs
require app
require DagorMath
require math
require math.base
require math.easing
require game.events.events
require game.utils.hero
require game.events.events_game
require DngDm
require HumanPhys
require DngHuman
require DaWeapons
require DagorRandom
require game.es.render.camera_shaker_common
require game.events.events_active_matter


def calc_trauma(trauma, addTrauma, maxTrauma)
  return trauma >= maxTrauma ? trauma : clamp(min(trauma + addTrauma, maxTrauma), 0.f, 1.f)

[es(tag=gameClient)]
def camera_shaker_perlin_add_trauma(evt : CmdAddCameraTrauma;
                                    camera__active : bool;
                                    var camera_shaker__trauma : float&)
  if camera__active
    camera_shaker__trauma = calc_trauma(camera_shaker__trauma, evt.addTrauma, evt.maxTrauma)

[es(tag=gameClient)]
def camera_shaker_perlin_add_trauma_by_distance(evt : CmdAddCameraTraumaByDistance;
                                                transform : float3x4;
                                                camera__active : bool;
                                                var camera_shaker__trauma : float&)
  if camera__active
    let distanceSq = length_sq(evt.position - transform[3])
    let maxDistSq = square(evt.maxDistance)
    let maxTrauma = cvt(maxDistSq - distanceSq, 0.f, maxDistSq, 0.f, evt.maxTrauma)
    camera_shaker__trauma = calc_trauma(camera_shaker__trauma, evt.addTrauma, maxTrauma)

[es(tag=gameClient)]
def camera_shaker_perlin_punch(evt : CmdCameraPunch;
                               camera__active : bool;
                               var camera_shaker__punch : float&;
                               var camera_shaker__punchAngles : float3&)
  if camera__active && camera_shaker__punch <= 0.05f
    camera_shaker__punch = 1.f
    camera_shaker__punchAngles = evt.angles * DEG_TO_RAD

[es(tag=gameClient)]
def camera_shaker_perlin_add_unbounded_trauma(evt : CmdAddUnboundedCameraTrauma;
                                              camera__active : bool;
                                              var camera_shaker__trauma : float&)
  if camera__active
    camera_shaker__trauma += evt.addTrauma


[es(tag=gameClient)]
def camera_shaker_perlin_add_server_cmd_trauma(evt : CmdCauseTrauma; bindedCamera : EntityId)
  query(bindedCamera) <| $ [es] (var camera_shaker__trauma : float&)
    camera_shaker__trauma = max(min(evt.maxTrauma, camera_shaker__trauma + evt.addTrauma), camera_shaker__trauma)


[es(tag=gameClient)]
def camera_shaker_perlin_punch_by_dir(evt : CmdCameraPunchByDir;
                                      camera__active : bool;
                                      camera_shaker__punchByDirMaxAngles : float3;
                                      camera_shaker__punchMaxPower : float;
                                      camera_shaker__punchDirLength : float;
                                      var camera_shaker__punch : float&;
                                      var camera_shaker__punchAngles : float3&)
  if !camera__active
    return

  let dir = evt.localDir
  let power = cvt(length(evt.localDir), 0.f, camera_shaker__punchDirLength, 0.f, camera_shaker__punchMaxPower)

  let maxPitch = camera_shaker__punchByDirMaxAngles.x * power
  let maxYaw = camera_shaker__punchByDirMaxAngles.y * power
  let maxRoll = camera_shaker__punchByDirMaxAngles.z * power

  let roll = cvt(dir.y, -1.f, 1.f, -maxRoll, maxRoll)
  let resPunchAngles = (abs(dir.x) >= abs(dir.z) ? float3(-sign(dir.x) * maxPitch, 0.f, -sign(dir.z) * roll) : float3(0.f, sign(dir.z) * maxYaw, sign(dir.z) * roll)) * DEG_TO_RAD
  camera_shaker__punchAngles = camera_shaker__punchAngles * camera_shaker__punch + resPunchAngles

  camera_shaker__punch = 1.f

[es(tag=gameClient, after=shooter_cam_update_tm_es, before=after_camera_sync)]
def camera_shaker_perlin_update_es(info : UpdateStageInfoAct;
                                   camera_shaker__maxShake : float3;
                                   camera_shaker__traumaFadeoutSpeed : float;
                                   camera_shaker__shakePower : float;
                                   camera_shaker__punchSpeed : float;
                                   camera_shaker__punchAngles : float3;
                                   camera_shaker__extraShakeAngles : float3;
                                   var camera_shaker__punch : float&;
                                   var camera_shaker__shake : float&;
                                   var camera_shaker__trauma : float&;
                                   var camera_shaker__totalTime : float&;
                                   var transform : float3x4)
  camera_shaker__shake = clamp(square(camera_shaker__trauma), 0f, 1f)

  let shake = camera_shaker__shake
  let maxShake = camera_shaker__maxShake * DEG_TO_RAD
  var shakerAngles = float3(maxShake.x * shake * perlin_noise1(camera_shaker__totalTime),
                            maxShake.y * shake * perlin_noise1(camera_shaker__totalTime + 1000.f),
                            maxShake.z * shake * perlin_noise1(camera_shaker__totalTime + 2000.f))

  camera_shaker__trauma = max(camera_shaker__trauma - camera_shaker__traumaFadeoutSpeed * info.dt, 0.f)
  camera_shaker__totalTime += camera_shaker__shakePower * info.dt
  if camera_shaker__totalTime > 1e5
    camera_shaker__totalTime = 0.f

  shakerAngles += smoothStopArch3(1.f - camera_shaker__punch) * camera_shaker__punchAngles
  camera_shaker__punch = clamp(camera_shaker__punch - camera_shaker__punchSpeed * info.dt, 0.f, 1.f)

  shakerAngles += camera_shaker__extraShakeAngles

  var shakerTm : float3x4

  rotxTM(shakerAngles.x, shakerTm)
  transform = transform * shakerTm

  rotyTM(shakerAngles.y, shakerTm)
  transform = transform * shakerTm

  rotzTM(shakerAngles.z, shakerTm)
  transform = transform * shakerTm


def calculate_extra_shake_angles(dt : float;
                                 velocity : float3;
                                 shake_power_add : float;
                                 shake_power_mult : float;
                                 swing_max_pitch : float;
                                 swing_max_yaw : float;
                                 swing_max_roll : float;
                                 swing_omega : float3;
                                 swing_min_velocity : float;
                                 swing_max_velocity : float;
                                 swing_tau : float;
                                 var extraShakeAngles : float3&;
                                 var swing_time : float&;
                                 var swing_amplitude : float&)
  var wishAmplitude = cvt(length_sq(velocity), square(swing_min_velocity), square(swing_max_velocity), 0.f, 1.f)
  wishAmplitude = wishAmplitude * shake_power_mult + shake_power_add
  swing_amplitude = approach(swing_amplitude, wishAmplitude, dt, swing_tau)

  if swing_amplitude <= 1.e-2f
    swing_time = 0.f
    extraShakeAngles = float3(0.f, 0.f, 0.f)
    return

  let maxSwingPitch = swing_max_pitch * DEG_TO_RAD
  let maxSwingYaw = swing_max_yaw * DEG_TO_RAD
  let maxSwingRoll = swing_max_roll * DEG_TO_RAD
  extraShakeAngles.x = swing_amplitude * maxSwingPitch * sin(swing_omega.x * swing_time)
  extraShakeAngles.y = swing_amplitude * maxSwingYaw * sin(swing_omega.y * swing_time)
  extraShakeAngles.z = swing_amplitude * maxSwingRoll * sin(swing_omega.z * swing_time)

  swing_time += dt

[es(tag=gameClient, on_disappear, REQUIRE=hero)]
def camera_shaker_perlin_reset_extra_shake_on_disappear(evt : Event; bindedCamera : EntityId)
  query(bindedCamera) <| $ [es] (var camera_shaker__extraShakeAngles : float3&)
    camera_shaker__extraShakeAngles = float3(0.0f)

// temp disabled with cameraShakerEnabled tag.
// unless synced with walk\run\sprint animation this shake does not feel good
[es(tag=gameClient, REQUIRE=(hero, cameraShakerEnabled), before=camera_shaker_perlin_update_es)]
def camera_shaker_perlin_swing(info : UpdateStageInfoAct;
                               bindedCamera : EntityId;
                               human_net_phys : HumanActor;
                               human_net_phys__curMoveState : int;
                               camera_shake__sprintSwingMaxPitch : float;
                               camera_shake__sprintSwingMaxYaw : float;
                               camera_shake__sprintSwingMaxRoll : float;
                               camera_shake__sprintSwingOmega : float3;
                               camera_shake__sprintSwingMinVelocity : float;
                               camera_shake__sprintSwingMaxVelocity : float;
                               camera_shake__sprintSwingTau : float;
                               camera_shake__walkSwingMaxPitch : float;
                               camera_shake__walkSwingMaxYaw : float;
                               camera_shake__walkSwingMaxRoll : float;
                               camera_shake__walkSwingOmega : float3;
                               camera_shake__walkSwingMinVelocity : float;
                               camera_shake__walkSwingMaxVelocity : float;
                               camera_shake__walkSwingTau : float;
                               var camera_shake__swingTime : float&;
                               var camera_shake__swingAmplitude : float&)
  query(bindedCamera) <| $ [es] (camera__active : bool;
                                 camera_settings__shakePowerMult : float;
                                 camera_settings__shakePowerAdd : float;
                                 var camera_shaker__extraShakeAngles : float3&)
    if !camera__active
      camera_shake__swingTime = 0.f
      camera_shaker__extraShakeAngles = float3(0.0)
      return

    let velocity = human_net_phys.phys.currentState.velocity
    let isInSprint = human_net_phys__curMoveState == int(HUMoveState.EMS_SPRINT)
    let isInWalk = human_net_phys__curMoveState == int(HUMoveState.EMS_WALK)
    let isInRun = human_net_phys__curMoveState == int(HUMoveState.EMS_RUN)

    if isInSprint
      calculate_extra_shake_angles(info.dt,
                                   velocity,
                                   camera_settings__shakePowerAdd,
                                   camera_settings__shakePowerMult,
                                   camera_shake__sprintSwingMaxPitch,
                                   camera_shake__sprintSwingMaxYaw,
                                   camera_shake__sprintSwingMaxRoll,
                                   camera_shake__sprintSwingOmega,
                                   camera_shake__sprintSwingMinVelocity,
                                   camera_shake__sprintSwingMaxVelocity,
                                   camera_shake__sprintSwingTau,
                                   camera_shaker__extraShakeAngles,
                                   camera_shake__swingTime,
                                   camera_shake__swingAmplitude)

    elif isInWalk || isInRun
      calculate_extra_shake_angles(info.dt,
                                   velocity,
                                   camera_settings__shakePowerAdd,
                                   camera_settings__shakePowerMult,
                                   camera_shake__walkSwingMaxPitch,
                                   camera_shake__walkSwingMaxYaw,
                                   camera_shake__walkSwingMaxRoll,
                                   camera_shake__walkSwingOmega,
                                   camera_shake__walkSwingMinVelocity,
                                   camera_shake__walkSwingMaxVelocity,
                                   camera_shake__walkSwingTau,
                                   camera_shaker__extraShakeAngles,
                                   camera_shake__swingTime,
                                   camera_shake__swingAmplitude)

[es(tag=gameClient, REQUIRE=hero)]
def camera_shaker_perlin_on_collision(evt : CmdCollisionDamage;
                                      hitpoints__maxHp : float;
                                      camera_shake__collisionDamageHpFactor : float;
                                      camera_shake__collisionDamageMaxTrauma : float)
  let trauma = cvt(evt.damage, 0.f, camera_shake__collisionDamageHpFactor * hitpoints__maxHp, 0.f, camera_shake__collisionDamageMaxTrauma)
  add_trauma(trauma, camera_shake__collisionDamageMaxTrauma)

[es(tag=gameClient, REQUIRE=hero)]
def camera_shaker_perlin_on_jump(evt : CmdPostPhysUpdate;
                                 human_net_phys : HumanActor;
                                 camera_shake__jumpMaxPunch : float;
                                 camera_shake__jumpMinSpeed : float;
                                 camera_shake__jumpMaxSpeed : float)
  let spdSummaryDiffY = human_net_phys.phys.currentState.spdSummaryDiff.y
  if spdSummaryDiffY >= camera_shake__jumpMinSpeed
    let pitchPunch = cvt(spdSummaryDiffY, camera_shake__jumpMinSpeed, camera_shake__jumpMaxSpeed, 0.f, -camera_shake__jumpMaxPunch)
    query() <| $ [es] (camera__active : bool;
                       camera_settings__shakePowerMult : float)
      if camera__active
        add_punch(float3(pitchPunch * camera_settings__shakePowerMult, 0.f, 0.f))

[es(tag=gameClient)]
def camera_shaker_perlin_vehicle_earth_tremor_es(evt : EventVehicleEarthTremor;
                                                 camera__target : EntityId;
                                                 camera_shaker__vehicleMaxDistance : float;
                                                 camera_shaker__vehicleMassMod : float;
                                                 camera_shaker__vehicleSpeedMod : float;
                                                 camera_shaker__vehicleMaxTrauma : float;
                                                 bindToVehicle : bool = false;
                                                 camera__active : bool)
  if !camera__active || bindToVehicle || get_bool(camera__target, "isInVehicle") ?? false
    return
  let massShake = evt.mass * camera_shaker__vehicleMassMod
  let speedShake = evt.speed * camera_shaker__vehicleSpeedMod
  add_trauma(massShake + speedShake, camera_shaker__vehicleMaxTrauma, evt.position, camera_shaker__vehicleMaxDistance)

[es(tag=gameClient)]
def camera_shaker_perlin_projectile_hit_es(evt : ProjectileHitShake;
                                           camera_shaker__projectileMaxDistance : float;
                                           camera_shaker__projectileHitDamageMod : float)
  let trauma = evt.damage * camera_shaker__projectileHitDamageMod
  add_trauma(trauma, 1.f, evt.position, camera_shaker__projectileMaxDistance)

[es(tag=gameClient, REQUIRE=msg_sink)]
def camera_shaker_perlin_shell_explosion_es(evt : EventShellExplosionShockWave)
  query() <| $ [es] (transform : float3x4;
                     camera__active : bool;
                     camera_shaker__waveMinPower : float;
                     camera_shaker__waveMaxPower : float;
                     camera_shaker__waveRadiusMod : float;
                     camera_shaker__waveDamageMod : float;
                     camera__target : EntityId)
    if !camera__active
      return
    let explosionPos = evt.position
    let damageRadius = evt.dmg_radius
    let damageHp = evt.dmg_hp
    let blastWaveRadius = damageRadius * camera_shaker__waveRadiusMod
    let hitDir = transform[3] - explosionPos
    let distance = length(hitDir)
    let hitDirNormalized = hitDir * safeinv(distance)
    if distance < blastWaveRadius
      let waveWeakening = cvt(distance, 0.f, blastWaveRadius, 0.f, camera_shaker__waveMaxPower - camera_shaker__waveMinPower)
      var shakePower = (camera_shaker__waveMaxPower - waveWeakening) * damageHp * camera_shaker__waveDamageMod
      query(camera__target) <| $ [es] (entity_mods__shakePowerMult : float)
        shakePower *= entity_mods__shakePowerMult
      add_trauma(shakePower)
      add_punch_by_dir(shakePower * rotate(inverse(transform), hitDirNormalized))

[es(tag=gameClient)]
def camera_shaker_perlin_projectile_fly_es(evt : ProjectileFlyShockWave;
                                           transform : float3x4&;
                                           camera__active : bool;
                                           camera_shaker__projectilePowerMod : float;
                                           camera_shaker__projectileMaxDistance : float;
                                           camera_shaker__projectileMinCaliber : float;
                                           camera_shaker__projectileFlyMaxTrauma : float)
  let caliber = evt.caliber
  if !camera__active || caliber < camera_shaker__projectileMinCaliber
    return

  let pos = evt.position
  let prevPos = evt.prev_position
  let dir = normalize(pos - prevPos)
  let closestPointOnDir = pos + dir * dot(transform[3] - pos, dir)
  let distanceSq = length_sq(transform[3] - closestPointOnDir)
  if distanceSq < square(camera_shaker__projectileMaxDistance) && dot(prevPos - closestPointOnDir, dir) <= 0.f && dot(pos - closestPointOnDir, dir) > 0.f
    let maxPower = caliber * camera_shaker__projectilePowerMod
    let shakePower = maxPower - cvt(distanceSq, 0.f, square(camera_shaker__projectileMaxDistance), 0.f, maxPower)
    add_trauma(shakePower, camera_shaker__projectileFlyMaxTrauma, evt.position, camera_shaker__projectileMaxDistance)

[es(tag=gameClient)]
def cmd_camera_shaker_perlin_es(evt : CmdShakeCamera; camera__active : bool)
  if camera__active
    add_trauma(evt.wish_shake, 1.f, evt.position, evt.max_distance)

[es(tag=gameClient)]
def camera_shake_on_shot_receive_event(evt : CameraShakeOnShot;
                                       camera__active : bool;
                                       var camera_shaker__onShotExternalImpulse : float3&;
                                       var camera_shaker__onShotViscosity : float3&;
                                       var camera_shaker__onShotStiffness : float3&)
  if camera__active
    camera_shaker__onShotViscosity = evt.viscocity
    camera_shaker__onShotStiffness = evt.stiffness
    camera_shaker__onShotExternalImpulse = evt.impulse


def camera_shake_on_shot_iteration(var prevOffset : float3&; var offset : float3&; stiffness, viscosity, externalImpulse : float3; mass, dt : float)
  if mass > 0.
    let velocity = (offset - prevOffset) / dt
    let springForce = -stiffness * offset - viscosity * velocity
    let acceleration = springForce / mass
    let newOffset = 2.0f * offset - prevOffset + (acceleration * dt + externalImpulse / mass) * dt
    prevOffset = offset
    offset = newOffset
  offset = clamp(offset, float3(-15. * DEG_TO_RAD), float3(15. * DEG_TO_RAD))


[es(tag=gameClient, after=shooter_cam_update_tm_es, before=after_camera_sync)]
def camera_shake_on_shot_update(info : UpdateStageInfoAct;
                                camera_shaker__onShotViscosity : float3;
                                camera_shaker__onShotStiffness : float3;
                                camera_shaker__onShotMass : float;
                                var camera_shaker__onShotExternalImpulse : float3&;
                                var camera_shaker__onShotCameraOffset : float3&;
                                var camera_shaker__onShotCameraPrevOffset : float3&;
                                var transform : float3x4)
  assume stiffness = camera_shaker__onShotStiffness
  assume viscocity = camera_shaker__onShotViscosity
  assume mass = camera_shaker__onShotMass

  let FIXED_DT = 1.0 / 120.0
  let MAX_STEPS = 10
  let impulse = camera_shaker__onShotExternalImpulse
  let numSteps = min(floori(info.dt / FIXED_DT), MAX_STEPS)
  let residualTime = numSteps == MAX_STEPS ? 0.0 : info.dt - float(numSteps) * FIXED_DT

  var prevOffset = camera_shaker__onShotCameraPrevOffset
  var offset = camera_shaker__onShotCameraOffset

  // If there's several iterations of physics, apply external force only to the first iteration
  if numSteps > 0
    camera_shake_on_shot_iteration(prevOffset, offset, stiffness, viscocity, impulse * FIXED_DT, mass, FIXED_DT)
    camera_shaker__onShotExternalImpulse = float3(0)
  for _ in range(numSteps - 1)
    camera_shake_on_shot_iteration(prevOffset, offset, stiffness, viscocity, float3(0), mass, FIXED_DT)
  if residualTime > 1e-5f
    camera_shake_on_shot_iteration(prevOffset, offset, stiffness, viscocity, impulse * residualTime, mass, residualTime)
    camera_shaker__onShotExternalImpulse = float3(0)

  camera_shaker__onShotCameraPrevOffset = prevOffset
  camera_shaker__onShotCameraOffset = offset

  var q : quat
  // Signs and swizzle make sure camera rotates around correct axis by right-hand rule
  euler_to_quat(-offset.y, offset.z, -offset.x, q)
  var shakerTm : float3x4
  make_tm(q, float3(0.0f, 0.0f, 0.0f), shakerTm)
  transform = transform * shakerTm


[es(tag=gameClient, after=after_guns_update_sync, before=clear_gun_launch_events_es)]
def camera_shake_on_shot(info : ParallelUpdateFrameDelayed;
                         gun__owner : EntityId;
                         gun_launch_events : GunLaunchEvents;
                         gun__cameraShakeOnShotStrength : float3;
                         gun__cameraShakeOnShotViscocity : float3;
                         gun__cameraShakeOnShotStiffness : float3)
  if length(gun_launch_events.launchEvents) > 0
    query(gun__owner) <| $ [es(REQUIRE=hero)] (human_input__aimOffset : float2;
                                               human_weap__recoilEnabled : bool = true)
      assume recoilMultiplier = 100.0
      assume strength = human_weap__recoilEnabled ? gun__cameraShakeOnShotStrength : float3()
      assume aimOffset = human_input__aimOffset
      let impulse = float3(-aimOffset.y * strength.x * recoilMultiplier, -aimOffset.x * strength.y * recoilMultiplier, gauss_rnd(0) * strength.z)

      broadcastEvent(CameraShakeOnShot(impulse = impulse,
                                         viscocity = gun__cameraShakeOnShotViscocity,
                                         stiffness = gun__cameraShakeOnShotStiffness,
                                         dt = info.dt))

[es(tag=gameClient, REQUIRE=hero)]
def camara_shake_perlin_punch_on_hit(evt : EventOnEntityHit; isAlive : bool; transform : float3x4;
                                     human_damage_model__dmgMult : float = 1.0;
                                     observed__punchesMinInterval : float = 0.225;
                                     observed__punchesRepeatMult : float = 0.0; // repeat punches disabled
                                     var observed__lastPunchTime : float&)
  let acceptDamageType = (evt.damageType == int(DamageType.DM_MELEE) ||
                          evt.damageType == int(DamageType.DM_BACKSTAB) ||
                          evt.damageType == int(DamageType.DM_PROJECTILE) ||
                          evt.damageType == int(DamageType.DM_COLLISION))
  if has(evt.victim, "hero") && acceptDamageType && isAlive
    let curTime = get_sync_time()
    var mult = 1.0
    if curTime - observed__lastPunchTime > observed__punchesMinInterval
      observed__lastPunchTime = curTime
    else
      mult = observed__punchesRepeatMult

    add_punch_by_dir(safediv(evt.deltaHp, human_damage_model__dmgMult) * mult * rotate(inverse(transform), evt.hitDir))

[es(tag=gameClient)]
def camera_shake_perlin_break_window(evt : EventRiExtraDestroyed; isDoor : bool)
  if isDoor
    return
  ecs::query(evt.offenderEid) <| $ [es(REQUIRE=watchedByPlr)] (camera_shake__breakWindowTrauma : float)
    add_trauma(camera_shake__breakWindowTrauma)


[es(tag=gameClient, REQUIRE=hero)]
def camera_shaker_perlin_on_melee_dmg(evt : EventOnEntityHit; eid : EntityId)
  if eid == evt.victim && evt.damageType == int(DamageType.DM_MELEE)
    query(evt.offender) <| $ [es] (melee_hit_camera_punch__punchForce : float;
                                   customizable_melee_attack__attackDirection : float2 const?)
      let angles = (customizable_melee_attack__attackDirection != null ?
          float3((*customizable_melee_attack__attackDirection).x, 0.0, (*customizable_melee_attack__attackDirection).y)
        : float3(rnd_float(-1.0, 1.0), rnd_float(-1.0, 1.0), rnd_float(-1.0, 1.0)))
      add_punch(angles * melee_hit_camera_punch__punchForce)
