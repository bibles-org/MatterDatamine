require ecs
require app
require HumanPhys
require DngHuman
require Gun
require game.events.events
require DagorConsole
require game.events.events_game
require game.utils.net_utils
require net


[es(on_appear)]
def human_hand_stamina_init(evt : Event;
                            human_hand_stamina__maxStamina : float;
                            var human_hand_stamina__stamina : float&)
  human_hand_stamina__stamina = human_hand_stamina__maxStamina


// human_hand_stamina_drain multiplies breathShakeMult everyframe assuming it is set by hearbeat_es
// To not have a float overflow we need this system to reset it to a default value on entities which do not have hearbeat_es
[es(after=human_phys_es, before=(hearbeat_es, human_hand_stamina_drain))]
def human_reset_breath_shake_mult(evt : CmdPostPhysUpdate;
                                  human_hand_stamina__enabled : bool = true;
                                  var human_net_phys : HumanActor&)
  human_net_phys.phys.currentState.breathShakeMult = human_hand_stamina__enabled ? 1.0 : 0.0


[es(after=(human_phys_es, hearbeat_es), before=human_weapon_aim)]
def human_hand_stamina_drain(evt : CmdPostPhysUpdate;
                             human_hand_stamina__enabled : bool = true;
                             human_hand_stamina__maxStamina : float;
                             human_hand_stamina__drain : float;
                             human_hand_stamina__regen : float2;
                             human_hand_stamina__HRMult : float;
                             human_hand_stamina__weaponMult : float;
                             human_hand_stamina__stateDrainMult : float3;
                             human_hand_stamina__breathShakeRange : float2;
                             human_hand_stamina__breathShakeMult : float2;
                             human_weap__currentGunEid : EntityId;
                             isDowned : bool = false;
                             var human_net_phys : HumanActor&;
                             var human_hand_stamina__stamina : float&)
  if !human_hand_stamina__enabled
    return

  assume currentState = human_net_phys.phys.currentState
  assume appliedCT = human_net_phys.phys.appliedCT
  assume standState = currentState.standState

  var isPreparingForNextShot = false

  query(human_weap__currentGunEid) <| $[es] (gun : Gun)
    isPreparingForNextShot = get_sync_time() < gun.curState.nextShotAtTime


  let isAiming = ((human_phys_state_can_aim(currentState) || isPreparingForNextShot)
    && is_control_bit_set(appliedCT, HumanPhysControlType.HCT_AIM)
    && currentState.weapEquipState.curState != HUWeaponEquipState.EES_DOWN
    && !human_phys_state_get_isClimbing(currentState)
    && !isDowned)

  if isAiming
    var drainMult = (standState == HUStandState.ESS_STAND ? human_hand_stamina__stateDrainMult.x :
                     standState == HUStandState.ESS_CROUCH ? human_hand_stamina__stateDrainMult.y :
                     /*crawl*/human_hand_stamina__stateDrainMult.z) * human_hand_stamina__HRMult * human_hand_stamina__weaponMult

    query(human_weap__currentGunEid) <| $[es] (gun_hand_stamina__drainMult : float)
      drainMult *= gun_hand_stamina__drainMult

    human_hand_stamina__stamina = max(human_hand_stamina__stamina - human_hand_stamina__drain * drainMult * evt.dt, 0.)
  else
    let regenSpeed = lerp(human_hand_stamina__regen.x, human_hand_stamina__regen.y, safediv(human_hand_stamina__stamina, human_hand_stamina__maxStamina))
    human_hand_stamina__stamina = min(human_hand_stamina__stamina + regenSpeed * evt.dt, human_hand_stamina__maxStamina)

  currentState.breathShakeMult *= cvt(human_hand_stamina__stamina, human_hand_stamina__breathShakeRange.x, human_hand_stamina__breathShakeRange.y, human_hand_stamina__breathShakeMult.x, human_hand_stamina__breathShakeMult.y)
