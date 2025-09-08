require ecs
require app
require math.base
require game.utils.hero
require game.events.events
require DngNet
require game.events.events_game
require game.es.human_weap_common
require PhysVars
require HumanPhys
require DngHuman
require DngHumanAnim
require DngNetPhys
require DngWeapon
require DagorSystem
require DagorMath
require DagorRandom
require DaWeaponProps
require DaWeapons
require DngDm
require PhysMat
require NetPropsRegistry
require game.es.action_common
require AnimV20


[es(tag=server, REQUIRE_NOT=gun__blk, on_appear)]
def melee_item_created_es(evt : Event;
                          melee_weapon__blk : string;
                          var melee_weapon__propsId : int&)
  if melee_weapon__propsId < 0
    melee_weapon__propsId = register_net_props(melee_weapon__blk, "action")


[es(tag=server, on_appear)]
def melee_weapon_created_es(evt : Event;
                            melee_weapon__blk : string;
                            gun__blk : das_string const?;
                            var gun__propsId : int&;
                            var melee_weapon__propsId : int&)
  if gun__propsId < 0 && gun__blk == null
    gun__propsId = register_net_props(melee_weapon__blk, "gun")

  if melee_weapon__propsId < 0
    melee_weapon__propsId = register_net_props(melee_weapon__blk, "action")


[es(tag=server, on_appear)]
def melee_init_attack_ray(evt : Event;
                          melee__attackRayMat : string;
                          var melee__attackRayMatId : int&)
  melee__attackRayMatId = get_material_id(melee__attackRayMat)


def run_human_melee_action(eid : ecs::EntityId;
                           human_net_phys : HumanActor;
                           override_time : float;
                           override_props_id : int;
                           override_at : float;
                           attack_period : float)
  let meleeName = human_net_phys.phys.currentState.isCrawl ? "crawl_melee" : "stand_melee"

  if is_server()
    sendEvent(eid, CmdInterruptReloadImmediately())

  let curInterpDelayTicksPacked = getCurInterpDelayTicksPacked()
  run_action(eid, meleeName, override_props_id, curInterpDelayTicksPacked,
             override_time, override_at, attack_period)


def can_run_melee_action(eid : ecs::EntityId;
                         gun__melee : bool;
                         in_vehicle : bool;
                         is_allowed_melee : bool;
                         phys : HumanPhys&;
                         gctrl : GunControls&;
                         human_net_phys : HumanActor&;
                         human_attached_gun__attachedGunEid : ecs::EntityId = ecs::INVALID_ENTITY_ID)
  if !is_allowed_melee
    return false

  if gun__melee && gctrl.shoot
    return true

  if phys.appliedCT |> is_control_bit_set(HumanPhysControlType.HCT_MELEE)
    return true

  let isHumanAllowedShooting = is_human_allowed_shooting(eid, human_attached_gun__attachedGunEid, human_net_phys)
  let isShootControlBit = phys.appliedCT |> is_control_bit_set(HumanPhysControlType.HCT_SHOOT)
  let isAimControlBit = phys.appliedCT |> is_control_bit_set(HumanPhysControlType.HCT_AIM)
  let isSwimming = phys.currentState |> human_phys_state_get_is_swimming()

  return (!isHumanAllowedShooting &&
         isShootControlBit &&
         (isSwimming || (in_vehicle && !isAimControlBit)))


[es]
def melee_weapon_phys_es(evt : CmdWeapPhysUpdate;
                         melee_weapon__propsId : int;
                         gun__melee : bool;
                         melee_weapon__attackTime : float = -1.0;
                         melee_weapon__attackAt : float = -1.0;
                         melee_weapon__attackPeriod : float = -1.0)
  if !evt.isForReal
    return

  let ownerEid = evt.owner

  query(ownerEid) <| $ [es] (isDriver : bool;
                             human_unarmed__active : bool = false;
                             human_net_phys : HumanActor&;
                             isInVehicle : bool = false;
                             isMeleeAllowed : bool = true)
    if (isDriver || human_unarmed__active)
      return

    let isCanRunMeleeAction = can_run_melee_action(ownerEid, gun__melee,
                                                   isInVehicle, isMeleeAllowed,
                                                   human_net_phys.phys,
                                                   evt.gctrl, human_net_phys)
    if isCanRunMeleeAction
      run_human_melee_action(ownerEid, human_net_phys, melee_weapon__attackTime,
                             melee_weapon__propsId, melee_weapon__attackAt,
                             melee_weapon__attackPeriod)


[es(REQUIRE_NOT=human_weap, REQUIRE_NOT=disableUpdate)]
def human_melee_post_phys_es(evt : CmdPostPhysUpdate;
                             eid : ecs::EntityId;
                             human_net_phys : HumanActor&)
  let isForReal = evt.isForReal
  let isMeleeControlBit = human_net_phys.phys.appliedCT |> is_control_bit_set(HumanPhysControlType.HCT_MELEE)

  if isForReal && isMeleeControlBit
    run_human_melee_action(eid, human_net_phys,
                           /*override_time*/ -1.0, /*override_props_id*/ -1,
                           /*override_at*/ -1.0, /*attack_period*/ -1.0)


[es(on_appear)]
def human_unarmed_created_es(evt : Event;
                             human_unarmed__blk : string;
                             var human_unarmed__propsId : int&)
  if human_unarmed__propsId < 0
    human_unarmed__propsId = register_net_props(human_unarmed__blk, "action")


[es(REQUIRE_NOT=disableUpdate)]
def melee_unarmed_phys_es(evt : CmdPostPhysUpdate;
                          eid : ecs::EntityId;
                          human_net_phys : HumanActor&;
                          human_unarmed__attackTime : float;
                          human_unarmed__attackPeriod : float;
                          human_unarmed__propsId : int;
                          human_unarmed__active : bool = false)
  if !human_unarmed__active
    return

  assume phys = human_net_phys.phys

  let isForReal = evt.isForReal
  let isMeleeControlBit = phys.appliedCT |> is_control_bit_set(HumanPhysControlType.HCT_MELEE)
  let isShootControlBit = phys.appliedCT |> is_control_bit_set(HumanPhysControlType.HCT_SHOOT)

  if isForReal && (isMeleeControlBit || isShootControlBit)
    run_human_melee_action(eid, human_net_phys,
                           human_unarmed__attackTime, human_unarmed__propsId,
                           /*override_at*/ -1.0, human_unarmed__attackPeriod)


[es(on_appear)]
def human_unarmed_reg_es(evt : Event;
                         human_unarmed__selWeaponVar : string;
                         var human_unarmed__selWeaponVarId : int&)
  human_unarmed__selWeaponVarId = animV20_add_enum_value(human_unarmed__selWeaponVar)
