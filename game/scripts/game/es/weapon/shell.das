require ecs
require ecs.common
require DngNet
require zones
require game.events.events_game
require game.events.events_active_matter
require game.es.grenade_thrower_common
require game.es.human_weap_common
require game.events.events
require AnimV20
require GeomNodeTree
require DagorMath
require DagorSystem
require DaWeaponProps
require Dacoll
require DngWeapon
require DngHuman


def explode_local_shell(shell_id : EntityId;
                        shell_owner : EntityId)
  // On explosion local shell should be silently destroyed without any side-effects
  destroyEntity(shell_id)
  query(shell_owner) <| $ [es] (var human_weap__localProjectilePhysEid : EntityId?;
                                var human_weap__localProjectileEid : EntityId?)
    if human_weap__localProjectilePhysEid != null && *human_weap__localProjectilePhysEid == shell_id
      *human_weap__localProjectilePhysEid = INVALID_ENTITY_ID
    elif human_weap__localProjectileEid != null && *human_weap__localProjectileEid == shell_id
      *human_weap__localProjectileEid = INVALID_ENTITY_ID


[es(tag=server, on_appear)]
def shell_created_es(evt : Event;
                     eid : EntityId;
                     shell__expl_node : string;
                     animchar : AnimcharBaseComponent;
                     var shell__explNodeIdx : int&)
  shell__explNodeIdx = *animchar.nodeTree |> geomtree_findNodeIndex(shell__expl_node)
  if shell__explNodeIdx < 0
    logerr("{getEntityTemplateName(eid)} shell.explNodeIdx < 0 (shell__expl_node={shell__expl_node})")
    destroyEntity(eid)


[es(tag=server)]
def shell_expl_es(evt : CmdShellExplode;
                  eid : EntityId;
                  shell__shell_id__shell_id : int;
                  shell__shell_id__damage_id : int;
                  shell__shell_id__ballistics_id : int;
                  shell__gun_props_id : int;
                  shell__owner : EntityId;
                  shell__rethrower : EntityId = INVALID_ENTITY_ID)

  using() <| $(var shellId : ShellPropIds#)
    shellId.shellId = int16(shell__shell_id__shell_id)
    shellId.damageId = int16(shell__shell_id__damage_id)
    shellId.ballisticsId = int16(shell__shell_id__ballistics_id)

    let normal = float3()
    detonate_shell_server(eid, shellId, shell__gun_props_id, evt.position,
                          shell__owner, evt.prevPos, evt.vel, INVALID_ENTITY_ID,
                          normal, shell__rethrower)

  // Detect that we exploded in gun
  if shell__owner != INVALID_ENTITY_ID
    clear_projectile_entity(shell__owner, eid)
  destroyEntity(eid)


[es(tag=netClient, REQUIRE=clientSide)]
def local_shell_expl_es(evt : CmdShellExplode;
                        eid : EntityId;
                        shell__owner : EntityId)
  explode_local_shell(eid, shell__owner)


[es(tag=server)]
def shell_expl_disorientated_es(evt : CmdShellExplode;
                                disorientated__tinnitusRad : float2;
                                disorientated__tinnitusPower : float2;
                                disorientated__flashRad : float2 = float2();
                                disorientated__flashPower : float2 = float2();
                                disorientated__flashDistExp : float = 1.0;
                                disorientated__tinnitusDistExp : float = 1.0)
  find_query() <| $ [es(REQUIRE=msg_sink)] (eid : EntityId)
    sendEvent(
      eid,
      EventFlashExploded(
        pos = evt.position,
        tinnitusRad = disorientated__tinnitusRad,
        flashRad = disorientated__flashRad,
        tinnitusPower = disorientated__tinnitusPower,
        flashPower = disorientated__flashPower,
        flashDistExp = disorientated__flashDistExp,
        tinnitusDistExp = disorientated__tinnitusDistExp,
        ignoreEid = INVALID_ENTITY_ID))
    return true


[es(tag=server, no_order)]
def shell_es(info : ParallelUpdateFrameDelayed;
             eid : EntityId;
             shell__explNodeIdx : int;
             animchar : AnimcharBaseComponent;
             shell__explTime : float;
             var active : bool&)
  if info.curTime < shell__explTime || !active
    return

  let pos = *animchar.nodeTree |> geomtree_getNodeWpos(shell__explNodeIdx)
  active = false
  sendEvent(
    eid,
    CmdShellExplode(
      position = pos,
      prevPos = float3(),
      vel = float3()))


[es(tag=netClient, no_order, REQUIRE=clientSide)]
def destroy_client_shell_es(info : ParallelUpdateFrameDelayed;
                            eid : EntityId;
                            shell__explTime : float;
                            shell__launchAtTime : float;
                            shell__owner : EntityId)
  var shouldExplode = false

  if has(eid, "phys_obj_net_phys") && shell__explTime != 0.f && info.curTime >= shell__explTime
    shouldExplode = true

  if info.curTime >= (shell__launchAtTime + 1.f)
    shouldExplode = true

  if shouldExplode
    explode_local_shell(eid, shell__owner)


[es(tag=server, on_appear)]
def launcher_add_timer_es(evt : Event;
                          explTimeAdd : float;
                          var shell__explTime : float&)
  shell__explTime += explTimeAdd


[es(tag=server, after=shell_es, REQUIRE=retardable)]
def shell_fuse_retarder_es(info : ParallelUpdateFrameDelayed;
                           var shell__explTime : float&;
                           transform : float3x4)
  let shellPos = transform[3]
  find_query() <| $ [es] (shellFuseRetard : float;
                          transform : float3x4;
                          sphere_zone__radius : float;
                          sphere_zone__truncateBelow : float const?)
    if is_inside_truncated_sphere_zone(shellPos, transform, sphere_zone__radius,
                                       sphere_zone__truncateBelow)
      shell__explTime += info.dt * (1.0 - safeinv(shellFuseRetard))
      return true
    return false


[es(no_order)]
def shell_smoke_effect_es(info : ParallelUpdateFrameDelayed;
                          shell__explTime : float;
                          shell__shell_id__shell_id : int;
                          var effect__scale : float&;
                          smokeStartTime : float;
                          smokeFadeTime : float;
                          smokeFadeScale : float;
                          clientSide : Tag const?)
  detonation_get_props(shell__shell_id__shell_id) <| $(detonationProps : DetonationProps)
    let timer = detonationProps.timer
    let startTime = shell__explTime - timer
    effect__scale = (cvt(info.curTime, startTime + smokeStartTime, startTime + smokeStartTime + smokeFadeTime, 0.0, 1.0) *
                    cvt(info.curTime, shell__explTime - timer, shell__explTime, 1.0, smokeFadeScale))

    // Local (predicted) grenade shouldn't try to produce any smoke, because it has smaller explTime (to be removed sooner)
    if (clientSide != null || info.curTime < startTime + smokeStartTime)
      effect__scale = 0.0


[es(after=shell_smoke_effect_es, REQUIRE=extinguishUnderwater)]
def shell_smoke_extinguish_underwater_es(info : ParallelUpdateFrameDelayed;
                                         transform : float3x4;
                                         var effect__scale : float&)
  if effect__scale > 0.0
    var isUnderwater = false
    traceht_water_at_time(transform[3], 5.0, info.curTime, isUnderwater)
    if isUnderwater
      effect__scale = 0.0