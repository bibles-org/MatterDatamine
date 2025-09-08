require ecs
require DngNet
require AnimV20
require Dacoll
require PhysObj
require PhysMat
require CollRes
require PhysDecl
require RendInst
require GamePhys
require Ballistics
require DngWeapon
require DngPhysObj
require DagorMath
require DagorRandom
require GeomNodeTree
require game.events.events
require active_matter.game.es.rendinst_attach_common
require game.events.events_game
require game.events.events_active_matter
require DagorSystem


def is_stuck(fly_dir, norm : float3; mat_id : int; stuckParams : ecs::Object) : bool
  for it in stuckParams
    let matId = get_material_id(it.key)
    if matId == mat_id
      let stuckMinDot = get_float(it.value) ?? -1.0
      return -dot(fly_dir, norm) > stuckMinDot
  return false


[es(after=update_projectile_es, before=before_animchar_update_sync, REQUIRE=crossbow_bolt)]
def crossbow_bolt_fly_es(info : ParallelUpdateFrameDelayed;
                         var transform : float3x4;
                         projectile_ballistics : ProjectileBallistics;
                         projectile__stopped : bool)
  if !projectile__stopped
    let flyDir = normalize(projectile_ballistics.state.vel)
    let q = dir_to_quat(flyDir)
    make_tm(q, projectile_ballistics.state.pos, transform)


[es(tag=server, REQUIRE=crossbow_bolt)]
def crossbow_bolt_stuck_es(evt : EventProjectileHitScene;
                           projectile_ballistics : ProjectileBallistics;
                           var projectile__stopped : bool&;
                           crossbow_bolt__stuckParams : ecs::Object;
                           crossbow_bolt__stuckPickableChance : float;
                           crossbow_bolt__stuckPickableTemplate : string;
                           crossbow_bolt__stuckUnpickableTemplate : string;
                           crossbow_bolt__stuckShiftBack : float = 0.12)
  let flyDir = normalize(projectile_ballistics.state.vel)
  if is_stuck(flyDir, evt.norm, evt.matId, crossbow_bolt__stuckParams)
    projectile__stopped = true
    var riexEid = INVALID_ENTITY_ID
    var riexDestroyable = false
    var riexRotatable = false
    using(evt.rendinstCellIdx,
          evt.rendinstIdx,
          evt.rendinstPool,
          evt.rendinstOffs,
          evt.rendinstLayer) <| $(var riDesc : RendInstDesc#)
      let appendTemplates = get_riex_attach_append_templates(riDesc, riexEid, riexDestroyable, riexRotatable)
      let pickable = gfrnd() < crossbow_bolt__stuckPickableChance
      let stuckTemplate = pickable ? crossbow_bolt__stuckPickableTemplate : crossbow_bolt__stuckUnpickableTemplate

      createEntity(stuckTemplate + appendTemplates)  <| $(var init)
        var tm : float3x4
        let q = dir_to_quat(flyDir)
        make_tm(q, evt.pos, tm)
        tm[3] -= flyDir * crossbow_bolt__stuckShiftBack
        set(init, "transform", tm)
        if riexDestroyable
          set(init, "rendinst_attach__riexHandle", uint64(riDesc.riExtraHandle))
        if riexRotatable
          let riexTm = get_TMatrix(riexEid, "transform")
          if riexTm != null
            set(init, "rendinst_attach__riexEid", riexEid)
            set(init, "rendinst_attach__localTm", inverse(*riexTm) * tm)


[es(tag=server)]
def crossbow_bolt_stuck_human_es(evt : EventOnProjectileHit;
                                 eid : EntityId;
                                 transform aka human_transform : float3x4;
                                 animchar : AnimcharBaseComponent;
                                 collres : CollisionResource;
                                 human : Tag const?;
                                 changed : Tag const?;
                                 flowerHuman : Tag const?)
  if human == null && changed == null && flowerHuman == null
    return

  ecs::query(evt.projectileEid) <| $ [es(REQUIRE=crossbow_bolt)] (projectile_ballistics : ProjectileBallistics;
                                                                  var projectile__stopped : bool&;
                                                                  crossbow_bolt__stuckHumanTemplate : string;
                                                                  crossbow_bolt__stuckShiftBack : float = 0.12;
                                                                  var transform : float3x4)
    let flyDir = normalize(projectile_ballistics.state.vel)
    projectile__stopped = true
    transform[3] = get_hidden_pos()

    createEntity(crossbow_bolt__stuckHumanTemplate)  <| $(var init)
      var tm, ntm : float3x4
      let q = dir_to_quat(flyDir)
      make_tm(q, evt.hitPos, tm)
      let node = collres_get_node(collres, evt.collNodeId)
      if node != null
        collres_get_collision_node_tm(collres, evt.collNodeId, human_transform, animchar.nodeTree, ntm)
      else
        identity(ntm)
      tm[3] -= flyDir * crossbow_bolt__stuckShiftBack
      set(init, "crossbow_bolt_in_human__eid", eid)
      set(init, "crossbow_bolt_in_human__nodeId", evt.collNodeId)
      set(init, "crossbow_bolt_in_human__localTm", inverse(ntm) * tm)


[es(tag=gameClient, after=after_animchar_update_sync, REQUIRE=crossbow_bolt)]
def crossbow_bolt_in_human_es(info : UpdateStageInfoAct;
                              var transform aka bolt_transform : float3x4;
                              crossbow_bolt_in_human__eid : EntityId;
                              crossbow_bolt_in_human__nodeId : int;
                              crossbow_bolt_in_human__localTm : float3x4)
  ecs::query(crossbow_bolt_in_human__eid) <| $ [es] (transform : float3x4;
                                                     animchar : AnimcharBaseComponent;
                                                     collres : CollisionResource)
    let node = collres_get_node(collres, crossbow_bolt_in_human__nodeId)
    if node != null
      var ntm : float3x4
      collres_get_collision_node_tm(collres, crossbow_bolt_in_human__nodeId, transform, animchar.nodeTree, ntm)
      bolt_transform = ntm * crossbow_bolt_in_human__localTm
      return


[es(tag=gameClient, REQUIRE=crossbow_bolt)]
def crossbow_bolt_stuck_destroy_client_copy_es(evt : EventProjectileHitScene;
                                               eid : EntityId;
                                               projectile_ballistics : ProjectileBallistics;
                                               crossbow_bolt__stuckParams : ecs::Object)
  let flyDir = normalize(projectile_ballistics.state.vel)
  if is_stuck(flyDir, evt.norm, evt.matId, crossbow_bolt__stuckParams)
    destroyEntity(eid)


[es(tag=gameClient)]
def crossbow_bolt_stuck_in_human_destroy_client_copy_es(evt : EventOnProjectileHit;
                                                        human : Tag const?;
                                                        changed : Tag const?;
                                                        flowerHuman : Tag const?)
  if human == null && changed == null && flowerHuman == null
    return
  if has(evt.projectileEid, "crossbow_bolt")
    destroyEntity(evt.projectileEid)


[es(tag=render, REQUIRE=crossbow_bolt, track=projectile__stopped, REQUIRE_NOT=ragdoll)]
def crossbow_bolt_unstuck_es(evt : Event;
                             eid : EntityId;
                             projectile__stopped : bool;
                             crossbow_bolt__unstuckTemplate : string;
                             var transform : float3x4;
                             projectile_ballistics : ProjectileBallistics;
                             scene_hit_place__pos : float3;
                             crossbow_bolt__unstuckShiftBack : float = 0.6)
  if !projectile__stopped
    return
  let flyDir = normalize(projectile_ballistics.state.vel)
  reCreateEntityFrom(eid, crossbow_bolt__unstuckTemplate)  <| $(var init)
    set(init, "ragdoll__start_vel", flyDir)
  transform[3] = scene_hit_place__pos - crossbow_bolt__unstuckShiftBack * flyDir


[es(tag=render, on_appear, REQUIRE=crossbow_bolt)]
def crossbow_bolt_start_ragdoll_es(evt : Event; var ragdoll : PhysRagdoll; var animchar : AnimcharBaseComponent; transform : float3x4)
  if distance_sq(transform[3], get_hidden_pos()) > 1.0
    ragdoll_startRagdoll(ragdoll, 1, -1, animchar.nodeTree)
    animchar |> animchar_setPostController(ragdoll)


[es(tag=gameClient, on_appear, after=projectile_phys_created_es, REQUIRE=crossbow_bolt)]
def crossbow_bolt_created_es(evt : Event;
                             eid : EntityId;
                             var projectile__maxLifeTime : float&;
                             crossbow_bolt__unstuckedLifetime : float;
                             crossbow_bolt__appendOnCreate : string = "")
  projectile__maxLifeTime = crossbow_bolt__unstuckedLifetime
  if crossbow_bolt__appendOnCreate != ""
    addSubTemplate(eid, crossbow_bolt__appendOnCreate)
