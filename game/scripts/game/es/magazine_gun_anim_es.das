require ecs
require AnimV20
require PhysVars
require AnimatedPhys
require DagorConsole
require daslib/enum_trait
require game.events.inventory_events
require game.es.human.human_gun_common
require game.es.inventory_weapon_mod_common
require game.es.boxed_ammo_reload_common


[es(on_appear, after=common_gun_anim_init_es)]
def magazine_gun_anim_init_es(evt : Event;
                              var phys_vars : PhysVars&;
                              var gun_anim__isReloadVarId : int&;
                              var gun_anim__reloadVarId : int&;
                              var gun_anim__reloadTypeVarId : int&;
                              var gun_anim__reloadTypes : IntList)
  gun_anim__isReloadVarId = registerVar(phys_vars, "is_reload", 0.f)
  gun_anim__reloadVarId = registerVar(phys_vars, "reload_progress", 0.f)
  gun_anim__reloadTypeVarId = registerVar(phys_vars, "reload_type", -1.f)

  let reload_type_count = typeinfo enum_length(type<ModDelayedMoveType>)
  resize(gun_anim__reloadTypes, reload_type_count)
  let reloadTypesEnum = fixed_array("unequip_mag", "equip_mag", "swap_mag")
  assert(length(reloadTypesEnum) == reload_type_count)
  for i in range(length(reloadTypesEnum))
    gun_anim__reloadTypes[i] = animV20_get_enum_value_by_name(reloadTypesEnum[i])
  registerVar(phys_vars, "unload_state", float(animV20_get_enum_value_by_name("unload_disabled")))


def start_reload_anim(gun_eid : EntityId; reload_type : int)
  query(gun_eid) <| $ [es(REQUIRE_NOT=gun_anim_v2__operationStateVarId)] (
                                                                          gun_anim__reloadTypeVarId : int;
                                                                          gun_anim__reloadVarId : int;
                                                                          gun_anim__isReloadVarId : int;
                                                                          gun_anim__reloadTypes : IntList;
                                                                          var gun_anim__reloadProgress : float&;
                                                                          var phys_vars : PhysVars;
                                                                          var anim_phys : AnimatedPhys;
                                                                          var animchar : AnimcharBaseComponent;
                                                                          var animchar_node_wtm : AnimcharNodesMat44&;
                                                                          var animchar_render__root_pos : vec4f&)
    setVar(phys_vars, gun_anim__reloadTypeVarId, float(gun_anim__reloadTypes[reload_type]))
    gun_anim__reloadProgress = 0.f
    setVar(phys_vars, gun_anim__reloadVarId, gun_anim__reloadProgress)
    setVar(phys_vars, gun_anim__isReloadVarId, 1.f)

    anim_phys |> anim_phys_update(animchar, phys_vars)
    animchar |> animchar_act(0.f, true)
    animchar |> animchar_copy_nodes(animchar_node_wtm, animchar_render__root_pos)
  query(gun_eid) <| $ [es] (gun__ammo : int;
                            gun_anim_v2__isChamberedVarId : int;
                            gun_anim_v2__reloadTypeVarId : int;
                            gun_anim__reloadTypes : IntList;
                            var phys_vars : PhysVars)
    set_weapon_operation_state(int(GunOperationState.RELOADING), gun_eid)
    phys_vars |> setVar(gun_anim_v2__isChamberedVarId, gun__ammo > 0 ? 1.0 : 0.0)
    phys_vars |> setVar(gun_anim_v2__reloadTypeVarId, float(gun_anim__reloadTypes[reload_type]))


[es(tag=render, track=weapon_mods__delayedMoveState)]
def set_reload_anim_on_delayed_move_weapon_mod_started(evt : Event;
                                                       eid : EntityId;
                                                       weapon_mods__delayedMoveState : int;
                                                       weapon_mods__delayedMoveType : int;
                                                       gun_anim__reloadProgress : float;
                                                       animchar__visible : bool = true)
  if !animchar__visible
    return
  if weapon_mods__delayedMoveState != int(ModDelayedMoveState.MOVE)
    return
  if gun_anim__reloadProgress > 0.0 && gun_anim__reloadProgress < 1.f // reload already in progress
    return

  start_reload_anim(eid, weapon_mods__delayedMoveType)


// When magazine is equipping, reload animation must start before change_weapon_mod_subtemplates_on_equip is called.
// Otherwise magazine will attach and will be visible in fully-equipped state for all the time until reload animation starts
// (until track=weapon_mods__delayedMoveState is triggered)
[es(tag=render, before=change_weapon_mod_subtemplates_on_equip, REQUIRE=item__id)]
def set_reload_anim_on_equip_weapon_mod_started(evt : EventOnEquipingAsWeaponMod)
  if !evt.isStartDelayedEquip
    return

  query(evt.weaponEid) <| $ [es] (gun_anim__reloadProgress : float;
                                  animchar__visible : bool = true)
    if !animchar__visible
      return
    if gun_anim__reloadProgress > 0.0 && gun_anim__reloadProgress < 1.f // reload already in progress
      return

    start_reload_anim(evt.weaponEid, int(ModDelayedMoveType.EQUIP))


[es(tag=render, before=common_gun_anim_updater_es, after=human_weap_anim_es)]
def set_reload_anim_progress_to_current_gun(info : UpdateStageInfoAct;
                                            weapon_mods__delayedMoveStartTime : float;
                                            weapon_mods__delayedMoveFinishTime : float;
                                            weapon_mods__modDelayedUnequipEid : EntityId;
                                            weapon_mods__delayedMoveState : int;
                                            weapon_mods__delayedMoveType : int;
                                            var gun_anim__reloadProgress : float&)
  if weapon_mods__delayedMoveState != int(ModDelayedMoveState.MOVE)
    return

  assume startTime = weapon_mods__delayedMoveStartTime
  assume finishTime = weapon_mods__delayedMoveFinishTime
  let curTime = clamp(info.curTime, startTime, finishTime)
  gun_anim__reloadProgress = safediv(curTime - startTime, finishTime - startTime)
  if weapon_mods__delayedMoveType == int(ModDelayedMoveType.SWAP)
    gun_anim__reloadProgress *= 0.5
    if weapon_mods__modDelayedUnequipEid == INVALID_ENTITY_ID // second half of swap
      gun_anim__reloadProgress += 0.5


[es(tag=render, track=weapon_mods__delayedMoveState)]
def reset_reload_anim_progress_on_delayed_move_weapon_mod_finished_or_aborted(evt : Event;
                                                                              weapon_mods__delayedMoveState : int;
                                                                              gun_anim__reloadTypeVarId : int;
                                                                              gun_anim__reloadVarId : int;
                                                                              gun_anim__isReloadVarId : int;
                                                                              gun_anim__reloadTypes : IntList;
                                                                              gun_anim__boltActionVarId : int;
                                                                              var gun_anim__reloadProgress : float&;
                                                                              var phys_vars : PhysVars;
                                                                              var anim_phys : AnimatedPhys;
                                                                              var animchar : AnimcharBaseComponent;
                                                                              var animchar_node_wtm : AnimcharNodesMat44&;
                                                                              var animchar_render__root_pos : vec4f&)
  if weapon_mods__delayedMoveState != int(ModDelayedMoveState.NONE)
    return

  // TODO: remove this ugly hack
  // move was finished or aborted, so gun should be in aim state, magazine may or may not be in gun (which corresponds to equip animation with reload_progress == 1.f)
  setVar(phys_vars, gun_anim__reloadTypeVarId, float(gun_anim__reloadTypes[int(ModDelayedMoveType.EQUIP)]))
  gun_anim__reloadProgress = 1.f
  setVar(phys_vars, gun_anim__reloadVarId, gun_anim__reloadProgress)
  setVar(phys_vars, gun_anim__isReloadVarId, 0.f)
  // After reload is finished bolt_progress is always = 0.0f. Reset it here so pistols will not have one frame of animation where bolt is pulled back.
  setVar(phys_vars, gun_anim__boltActionVarId, 0.f)

  // FIXME: This is a bad way to force update gun animchar as we ignore common_gun_anim_updater_es's update
  // (it's result will get written to animchar nodes only on ParallelUpdateFrameDelayed = next frame).
  // And unless this system results in fully correct weapon state, this can cause strange one frame animation bugs.
  // Ideally we should not call theese and relly on usual animchar update order (animchar__updater_es or slot_attach update systems).
  anim_phys |> anim_phys_update(animchar, phys_vars)
  animchar |> animchar_act(0.f, true)
  animchar |> animchar_copy_nodes(animchar_node_wtm, animchar_render__root_pos)


[es(tag=render, track=weapon_mods__delayedMoveState)]
def reset_reload_anim_progress_v2(evt : Event;
                                  eid : EntityId;
                                  weapon_mods__delayedMoveState : int;
                                  var phys_vars : PhysVars;
                                  var anim_phys : AnimatedPhys;
                                  var animchar : AnimcharBaseComponent;
                                  var animchar_node_wtm : AnimcharNodesMat44&;
                                  var animchar_render__root_pos : vec4f&)
  if weapon_mods__delayedMoveState != int(ModDelayedMoveState.NONE)
    return

  set_weapon_operation_state(int(GunOperationState.BOLTACTION), eid)

  // FIXME: This is a bad way to force update gun animchar as we ignore common_gun_anim_updater_es's update
  // (it's result will get written to animchar nodes only on ParallelUpdateFrameDelayed = next frame).
  // And unless this system results in fully correct weapon state, this can cause strange one frame animation bugs.
  // Ideally we should not call theese and relly on usual animchar update order (animchar__updater_es or slot_attach update systems).
  anim_phys |> anim_phys_update(animchar, phys_vars)
  animchar |> animchar_act(0.f, true)
  animchar |> animchar_copy_nodes(animchar_node_wtm, animchar_render__root_pos)
