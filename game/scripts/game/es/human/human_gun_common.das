module human_gun_common shared
require app
require ecs
require Gun
require PhysVars
require math.base
require ecs.extra_set
require DaWeaponProps
require DagorMath
require DngHuman
require DngNet


enum GunOperationState
  AMMO_INSPECTION
  BOLTACTION
  IDLE
  FIX_JAMMING
  RELOADING


def create_shell_entity(templ_name : string; in_tm : float3x4; start_vel : float3;
                        owner_eid : EntityId; shell_id : ShellPropIds | #; gun_props_id : int;
                        launch_time : float; expl_time : float; in_active : bool; visible : bool;
                        client_side : bool;  rethrower_eid : EntityId)
  return createEntity("{templ_name}+{client_side ? "client_side" : "replicating"}") <| $(var init)
    init |> set("transform", in_tm)
    init |> set("start_vel", start_vel)
    init |> set("shell__shell_id__shell_id", int(shell_id.shellId))
    init |> set("shell__shell_id__damage_id", int(shell_id.damageId))
    init |> set("shell__shell_id__ballistics_id", int(shell_id.ballisticsId))
    init |> set("shell__gun_props_id", gun_props_id)
    init |> set("shell__owner", owner_eid)
    init |> set("shell__rethrower", rethrower_eid)
    init |> set("shell__launchAtTime", launch_time)
    init |> set("shell__explTime", expl_time)
    init |> set("slot_attach__visible", visible)
    init |> set("animchar_render__enabled", in_active && visible)
    init |> set("active", in_active)
    if !!owner_eid
      init |> set("ignoreObjs__time", 0.01f)
      init |> set("ignoreObjs__eids", [ owner_eid])


def calc_human_net_phys_aim_speed(human_net_phys : HumanActor;
                                  gun__adsSpeedMult : float = 1.0;
                                  gun_entity_mods__adsSpeedMult : float = 1.0)
  return human_net_phys.phys.defAimSpeed * gun__adsSpeedMult * gun_entity_mods__adsSpeedMult


def reload_projectile(eid, gun_eid : EntityId) : EntityId
  var shellEid = INVALID_ENTITY_ID
  query(gun_eid) <| $ [es] (gun__shell_prop_ids : GunShellPropIds;
                            var human_gun_attached : bool&;
                            var grenade_thrower__projectileEntity : EntityId&;
                            gun__curShellId : ShellPropIds const?;
                            gun__propsId : int = -1)
    if gun__propsId < 0 || length(gun__shell_prop_ids) == 0
      return
    using() <| $(var curShellId : ShellPropIds#)
      if gun__curShellId != null
        curShellId = *gun__curShellId
      shell_entity_get_props(int(curShellId.shellId)) <| $(entProps : ShellEntityTypeProps)
        let entPropsTemplName = entProps.templName
        if !empty(entPropsTemplName) && grenade_thrower__projectileEntity == INVALID_ENTITY_ID
          shellEid = create_shell_entity(entPropsTemplName,
                                          IDENT_TM,
                                          float3(0.f),
                                          eid,
                                          curShellId,
                                          gun__propsId,
                                          /*launchTime*/ get_sync_time(),
                                          /*explTime*/ 0.f,
                                          /*active*/ false,
                                          /*visible*/ false,
                                          /*clientSide*/ !is_server(),
                                          INVALID_ENTITY_ID)
          human_gun_attached = false
          grenade_thrower__projectileEntity = shellEid

  return shellEid


def switch_to_first_weap_with_ammo(human_weap__gunEids : EidList;
                                   var phys : HumanPhys)
  var bestSlot = int(HUWeaponSlots.EWS_UNARMED)
  for i in range(int(HUWeaponSlots.EWS_GRENADE))
    var hasAmmo = false
    query(human_weap__gunEids[i]) <| $ [es] (gun__totalAmmo : int;
                                             gun__ammo : int)
      hasAmmo = gun__totalAmmo > 0 || gun__ammo > 0
    if hasAmmo
      bestSlot = i
      break
    elif human_weap__gunEids[bestSlot] == INVALID_ENTITY_ID && human_weap__gunEids[i] != INVALID_ENTITY_ID
      bestSlot = i
  phys.producedCT |> set_chosen_weapon(HUWeaponSlots(bestSlot))


// This is a modified version of cpp function gun_lerpBoltActionTime
// Unlike gun_lerpBoltActionTime it returns 1.f instead of 0.f after shoot attempt when gun__ammo == 0
def gun_lerp_bolt_action_time(gun : Gun; at_time : float)
  assume state = gun.curState
  if state.lastShotAtTime > at_time
    assume prevState = gun.prevState
    return cvt(at_time, gun.prevState.lastShotAtTime, max(prevState.lastShotAtTime, prevState.boltActionEndAtTime), 0.f, 1.f)
  else
    return cvt(at_time, state.lastShotAtTime, max(state.lastShotAtTime, state.boltActionEndAtTime), 0.f, 1.f)


def set_weapon_operation_state(new_operation_state : int; weapon_eid : EntityId)
  query(weapon_eid) <| $ [es] (gun_anim_v2__operationStateVarId : int;
                               gun_anim_v2__operationProgressVarId : int;
                               gun_anim_v2__operationStates : IntList;
                               var gun_anim_v2__currentOperationState : int&;
                               var phys_vars : PhysVars)
    gun_anim_v2__currentOperationState = new_operation_state
    setVar(phys_vars, gun_anim_v2__operationStateVarId, float(gun_anim_v2__operationStates[new_operation_state]))
    setVar(phys_vars, gun_anim_v2__operationProgressVarId, 0.0)
