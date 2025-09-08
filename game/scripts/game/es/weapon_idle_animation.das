require ecs
require app
require PhysVars
require DagorRandom
require game.es.human.human_gun_common


[es(on_appear)]
def weapon_idle_anim_init(evt : Event;
                          weapon_idle_anim__timeBetweenIdlesRng : float2;
                          var weapon_idle_anim__idleActionVarId, weapon_idle_anim__idleTypeVarId : int&;
                          var phys_vars : PhysVars;
                          var weapon_idle_anim__nextIdleAt : float&)
  weapon_idle_anim__idleActionVarId = registerVar(phys_vars, "idle", 0.f)
  weapon_idle_anim__idleTypeVarId = registerVar(phys_vars, "idle_type", 0.f)
  assume timeRng = weapon_idle_anim__timeBetweenIdlesRng
  weapon_idle_anim__nextIdleAt = get_sync_time() + rnd_float(timeRng.x, timeRng.y)


[es(tag=render, after=common_gun_anim_updater_es, REQUIRE=(attachedToParent, gun), REQUIRE_NOT=(sleeping_weapon, gun_anim_v2__operationProgressVarId))]
def weapon_idle_anim_updater(act : UpdateStageInfoAct&;
                             gun__owner : EntityId;
                             weapon_idle_anim__timeBetweenIdlesRng, weapon_idle_anim__idleTimeRng : float2;
                             weapon_idle_anim__idleActionVarId, weapon_idle_anim__idleTypeVarId : int;
                             gun_anim__boltActionVarId : int;
                             gun_anim__ammoInspectionProgressVarId : int;
                             gun_anim__reloadVarId : int;
                             weapon_idle_anim__idleTypesCount : int;
                             var weapon_idle_anim__nextIdleAt : float&;
                             var phys_vars : PhysVars;
                             var weapon_idle_anim__curIdleTime, weapon_idle_anim__targetIdleTime : float&;
                             animchar__visible : bool = true)
  if !animchar__visible || weapon_idle_anim__idleActionVarId == -1
    return
  if act.curTime < weapon_idle_anim__nextIdleAt
    return

  assume idleTimeRng = weapon_idle_anim__idleTimeRng
  assume timeRng = weapon_idle_anim__timeBetweenIdlesRng

  let boltActionProgress = phys_vars |> getVar(gun_anim__boltActionVarId)
  let reloadProgress = phys_vars |> getVar(gun_anim__reloadVarId)
  if ((boltActionProgress > 0.0 && boltActionProgress < 1.0) || phys_vars |> getVar(gun_anim__ammoInspectionProgressVarId) != 0.0
      || (reloadProgress > 0.0 && reloadProgress < 1.0))
    weapon_idle_anim__nextIdleAt = act.curTime + rnd_float(timeRng.x, timeRng.y)
    setVar(phys_vars, weapon_idle_anim__idleTypeVarId, float(rnd_int(0, weapon_idle_anim__idleTypesCount)))
    setVar(phys_vars, weapon_idle_anim__idleActionVarId, 0.0)
    return

  if weapon_idle_anim__curIdleTime == 0.0
    weapon_idle_anim__targetIdleTime = rnd_float(idleTimeRng.x, idleTimeRng.y)
  elif weapon_idle_anim__curIdleTime >= weapon_idle_anim__targetIdleTime
    weapon_idle_anim__curIdleTime = 0.0
    weapon_idle_anim__nextIdleAt = act.curTime + rnd_float(timeRng.x, timeRng.y)
    setVar(phys_vars, weapon_idle_anim__idleTypeVarId, float(rnd_int(0, weapon_idle_anim__idleTypesCount)))
    weapon_idle_anim__curIdleTime = -act.dt
  weapon_idle_anim__curIdleTime += act.dt

  var isHoldBreath = false
  query(gun__owner) <| $ [es] (human_net_phys__isHoldBreath : bool)
    isHoldBreath = human_net_phys__isHoldBreath
  if isHoldBreath
    setVar(phys_vars, weapon_idle_anim__idleActionVarId, 0.0)
    weapon_idle_anim__curIdleTime = weapon_idle_anim__targetIdleTime
  else
    let value = clamp(weapon_idle_anim__curIdleTime / weapon_idle_anim__targetIdleTime, 0.0, 1.0)
    setVar(phys_vars, weapon_idle_anim__idleActionVarId, sin(PI * value))


[es(tag=render, after=gun_animate_operation_progress, REQUIRE=(attachedToParent, gun), REQUIRE_NOT=sleeping_weapon)]
def weapon_idle_anim_updater_v2(act : UpdateStageInfoAct&;
                                eid, gun__owner : EntityId;
                                weapon_idle_anim__timeBetweenIdlesRng, weapon_idle_anim__idleTimeRng : float2;
                                weapon_idle_anim__idleTypeVarId : int;
                                gun_anim_v2__operationProgressVarId : int;
                                weapon_idle_anim__idleTypesCount : int;
                                gun_anim_v2__currentOperationState : int;
                                var weapon_idle_anim__nextIdleAt : float&;
                                var phys_vars : PhysVars;
                                var weapon_idle_anim__curIdleTime, weapon_idle_anim__targetIdleTime : float&;
                                animchar__visible : bool = true)
  if !animchar__visible
    return
  if gun_anim_v2__currentOperationState != int(GunOperationState.IDLE) && act.curTime < weapon_idle_anim__nextIdleAt
    return

  assume idleTimeRng = weapon_idle_anim__idleTimeRng
  assume timeRng = weapon_idle_anim__timeBetweenIdlesRng
  weapon_idle_anim__nextIdleAt = act.curTime + rnd_float(timeRng.x, timeRng.y)

  var possibleStartIdle = true
  query(gun__owner) <| $[es] (human_net_phys__isAiming : bool;
                              human_weap__lastShotAtTime : float;
                              action__running : bool)
    possibleStartIdle = !human_net_phys__isAiming && act.curTime - human_weap__lastShotAtTime > 1.f && !action__running
  if !possibleStartIdle
    set_weapon_operation_state(int(GunOperationState.BOLTACTION), eid)
    return
  let operationProgress = phys_vars |> getVar(gun_anim_v2__operationProgressVarId)
  if gun_anim_v2__currentOperationState == int(GunOperationState.BOLTACTION) && operationProgress == 0.0 || operationProgress == 1.0
    set_weapon_operation_state(int(GunOperationState.IDLE), eid)
    setVar(phys_vars, weapon_idle_anim__idleTypeVarId, float(rnd_int(0, weapon_idle_anim__idleTypesCount)))

  elif gun_anim_v2__currentOperationState == int(GunOperationState.IDLE)
    if weapon_idle_anim__curIdleTime == 0.0
      weapon_idle_anim__targetIdleTime = rnd_float(idleTimeRng.x, idleTimeRng.y)
    elif weapon_idle_anim__curIdleTime >= weapon_idle_anim__targetIdleTime
      weapon_idle_anim__curIdleTime = 0.0
      set_weapon_operation_state(int(GunOperationState.BOLTACTION), eid)
      return
    weapon_idle_anim__curIdleTime += act.dt

    var isHoldBreath = false
    query(gun__owner) <| $ [es] (human_net_phys__isHoldBreath : bool)
      isHoldBreath = human_net_phys__isHoldBreath
    let value = isHoldBreath ? 0.0 : clamp(weapon_idle_anim__curIdleTime / weapon_idle_anim__targetIdleTime, 0.0, 1.0)
    setVar(phys_vars, gun_anim_v2__operationProgressVarId, value)

