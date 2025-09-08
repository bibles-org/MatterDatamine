require ecs
require Gun
require AnimV20
require PhysVars
require AnimatedPhys
require daslib/enum_trait
require game.es.human.human_gun_common
require game.es.human.human_reload_common
require game.events.events_active_matter


[es(on_appear, before=common_gun_anim_init_es)]
def loaded_shells_anim_init_es(evt : Event;
                               var phys_vars : PhysVars&;
                               var gun_anim__loadedShellsNumVarId : int&)
  gun_anim__loadedShellsNumVarId = registerVar(phys_vars, "loaded_shells", 0.f)


[es(on_appear, before=anim_phys_init_es)]
def common_gun_anim_init_es(evt : Event;
                            var phys_vars : PhysVars&;
                            var gun_anim__boltActionVarId : int&;
                            var gun_anim__reloadVarId : int&;
                            var gun_anim__reloadStyleVarId : int&;
                            var gun_anim__ammoInspectionProgressVarId : int&;
                            var gun_anim__ammoInspectionIdleProgressVarId : int&;
                            var gun_anim__haveProjectileInChamberVarId : int&;
                            var gun_anim__curNumAmmoVarId : int&;
                            var gun_anim__haveOpticsVarId : int&;
                            var gun_anim__actionProgressVarId : int&;
                            var gun_anim__changeWeaponProgressVarId : int&;
                            var gun_anim__reloadStyles : IntList)
  gun_anim__boltActionVarId = registerVar(phys_vars, "bolt_action", 0.f)
  gun_anim__reloadVarId = registerVar(phys_vars, "reload_progress", 0.f)
  gun_anim__reloadStyleVarId = registerVar(phys_vars, "reload_style", 0.f)
  gun_anim__ammoInspectionProgressVarId = registerVar(phys_vars, "ammo_inspection_progress", 0.f)
  gun_anim__ammoInspectionIdleProgressVarId = registerVar(phys_vars, "ammo_inspection_idle_progress", 0.f)
  gun_anim__haveProjectileInChamberVarId = registerVar(phys_vars, "have_projectile_in_chamber", 0.f)
  gun_anim__curNumAmmoVarId = registerVar(phys_vars, "cur_num_ammo", 0.f)
  gun_anim__haveOpticsVarId = registerVar(phys_vars, "have_optics", 0.f)
  gun_anim__actionProgressVarId = registerVar(phys_vars, "action_progress", 0.f)
  gun_anim__changeWeaponProgressVarId = registerVar(phys_vars, "changeweapon_progress", 0.f)

  let reload_style_count = typeinfo enum_length(type<GunReloadStyle>)
  resize(gun_anim__reloadStyles, reload_style_count)
  let reloadStylesEnum = fixed_array("reload_simple", "reload_alt", "reload_alt_jammed", "reload_jammed")
  assert(length(reloadStylesEnum) == reload_style_count)
  for i in range(length(reloadStylesEnum))
    gun_anim__reloadStyles[i] = animV20_get_enum_value_by_name(reloadStylesEnum[i])


[es(tag=render, no_order, REQUIRE_NOT=sleeping_weapon)]
def common_gun_anim_updater_es(info : UpdateStageInfoAct&;
                               gun_anim__reloadVarId : int;
                               gun_anim__reloadStyleVarId : int;
                               gun_anim__boltActionVarId : int;
                               gun_anim__haveProjectileInChamberVarId : int;
                               gun_anim__curNumAmmoVarId : int;
                               gun_anim__haveOpticsVarId : int;
                               gun_anim__reloadStyles : IntList;
                               gun__ammo : int;
                               gun : Gun const?;
                               gun_anim__reloadProgress : float = -1.0f;
                               gun_anim__reloadStyle : int = 0;
                               gun__opticsAttached : bool = false;
                               gun__showChamberedAmmo : bool = true;
                               animchar__visible : bool = true;
                               var phys_vars : PhysVars)
  if !animchar__visible
    return

  if gun != null
    let boltActionState = gun_lerp_bolt_action_time(*gun, info.curTime)
    setVar(phys_vars, gun_anim__boltActionVarId, gun__ammo > 0 && boltActionState == 1.f ? 0.f : boltActionState)
    setVar(phys_vars, gun_anim__haveProjectileInChamberVarId, (gun__showChamberedAmmo && gun.curState.loaded) ? 1.f : 0.f)

  let reloadStyleEnum = gun_anim__reloadStyles[gun_anim__reloadStyle]

  setVar(phys_vars, gun_anim__reloadVarId, gun_anim__reloadProgress)
  setVar(phys_vars, gun_anim__reloadStyleVarId, float(reloadStyleEnum))

  setVar(phys_vars, gun_anim__curNumAmmoVarId, float(gun__ammo))
  setVar(phys_vars, gun_anim__haveOpticsVarId, gun__opticsAttached ? 1.f : 0.f)


[es(tag=render, no_order, REQUIRE_NOT=sleeping_weapon)]
def loaded_shells_anim_updater_es(info : UpdateStageInfoAct&;
                                  gun_anim__loadedShellsNumVarId : int;
                                  gun_anim__shellsLoaded : int;
                                  animchar__visible : bool = true;
                                  var phys_vars : PhysVars)
  if !animchar__visible
    return

  setVar(phys_vars, gun_anim__loadedShellsNumVarId, float(gun_anim__shellsLoaded))


[es(tag=render, before=(animchar_es, anim_phys_updater_es), REQUIRE_NOT=sleeping_weapn)]
def reset_gun_anim_state_es(info : ParallelUpdateFrameDelayed;
                            gun_anim__actionProgressVarId : int;
                            gun_anim__changeWeaponProgressVarId : int;
                            var phys_vars : PhysVars&)
  // Some parameters are set from animtree of the human holding the gun directly to the held weapon during animchar_act.
  // As a failsafe it's a good idea to reset these every frame before animchar_act, so that they are 100% for gun's which are no longer held.
  // Yes, this is a hack, but it fixes a ton of possible bugs of kind:
  // "We placed the gun from hands on to the back, so it no longer updates from human, but change anim did not finish fully, so the
  // gun is in change weapon anim on the back and looks wrong".
  if gun_anim__actionProgressVarId > 0
    setVar(phys_vars, gun_anim__actionProgressVarId, 0.0)
  if gun_anim__changeWeaponProgressVarId > 0
    setVar(phys_vars, gun_anim__changeWeaponProgressVarId, 0.0)


[es(tag=render, on_appear, track=gun__ammo, after=(common_gun_anim_init_es, anim_phys_init_es))]
def set_not_equipped_gun_bolt_state(evt : Event;
                                    slot_attach__attachedTo : EntityId;
                                    gun_anim__boltActionVarId : int;
                                    gun_anim__curNumAmmoVarId : int;
                                    gun__ammo : int;
                                    var phys_vars : PhysVars;
                                    var anim_phys : AnimatedPhys;
                                    var animchar : AnimcharBaseComponent;
                                    var animchar_node_wtm : AnimcharNodesMat44&;
                                    var animchar_render__root_pos : vec4f&)
  if !!slot_attach__attachedTo
    return

  setVar(phys_vars, gun_anim__boltActionVarId, gun__ammo > 0 ? 0.f : 1.f)
  setVar(phys_vars, gun_anim__curNumAmmoVarId, float(gun__ammo))

  anim_phys |> anim_phys_update(animchar, phys_vars)
  animchar |> animchar_act(0.f, true)
  animchar |> animchar_copy_nodes(animchar_node_wtm, animchar_render__root_pos)
