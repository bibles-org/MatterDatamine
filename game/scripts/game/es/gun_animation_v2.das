require ecs
require Gun
require AnimV20
require PhysVars
require daslib/enum_trait
require game.es.human.human_gun_common
require game.es.inventory_weapon_mod_common
require game.events.events_active_matter


[es(on_appear, before=anim_phys_init_es)]
def common_gun_anim_init_v2(evt : Event;
                            eid : EntityId;
                            var phys_vars : PhysVars&;
                            var gun_anim_v2__operationProgressVarId : int&;
                            var gun_anim_v2__isChamberedVarId : int&;
                            var gun_anim_v2__isJammingVarId : int&;
                            var gun_anim_v2__operationStateVarId : int&;
                            var gun_anim_v2__reloadTypeVarId : int&;
                            var gun_anim_v2__ammoInspectionIdleProgressVarId : int&;
                            var gun_anim_v2__actionProgressVarId : int&;
                            var gun_anim_v2__changeWeaponProgressVarId : int&;
                            var gun_anim_v2__operationStates : IntList)
  gun_anim_v2__operationProgressVarId = registerVar(phys_vars, "operation_progress", 0.f)
  gun_anim_v2__isChamberedVarId = registerVar(phys_vars, "is_chambered", 0.f)
  gun_anim_v2__isJammingVarId = registerVar(phys_vars, "is_jamming", 0.f)
  gun_anim_v2__operationStateVarId = registerVar(phys_vars, "operation_state", 0.f)
  gun_anim_v2__reloadTypeVarId = registerVar(phys_vars, "reload_type", 0.f)
  gun_anim_v2__ammoInspectionIdleProgressVarId = registerVar(phys_vars, "ammo_inspection_idle_progress", 0.f)
  gun_anim_v2__actionProgressVarId = registerVar(phys_vars, "action_progress", 0.f)
  gun_anim_v2__changeWeaponProgressVarId = registerVar(phys_vars, "changeweapon_progress", 0.f)

  let operationStatesCount = typeinfo enum_length(type<GunOperationState>)
  resize(gun_anim_v2__operationStates, operationStatesCount)
  let operationStatesEnum = fixed_array("ammo_inspection", "boltaction", "idle", "fix_jamming", "reloading")
  assert(length(operationStatesEnum) == operationStatesCount)
  for i in range(length(operationStatesEnum))
    gun_anim_v2__operationStates[i] = animV20_get_enum_value_by_name(operationStatesEnum[i])

  set_weapon_operation_state(int(GunOperationState.BOLTACTION), eid)


[es(on_appear, after=common_gun_anim_init_v2)]
def magazine_gun_anim_init_v2(evt : Event;
                              var gun_anim__reloadTypes : IntList)
  let reloadTypeCount = typeinfo enum_length(type<ModDelayedMoveType>)
  resize(gun_anim__reloadTypes, reloadTypeCount)
  let reloadTypesEnum = fixed_array("unequip_magazine", "equip_magazine", "swap_magazine")
  assert(length(reloadTypesEnum) == reloadTypeCount)
  for i in range(length(reloadTypesEnum))
    gun_anim__reloadTypes[i] = animV20_get_enum_value_by_name(reloadTypesEnum[i])


[es(tag=render, before=(animchar_es, anim_phys_updater_es), REQUIRE_NOT=sleeping_weapn)]
def reset_gun_anim_state_v2_es(info : ParallelUpdateFrameDelayed;
                               gun_anim_v2__actionProgressVarId : int;
                               gun_anim_v2__changeWeaponProgressVarId : int;
                               var phys_vars : PhysVars&)
  // Some parameters are set from animtree of the human holding the gun directly to the held weapon during animchar_act.
  // As a failsafe it's a good idea to reset these every frame before animchar_act, so that they are 100% for gun's which are no longer held.
  // Yes, this is a hack, but it fixes a ton of possible bugs of kind:
  // "We placed the gun from hands on to the back, so it no longer updates from human, but change anim did not finish fully, so the
  // gun is in change weapon anim on the back and looks wrong".
  if gun_anim_v2__actionProgressVarId > 0
    setVar(phys_vars, gun_anim_v2__actionProgressVarId, 0.0)
  if gun_anim_v2__changeWeaponProgressVarId > 0
    setVar(phys_vars, gun_anim_v2__changeWeaponProgressVarId, 0.0)


[es(tag=render, no_order, REQUIRE_NOT=sleeping_weapon)]
def gun_animate_operation_progress(act : UpdateStageInfoAct&;
                                   gun_anim_v2__currentOperationState : int;
                                   gun_anim_v2__operationProgressVarId : int;
                                   gun_anim__reloadProgress : float;
                                   var phys_vars : PhysVars;
                                   gun : Gun const?;
                                   animchar__visible : bool = true)
  if !animchar__visible
    return

  if gun != null && gun_anim_v2__currentOperationState == int(GunOperationState.BOLTACTION)
    let boltActionState = gun_lerp_bolt_action_time(*gun, act.curTime)
    setVar(phys_vars, gun_anim_v2__operationProgressVarId, boltActionState)
  elif gun_anim_v2__currentOperationState == int(GunOperationState.RELOADING)
    setVar(phys_vars, gun_anim_v2__operationProgressVarId, gun_anim__reloadProgress)
