require ecs
require DngHuman
require math.base
require DngWeapon
require DngHumanAnim
require PhysVars
require DagorRandom
require DagorMath
require DagorSystem
require game.events.events
require game.events.events_active_matter


def random_p3(mu, sigma : float3) : float3
  return mu + sigma * float3(gauss_rnd(0), gauss_rnd(0), gauss_rnd(0))

def recoil_update(var pos : float3&; var vel : float3&; spring, damp, inertia : float3; dt : float)
  let invInertia = safeinv(inertia)
  // -k*x - c*v
  let updateRate = 1.0 / 60.0// not less than 60fps for smooth and predicatable integration
  var critDamping = 4.f * spring * inertia
  critDamping.x = sqrt(critDamping.x)
  critDamping.y = sqrt(critDamping.y)
  critDamping.z = sqrt(critDamping.z)
  let resDamping = damp * critDamping
  var remainingDt = dt
  while remainingDt > 0.f
    let curDt = min(remainingDt, updateRate)
    let acc = -(spring * pos + resDamping * vel) * invInertia
    pos += vel * curDt + acc * curDt * curDt * 0.5f
    vel += acc * curDt
    remainingDt -= updateRate

def constraint_movement(var pos : float3&; var vel : float3&; limit : float3)
  for i in range(0, 3)
    if pos[i] < -limit[i] || pos[i] > limit[i]
      vel[i] = 0.f
    pos[i] = clamp(pos[i], -limit[i], limit[i])

[es(after=update_phys_es, before=anim_phys_updater_es, before=animchar_es, REQUIRE_NOT=deadEntity)]
def human_anim_weap(info : ParallelUpdateFrameDelayed;
                    human_anim : HumanAnimCtx;
                    human_net_phys__aimPosition : float;
                    var phys_vars : PhysVars;
                    human_weap__gunEids : EidList;
                    human_weap__currentGunSlot : int;
                    human_weap__gunAngleSpeed : float2;
                    human_weap__gunAngleSpeedToVelocityMult : float3;
                    human_weap__gunAngleSpeedToOmegaMult : float3;
                    var human_weap__recoil : float&;
                    var human_weap__gunOffset : float3&;
                    var human_weap__gunVelocity : float3&;
                    human_weap__gunOffsetSpring : float3;
                    human_weap__gunOffsetDamping : float3;
                    var human_weap__gunRotation : float3&;
                    var human_weap__gunOmega : float3&;
                    human_weap__recoilEnabled : bool = true;
                    human_weap__gunRotationSpring : float3;
                    human_weap__gunRotationDamping : float3;
                    human_weap__curRecoilMult : float;
                    human_weap__gunOffsAngles : float3;
                    var prevVisualBoltActionProgress : float&;
                    boltActionProgress : float;
                    human_weap__gunOffsetLimit : float3;
                    human_weap__gunRotationLimit : float3;
                    var human_weap__jumpOffsetLandCurrent : float3&;
                    human_weap__jumpOffsetLandViscosity : float;
                    human_weap__jumpOffsetMinMaxGunWeight : float2;
                    human_weap__jumpOffsetAddVelocity : float3;
                    human_weap__jumpOffsetAddOmega : float3;
                    human_phys__jumpEndTime : float;
                    human_phys__jumpStartTime : float;
                    human_phys__afterJumpDelay : float;
                    animchar__visible = true;
                    animchar__actWhenInvisible = false;
                    human_weap__recoilToImpulseMult : float = 20.f)
  if !animchar__visible && !animchar__actWhenInvisible
    return
  if human_weap__currentGunSlot < 0
    return
  let gunEid = human_weap__gunEids[human_weap__currentGunSlot]
  ecs::query(gunEid) <| $ [es] (gun__inertialMass : float;
                                gun__rotInertia, gun__recoilOffsetMean, gun__recoilOffsetDeviation,
                                gun__recoilRotationMean, gun__recoilRotationDeviation : float3;
                                gun__recoilAmount : float;
                                gun__recoilOriMultInAim : float3;
                                gun__rotationSpringMult : float3;
                                gun__visualRecoilMult : float = 1.0;
                                gun__visualBoltRecoilMult : float = 0.3;
                                gun__gunRotationDamping : float3 = float3(1.0);
                                gun__rotationSpringAimMult : float3 const?)
    let massInertia = float3(gun__inertialMass, gun__inertialMass, gun__inertialMass)
    let rotInertia = gun__rotInertia * gun__inertialMass
    let invMoi = safeinv(rotInertia)

    let gunRecoil = human_weap__recoilEnabled ? gun__recoilAmount : 0.0

    if boltActionProgress > 0.5 && prevVisualBoltActionProgress <= 0.5
      human_weap__recoil = gunRecoil * gun__visualRecoilMult * human_weap__curRecoilMult * gun__visualBoltRecoilMult * 0.00001
    if human_weap__recoil > 0.f
      let invMass = safeinv(massInertia)
      let velRecoilMult = random_p3(gun__recoilOffsetMean, gun__recoilOffsetDeviation)
      let recoilOriMult = human_net_phys__aimPosition > 0.5 ? gun__recoilOriMultInAim : float3(1.0, 1.0, 1.0)
      human_weap__gunVelocity += human_weap__recoil * human_weap__recoilToImpulseMult * invMass * velRecoilMult

      let omegaRecoilMult = random_p3(gun__recoilRotationMean, gun__recoilRotationDeviation)
      human_weap__gunOmega += human_weap__recoil * human_weap__recoilToImpulseMult * invMoi * omegaRecoilMult * recoilOriMult

    let dtMultiplier = info.dt * 60.
    human_weap__gunOmega += human_weap__gunOffsAngles * dtMultiplier
    let invMass = safeinv(gun__inertialMass)
    prevVisualBoltActionProgress = boltActionProgress
    human_weap__recoil = 0.f
    human_weap__gunVelocity.y += human_weap__gunAngleSpeed.y * human_weap__gunAngleSpeedToVelocityMult.y * invMass * dtMultiplier
    human_weap__gunVelocity.z += human_weap__gunAngleSpeed.x * human_weap__gunAngleSpeedToVelocityMult.z * invMass * dtMultiplier
    human_weap__gunOmega.x += human_weap__gunAngleSpeed.x * human_weap__gunAngleSpeedToOmegaMult.x * invMoi.x * dtMultiplier
    human_weap__gunOmega.y += human_weap__gunAngleSpeed.x * human_weap__gunAngleSpeedToOmegaMult.y * invMoi.y * dtMultiplier
    human_weap__gunOmega.z += human_weap__gunAngleSpeed.y * human_weap__gunAngleSpeedToOmegaMult.z * invMoi.z * dtMultiplier

    let jumpOffsetApplyTime = max(human_phys__jumpEndTime, human_phys__jumpStartTime)
    let jumpOffsetWeight = 1.0 - abs(cvt(info.curTime, jumpOffsetApplyTime, jumpOffsetApplyTime + human_phys__afterJumpDelay, -1.0, 1.0)) // 0 -> 1 -> 0
    let jumpOffsetGunWeightMod = cvt(gun__inertialMass, human_weap__jumpOffsetMinMaxGunWeight.x, human_weap__jumpOffsetMinMaxGunWeight.y, 0.0, 1.0)
    human_weap__gunVelocity += human_weap__jumpOffsetAddVelocity * jumpOffsetWeight * jumpOffsetGunWeightMod
    human_weap__gunOmega += human_weap__jumpOffsetAddOmega * jumpOffsetWeight * jumpOffsetGunWeightMod

    recoil_update(human_weap__gunOffset, human_weap__gunVelocity,
                  human_weap__gunOffsetSpring, human_weap__gunOffsetDamping,
                  massInertia, info.dt)

    let springMult = human_net_phys__aimPosition > 0.9 && gun__rotationSpringAimMult != null ? *gun__rotationSpringAimMult : gun__rotationSpringMult
    recoil_update(human_weap__gunRotation, human_weap__gunOmega,
                  human_weap__gunRotationSpring * springMult, human_weap__gunRotationDamping * gun__gunRotationDamping,
                  rotInertia, info.dt)

    setVar(phys_vars, human_anim.weaponRollVarId, human_weap__gunRotation.x)
    setVar(phys_vars, human_anim.weaponYawVarId, human_weap__gunRotation.y)
    setVar(phys_vars, human_anim.weaponPitchVarId, human_weap__gunRotation.z)

    constraint_movement(human_weap__gunOffset, human_weap__gunVelocity, human_weap__gunOffsetLimit)
    constraint_movement(human_weap__gunRotation, human_weap__gunOmega, human_weap__gunRotationLimit)

    human_weap__jumpOffsetLandCurrent = approach(human_weap__jumpOffsetLandCurrent, float3(0.0), info.dt, human_weap__jumpOffsetLandViscosity)

    let offset = human_weap__gunOffset + human_weap__jumpOffsetLandCurrent

    setVar(phys_vars, human_anim.weaponOffsFwdVarId, offset.x)
    setVar(phys_vars, human_anim.weaponOffsUpVarId, offset.y)
    setVar(phys_vars, human_anim.weaponOffsLeftVarId, offset.z)


[es(tag=gameClient)]
def human_weap_jump_offset_land(evt : CmdPostPhysUpdate;
                                human_net_phys : HumanActor;
                                human_weap__jumpOffsetLandMinSpeed : float;
                                human_weap__jumpOffsetLandMaxSpeed : float;
                                human_weap__jumpOffsetLandMaxOffsetTpv : float3;
                                human_weap__jumpOffsetLandMaxOffsetFpv : float3;
                                var human_weap__jumpOffsetLandCurrent : float3&;
                                hero : Tag const?)
  let spdSummaryDiffY = human_net_phys.phys.currentState.spdSummaryDiff.y
  if spdSummaryDiffY >= human_weap__jumpOffsetLandMinSpeed
    let power = cvt(spdSummaryDiffY, human_weap__jumpOffsetLandMinSpeed, human_weap__jumpOffsetLandMaxSpeed, 0.f, 1.0)
    let offset = hero == null ? human_weap__jumpOffsetLandMaxOffsetTpv : human_weap__jumpOffsetLandMaxOffsetFpv
    human_weap__jumpOffsetLandCurrent += offset * power


def set_phys_selected_weapon_var_from_props(var phys_vars : PhysVars;
                                            gunPropsId : int;
                                            gun_eid : EntityId;
                                            human_anim__selectedWeaponVarId : int;
                                            func_name : string)
  let result = gun_to_anim_get_props(gunPropsId) <| $(gunAnimProps : GunToAnimProps)
    phys_vars |> setVar(human_anim__selectedWeaponVarId, float(gunAnimProps.enumVarId))

  if !result
    query(gun_eid) <| $ [es] (gun__blk : string = "";
                              melee_weapon__blk : string = "")
      logerr("Can't get GunToAnimProps in {func_name} with id {gunPropsId} in gun__propsId,
             eid/template {gun_eid}<{getEntityTemplateName(gun_eid)}> gunBlk: {gun__blk} meleeBlk: {melee_weapon__blk}")


[es(REQUIRE_NOT=deadEntity)]
def human_anim_weap_es(info : ParallelUpdateFrameDelayed;
                       human_weap__gunEids : EidList;
                       animchar__visible : bool = true;
                       animchar__actWhenInvisible = false;
                       human_anim__selectedWeaponVarId : int;
                       human_weap__unarmedEnumValue : int;
                       human_net_phys : HumanActor;
                       var phys_vars : PhysVars)
  if !animchar__visible && !animchar__actWhenInvisible
    return

  let gunSlot = determine_current_weapon_slot(info.curTime, human_net_phys)
  if int(gunSlot) == int(HUWeaponSlots.EWS_UNARMED)
    phys_vars |> setVar(human_anim__selectedWeaponVarId, float(human_weap__unarmedEnumValue))
    return

  if int(gunSlot) >= length(human_weap__gunEids)
    return

  assume phys = human_net_phys.phys
  query(human_weap__gunEids[int(gunSlot)]) <| $ [es] (gun__propsId : int; grenade_thrower__selectedGrenadeVarId : int = -1)
    if human_anim__selectedWeaponVarId >= 0 && phys.canSwitchWeapon
      if grenade_thrower__selectedGrenadeVarId >= 0
        phys_vars |> setVar(human_anim__selectedWeaponVarId, float(grenade_thrower__selectedGrenadeVarId))
      elif gun__propsId >= 0
        set_phys_selected_weapon_var_from_props(phys_vars, gun__propsId,
                                                human_weap__gunEids[int(gunSlot)],
                                                human_anim__selectedWeaponVarId, "human_anim_weap_es")

[es(tag=gameClient, REQUIRE_NOT=deadEntity, before=slot_attach_init_tms_es)]
def human_anim_set_force_animchar_act(info : ParallelUpdateFrameDelayed;
                                      human_weap__gunEids : EidList;
                                      human_net_phys__weapEquipCurSlot : int)
  for eid, i in human_weap__gunEids, range(length(human_weap__gunEids))
    query(eid) <| $ [es] (var force_animchar_act : bool&)
      force_animchar_act = i != human_net_phys__weapEquipCurSlot

[es]
def human_anim_weap_attachment_es(info : ParallelUpdateFrameDelayed;
                                  human_attached_gun__attachedGunEid : EntityId;
                                  human_anim__selectedWeaponVarId : int;
                                  var phys_vars : PhysVars)
  if human_attached_gun__attachedGunEid == INVALID_ENTITY_ID
    return

  let gunPropsId = get_int(human_attached_gun__attachedGunEid, "gun__propsId") ?? -1
  if gunPropsId >= 0 && human_anim__selectedWeaponVarId != 0
    set_phys_selected_weapon_var_from_props(phys_vars, gunPropsId, human_attached_gun__attachedGunEid,
                                            human_anim__selectedWeaponVarId, "human_anim_weap_attachment_es")
