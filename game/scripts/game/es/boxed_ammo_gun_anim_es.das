require ecs
require AnimV20
require PhysVars
require AnimatedPhys
require daslib/enum_trait
require DagorMath
require game.es.boxed_ammo_reload_common


[es(on_appear, after=common_gun_anim_init_es)]
def boxed_ammo_gun_anim_load_init_es(evt : Event;
                                     var phys_vars : PhysVars&;
                                     var gun_anim__singleReloadVarId : int&;
                                     var gun_anim__singleReloadStateVarId : int&;
                                     var gun_anim__singleReloadStates : IntList;
                                     var gun_anim__unloadVarId : int&;
                                     var gun_anim__unloadStateVarId : int&;
                                     var gun_anim__unloadStates : IntList;
                                     var gun_anim__fromEmptyVarId : int&)
  gun_anim__singleReloadVarId = registerVar(phys_vars, "single_reload_progress", 0.f)
  gun_anim__singleReloadStateVarId = registerVar(phys_vars, "single_reload_state", 0.f)
  let reload_count = typeinfo enum_length(type<BoxedAmmoReloadState>)
  resize(gun_anim__singleReloadStates, reload_count)
  gun_anim__singleReloadStates[int(BoxedAmmoReloadState.NONE) + 1] = -1
  gun_anim__singleReloadStates[int(BoxedAmmoReloadState.WAIT) + 1] = -1
  let loadAnimStates <- {
    "single_reload_disabled" => int(BoxedAmmoReloadState.NONE) + 1,
    "single_reload_prepare" => int(BoxedAmmoReloadState.PREPARE) + 1,
    "single_reload_loop" => int(BoxedAmmoReloadState.LOOP) + 1,
    "single_reload_post" => int(BoxedAmmoReloadState.POST) + 1
  }
  for state_name, state_num in keys(loadAnimStates), values(loadAnimStates)
    gun_anim__singleReloadStates[state_num] = animV20_get_enum_value_by_name(state_name)

  gun_anim__unloadVarId = registerVar(phys_vars, "unload_progress", 0.f)
  gun_anim__unloadStateVarId = registerVar(phys_vars, "unload_state", 0.f)
  resize(gun_anim__unloadStates, reload_count)
  gun_anim__unloadStates[int(BoxedAmmoReloadState.NONE) + 1] = -1
  gun_anim__unloadStates[int(BoxedAmmoReloadState.WAIT) + 1] = -1
  let unloadAnimStates <- {
    "unload_disabled" => int(BoxedAmmoReloadState.NONE) + 1,
    "unload_prepare" => int(BoxedAmmoReloadState.PREPARE) + 1,
    "unload_loop" => int(BoxedAmmoReloadState.LOOP) + 1,
    "unload_post" => int(BoxedAmmoReloadState.POST) + 1
  }
  for state_name, state_num in keys(unloadAnimStates), values(unloadAnimStates)
    gun_anim__unloadStates[state_num] = animV20_get_enum_value_by_name(state_name)

  gun_anim__fromEmptyVarId = registerVar(phys_vars, "reload_from_empty", 0.f)


[es(tag=render, after=common_gun_anim_updater_es)]
def boxed_ammo_gun_bullet_by_bullet_reload_anim_updater_es(info : UpdateStageInfoAct&;
                                                           gun_anim__reloadProgress : float;
                                                           gun_anim__singleReloadVarId : int;
                                                           gun_anim__singleReloadStateVarId : int;
                                                           gun_anim__singleReloadStates : IntList;
                                                           gun_anim__unloadVarId : int;
                                                           gun_anim__unloadStateVarId : int;
                                                           gun_anim__unloadStates : IntList;
                                                           gun_anim__fromEmptyVarId : int;
                                                           gun_boxed_ammo_reload__ammoCountBeforeReload : int;
                                                           gun_boxed_ammo_reload__reloadState : int;
                                                           gun_boxed_ammo_reload__isLoad : bool;
                                                           animchar__visible : bool = true;
                                                           gun_anim__customReloadStyleEnabled : bool = false;
                                                           var phys_vars : PhysVars)
  if !animchar__visible
    return
  if gun_anim__customReloadStyleEnabled
    return

  if gun_boxed_ammo_reload__isLoad
    setVar(phys_vars, gun_anim__singleReloadStateVarId, float(gun_anim__singleReloadStates[gun_boxed_ammo_reload__reloadState + 1]))
    setVar(phys_vars, gun_anim__singleReloadVarId, gun_anim__reloadProgress)
    setVar(phys_vars, gun_anim__fromEmptyVarId, gun_boxed_ammo_reload__ammoCountBeforeReload > 0 ? 0.f : 1.f)
  else
    setVar(phys_vars, gun_anim__unloadStateVarId, float(gun_anim__unloadStates[gun_boxed_ammo_reload__reloadState + 1]))
    setVar(phys_vars, gun_anim__unloadVarId, gun_anim__reloadProgress)


[es(tag=render, before=common_gun_anim_updater_es, after=human_weap_anim_es)]
def set_boxed_ammo_bullet_by_bullet_reload_anim_progress_to_current_gun(info : UpdateStageInfoAct;
                                                                        gun_boxed_ammo_reload__reloadState : int;
                                                                        gun_boxed_ammo_reload__startTime : float;
                                                                        gun_boxed_ammo_reload__atTime : float;
                                                                        var gun_anim__reloadProgress : float&)
  if gun_boxed_ammo_reload__reloadState == int(BoxedAmmoReloadState.NONE)
    return

  assume startTime = gun_boxed_ammo_reload__startTime
  assume finishTime = gun_boxed_ammo_reload__atTime
  let curTime = clamp(info.curTime, startTime, finishTime)
  gun_anim__reloadProgress = safediv(curTime - startTime, finishTime - startTime)


[es(tag=render, on_appear, after=boxed_ammo_gun_anim_load_init_es, track=gun_boxed_ammo_reload__reloadState)]
def reset_reload_anim_progress_on_boxed_ammo_reload_finished_or_interrupted(evt : Event;
                                                                            gun_boxed_ammo_reload__reloadState : int;
                                                                            gun_anim__reloadVarId : int;
                                                                            gun_anim__singleReloadVarId : int;
                                                                            gun_anim__singleReloadStateVarId : int;
                                                                            gun_anim__singleReloadStates : IntList;
                                                                            gun_anim__unloadVarId : int;
                                                                            gun_anim__unloadStateVarId : int;
                                                                            gun_anim__unloadStates : IntList;
                                                                            var gun_anim__reloadProgress : float&;
                                                                            var phys_vars : PhysVars;
                                                                            var anim_phys : AnimatedPhys;
                                                                            var animchar : AnimcharBaseComponent;
                                                                            var animchar_node_wtm : AnimcharNodesMat44&;
                                                                            var animchar_render__root_pos : vec4f&)
  if gun_boxed_ammo_reload__reloadState != int(BoxedAmmoReloadState.NONE)
    return

  // reload was finished or aborted, so gun should be in aim state
  setVar(phys_vars, gun_anim__singleReloadStateVarId, float(gun_anim__singleReloadStates[int(BoxedAmmoReloadState.NONE) + 1]))
  setVar(phys_vars, gun_anim__unloadStateVarId, float(gun_anim__unloadStates[int(BoxedAmmoReloadState.NONE) + 1]))
  gun_anim__reloadProgress = 0.f
  setVar(phys_vars, gun_anim__reloadVarId, gun_anim__reloadProgress)
  setVar(phys_vars, gun_anim__singleReloadVarId, gun_anim__reloadProgress)
  setVar(phys_vars, gun_anim__unloadVarId, gun_anim__reloadProgress)

  anim_phys |> anim_phys_update(animchar, phys_vars)
  animchar |> animchar_act(0.f, true)
  animchar |> animchar_copy_nodes(animchar_node_wtm, animchar_render__root_pos)


[es(tag=render, REQUIRE=gun_anim__customReloadStyleBatch, after=boxed_ammo_gun_bullet_by_bullet_reload_anim_updater_es)]
def boxed_ammo_gun_batch_reload_anim_updater_es(info : UpdateStageInfoAct&;
                                                gun_anim__singleReloadStateVarId : int;
                                                gun_anim__singleReloadStates : IntList;
                                                gun_anim__customReloadStyleEnabled : bool;
                                                animchar__visible : bool = true;
                                                var phys_vars : PhysVars)
  if !animchar__visible
    return
  if !gun_anim__customReloadStyleEnabled
    return

  setVar(phys_vars, gun_anim__singleReloadStateVarId, float(gun_anim__singleReloadStates[int(BoxedAmmoReloadState.NONE) + 1]))


[es(tag=render, REQUIRE=gun_anim__customReloadStyleBatch, before=common_gun_anim_updater_es, after=(human_weap_anim_es, set_boxed_ammo_bullet_by_bullet_reload_anim_progress_to_current_gun))]
def set_boxed_ammo_batch_reload_anim_progress_to_current_gun(info : UpdateStageInfoAct;
                                                             gun_anim__customReloadStyleEnabled : bool;
                                                             gun_boxed_ammo_reload__reloadState : int;
                                                             var gun_anim__reloadProgress : float&)
  if gun_boxed_ammo_reload__reloadState == int(BoxedAmmoReloadState.NONE)
    return
  if !gun_anim__customReloadStyleEnabled
    return

  // reloadProgress should be clamped to interval [0.01, 0.98], cause reloadProgress in intervals [-2, 0.01) || [0.99, 1)
  // sets boltaction instead of actual reload animation (see reload animtree), but simply removing "boltaction" node
  // outta "~~reload_chooser" anim node will break cockpits actions during shooting (e.g. toz b)
  // TODO: rework boxed ammo reload animtree and bolt states, so that "reload_progress" var will actually change
  // only reload progress (as its name implies)
  let reloadStart = 0.01
  let reloadEnd = 0.98

  if gun_boxed_ammo_reload__reloadState == int(BoxedAmmoReloadState.PREPARE)
    gun_anim__reloadProgress = reloadStart
  elif gun_boxed_ammo_reload__reloadState == int(BoxedAmmoReloadState.LOOP)
    gun_anim__reloadProgress = clamp(gun_anim__reloadProgress, reloadStart, reloadEnd)
  elif gun_boxed_ammo_reload__reloadState == int(BoxedAmmoReloadState.POST)
    // set reloadProgress to boltaction instead of reload animation, so cockpits states can be enforced depending on gun__ammo
    // (see gun_anim__curNumAmmoVarId)
    gun_anim__reloadProgress = 0.0
