require ecs
require app
require math.random
require math.base
require game.events.events
require game.events.events_active_matter
require game.es.stalker_statue_common
require game.es.riextra_damage_common
require danetlibs.pathfinder.main.pathfinder_common
require danetlibs.navmesh_phys.main.nphys_find_obstacles_common
require AnimV20
require GeomNodeTree
require DagorMath
require DagorMathUtils
require DagorSystem
require RiDestr
require RendInst
require Grid


[es(tag=server, on_appear)]
def init_statue_origin(evt : Event; var stalker_statue__origin, stalker_statue__prevTm : float3x4; transform : float3x4)
  stalker_statue__origin = transform
  stalker_statue__prevTm = transform


[es(tag=server, on_appear, REQUIRE=heroForPlayer)]
def server_cam_node_init(evt : Event; animchar : AnimcharBaseComponent; human_cam__camNodeName : string; var human_cam__camNodeId : int&)
  human_cam__camNodeId = geomtree_findNodeIndex(*animchar.nodeTree, human_cam__camNodeName)


[es(tag=server, no_order)]
def sleeping_statue_es(act : UpdateStageInfoAct;
                       eid : EntityId;
                       transform aka s_transform : float3x4;
                       stalker_statue__searchRadius : float;
                       sleeping_statue__interval : float;
                       var sleeping_statue__updateAt : float&)
  if act.curTime > sleeping_statue__updateAt
    sleeping_statue__updateAt = act.curTime + sleeping_statue__interval
    let radiusSq = square(stalker_statue__searchRadius)
    find_query() <| $ [es(REQUIRE=stalkerStatueTarget, REQUIRE_NOT=(stalkerStatue_Not_Target, deadEntity))
        ] (transform aka t_transform : float3x4)
      if distance_sq(t_transform[3], s_transform[3]) < radiusSq
        removeSubTemplate(eid, "sleeping_statue_tmpl")
        return true
      return false


[es(tag=netClient)]
def update_statue_pos_on_client(evt : EventStatueMove; eid : EntityId; var transform : float3x4)
  let prevTm := transform
  transform[3] = evt.pos
  transform[0] = normalize(float3(evt.look.x, .0, evt.look.y))
  transform[2] = cross(transform[0], transform[1])
  if evt.duration > .0
    sendEvent(eid, EventSnapshotBlink(from = prevTm, to = transform, dt = evt.duration))


[es(tag=(server, gameClient))]
def stalker_statue_blink_offline(evt : EventStatueMove; eid : EntityId; transform : float3x4; var stalker_statue__prevTm : float3x4)
  if evt.duration > .0
    sendEvent(eid, EventSnapshotBlink(from = stalker_statue__prevTm, to = transform, dt = evt.duration))
  stalker_statue__prevTm = transform


[es(tag=gameClient, on_event=EventStatueAttacked)]
def spawn_statue_attack_fx(evt : Event;
                           stalker_statue__attackFx : string;
                           stalker_statue__angleVariation : float2;
                           stalker_statue__attackFrom : float3;
                           transform : float3x4)
  let origin = transform * stalker_statue__attackFrom
  let angle = rnd_float(stalker_statue__angleVariation)
  for i in range(4)
    let q = quat(transform[0], angle - float(i) * 0.1)
    var tm = transform
    tm[0] = q * tm[0]
    tm[1] = q * tm[1]
    tm[2] = q * tm[2]
    tm[3] = origin
    createEntity(stalker_statue__attackFx) <| $(init)
      init |> set("transform", tm)
      init |> set("statue_fx__attackOrigin", origin)
      init |> set("statue_fx__startedAt", get_sync_time() + float(i) * 0.05)


[es(tag=gameClient, no_order)]
def statue_attack_fx_update(act : UpdateStageInfoAct;
                            eid : EntityId;
                            statue_fx__attackOrigin : float3;
                            statue_fx__attackRadius : float;
                            statue_fx__attackDuration : float;
                            statue_fx__startedAt : float;
                            var transform : float3x4)
  if act.curTime < statue_fx__startedAt
    return
  if act.curTime > statue_fx__startedAt + statue_fx__attackDuration
    destroyEntity(eid)
    return
  let r = (act.curTime - statue_fx__startedAt) / statue_fx__attackDuration
  let q = quat(transform[2], lerp(0.25, -PI * 0.85, r))
  transform[3] = statue_fx__attackOrigin + q * transform[1] * statue_fx__attackRadius


[es(tag=server, REQUIRE=cairn_trap)]
def on_cair_stone_destroyed(evt : EventRiExtraDestroyed;
                            transform : float3x4;
                            cairn_trap__spawnerTemplate : string;
                            cairn_trap__templates : StringList;
                            cairn_trap__spawnCount : int2)
  let count = rnd_int(cairn_trap__spawnCount)
  for _ in range(count)
    createEntity(cairn_trap__spawnerTemplate) <| $(var init)
      init |> set("transform", transform)
      init |> set("statue_spawner__template", cairn_trap__templates[grnd() % length(cairn_trap__templates)])


[es(tag=server, on_appear)]
def init_stalker_statue_spawner(evt : Event;
                                statue_spawner__template : string;
                                var statue_spawner__stalker_statue__traceDstThresholdsSq : float4&;
                                var statue_spawner__stalker_statue__zoomVisionDstMulti : float&;
                                var statue_spawner__stalker_statue__zoomVisionDotMulti : float&;
                                var statue_spawner__stalker_statue__highPrecisionDot : float&;
                                var statue_spawner__stalker_statue__traceBudget : int&;
                                var statue_spawner__stalker_statue__maxVisionDot : float&;
                                var statue_spawner__stalker_statue__boundingPoints : Point3List)
  var templ = getTemplateByName(statue_spawner__template)
  if templ == null
    templ = buildTemplateByName(statue_spawner__template)
  if templ == null
    logerr("Statue spawner can't get template '{statue_spawner__template}'.")
    return
  statue_spawner__stalker_statue__traceDstThresholdsSq = get_Point4(getTemplateComponent(*templ, "stalker_statue__traceDstThresholdsSq")) ?? float4()
  statue_spawner__stalker_statue__zoomVisionDstMulti = get_float(getTemplateComponent(*templ, "stalker_statue__zoomVisionDstMulti")) ?? .0
  statue_spawner__stalker_statue__zoomVisionDotMulti = get_float(getTemplateComponent(*templ, "stalker_statue__zoomVisionDotMulti")) ?? .0
  statue_spawner__stalker_statue__highPrecisionDot = get_float(getTemplateComponent(*templ, "stalker_statue__highPrecisionDot")) ?? .0
  statue_spawner__stalker_statue__traceBudget = get_int(getTemplateComponent(*templ, "stalker_statue__traceBudget")) ?? 0
  statue_spawner__stalker_statue__maxVisionDot = get_float(getTemplateComponent(*templ, "stalker_statue__maxVisionDot")) ?? .0
  let tmp = get_ecs_Point3List(getTemplateComponent(*templ, "stalker_statue__boundingPoints"))
  if tmp != null
    statue_spawner__stalker_statue__boundingPoints := *tmp


[es(tag=server, no_order)]
def stalker_statue_spawner(act : UpdateStageInfoAct;
                           eid : EntityId;
                           transform : float3x4;
                           statue_spawner__radius : float2;
                           statue_spawner__template : string;
                           statue_spawner__interval : float;
                           statue_spawner__stalker_statue__traceDstThresholdsSq : float4;
                           statue_spawner__stalker_statue__zoomVisionDstMulti : float;
                           statue_spawner__stalker_statue__zoomVisionDotMulti : float;
                           statue_spawner__stalker_statue__highPrecisionDot : float;
                           statue_spawner__stalker_statue__traceBudget : int;
                           statue_spawner__stalker_statue__maxVisionDot : float;
                           statue_spawner__stalker_statue__boundingPoints : Point3List;
                           var statue_spawner__updateAt : float&;
                           var statue_spawner__attemptsLeft : int&)
  if statue_spawner__updateAt < act.curTime
    statue_spawner__updateAt = act.curTime + statue_spawner__interval
    statue_spawner__attemptsLeft--
    let pos = find_statue_spawn_point(transform[3], statue_spawner__radius,
                                      statue_spawner__stalker_statue__traceDstThresholdsSq,
                                      statue_spawner__stalker_statue__zoomVisionDstMulti,
                                      statue_spawner__stalker_statue__zoomVisionDotMulti,
                                      statue_spawner__stalker_statue__highPrecisionDot,
                                      statue_spawner__stalker_statue__traceBudget,
                                      statue_spawner__stalker_statue__maxVisionDot,
                                      statue_spawner__stalker_statue__boundingPoints)
    if pos is pos
      createEntity(statue_spawner__template) <| $(var init)
        var tm = IDENT_TM
        tm[3] = pos as pos
        init |> set("transform", tm)
        destroyEntity(eid)
    if statue_spawner__attemptsLeft <= 0
      destroyEntity(eid)


def find_statue_spawn_point(origin : float3; radius : float2;
                            stalker_statue__traceDstThresholdsSq : float4;
                            stalker_statue__zoomVisionDstMulti : float;
                            stalker_statue__zoomVisionDotMulti : float;
                            stalker_statue__highPrecisionDot : float;
                            stalker_statue__traceBudget : int;
                            stalker_statue__maxVisionDot : float;
                            stalker_statue__boundingPoints : Point3List) : MaybePos const
  let navPoint = get_lower_navmesh_pos_in_radius(origin, radius.y) <| $(pos)
    return distance_sq(pos, origin) > square(radius.x)
  if navPoint is pos
    var tm = IDENT_TM
    tm[3] = navPoint as pos
    if !test_statue_visible(tm,
                            stalker_statue__traceDstThresholdsSq,
                            stalker_statue__zoomVisionDstMulti,
                            stalker_statue__zoomVisionDotMulti,
                            stalker_statue__highPrecisionDot,
                            stalker_statue__traceBudget,
                            stalker_statue__maxVisionDot,
                            stalker_statue__boundingPoints,
                            true)
      return navPoint
  return MaybePos()


[es(tag=server, REQUIRE=cairn_trap)]
def cairn_stone_on_impulse(evt : EventRendinstImpulse; ri_extra : RiExtraComponent)
  damage_ri_on_server(ri_extra.handle, 100.0, evt.impulsePos, evt.impulseDir, get_sync_time(), EntityId(uint(evt.userData)))


[es(tag=server, REQUIRE=cairn_trap)]
def cairn_stone_on_trap_trigger(evt : EventTrapTrigger;
                                eid : EntityId;
                                transform aka trap_transform : float3x4;
                                ri_extra : RiExtraComponent)
  query(evt.activatorEid) <| $[es] (transform aka activator_transform : float3x4)
    damage_ri_on_server(ri_extra.handle, 100.0, activator_transform[3], normalize(trap_transform[3] - activator_transform[3]), get_sync_time(), eid)


[es(tag=server)]
def destroy_doors_on_statue_move(evt : EventStatueMove;
                                 eid : EntityId;
                                 transform aka statue_transform : float3x4;
                                 stalker_statue__lastCoveredPath : Point3List)
  if length(stalker_statue__lastCoveredPath) == 0 || evt.duration == .0
    return
  let qBox = setup_obstacle_bbox_from_path(stalker_statue__lastCoveredPath,
                                            stalker_statue__lastCoveredPath[0],
                                            1.0, 2.0, 1.0, FLT_MAX)
  for_each_entity_in_grid(ecs_hash("doors"), qBox, GridEntCheck.POS) <| $(door_eid : EntityId)
    query(door_eid) <| $ [es] (ri_extra : RiExtraComponent; transform aka door_transform : float3x4)
      let riType = handle_to_ri_type(ri_extra.handle)
      let riCollres = get_ri_gen_extra_collres(int(riType))
      if riCollres == null
        return
      var box = BBox3()
      box |> bbox3f_to_scalar_bbox3(riCollres.vFullBBox)
      let invTm = inverse(door_transform)

      var prev = stalker_statue__lastCoveredPath[0]
      for i in range(1, length(stalker_statue__lastCoveredPath))
        let delta = stalker_statue__lastCoveredPath[i] - prev
        let t = length(delta)
        let dir = delta * safeinv(t)
        let from = prev + statue_transform[1]
        let p1 = invTm * from
        let p2 = invTm * stalker_statue__lastCoveredPath[i] + statue_transform[1]
        if test_segment_box_intersection(p1, p2, box)
          damage_ri_on_server(ri_extra.handle, 10000.0, from, dir, get_sync_time(), eid)
          return
        prev = stalker_statue__lastCoveredPath[i]


[es(tag=server, on_appear)]
def init_statue_poses(evt : Event;
                      animchar : AnimcharBaseComponent;
                      stalker_statue__poseNames : StringList;
                      var stalker_statue__poseIds : IntList)
  let animGraph = animchar.animGraph
  if animGraph != null
    for nm in stalker_statue__poseNames
      stalker_statue__poseIds |> push(*animGraph |> anim_graph_getStateIdx(string(nm)))


[es(tag=server)]
def change_statue_pose_on_move(evt : EventStatueMove;
                               stalker_statue__poseIds : IntList;
                               var animchar : AnimcharBaseComponent)
  var animGraph = animchar.animGraph
  if length(stalker_statue__poseIds) == 0 || animGraph == null
    return
  let state = stalker_statue__poseIds[grnd() % length(stalker_statue__poseIds)]
  *animGraph |> anim_graph_enqueueState(*animchar.animState, state)


[es(tag=gameClient, track=isAlive)]
def on_death_statue_client(evt : Event;
                           isAlive : bool;
                           eid aka stalker_statue_eid : EntityId;
                           stalker_statue__deathFx : string;
                           var animchar_render__enabled : bool&)
  if !isAlive
    animchar_render__enabled = true
    createEntity(stalker_statue__deathFx) <| $(var init : ComponentsInitializer)
      init |> set("game_effect__attachedTo", stalker_statue_eid)


[es(tag=server, no_order, REQUIRE=deadEntity)]
def update_death_statue_status_server(info : ParallelUpdateFrameDelayed;
                                      eid aka statue_eid : EntityId;
                                      stalker_statue__destroyTimer : float;
                                      var stalker_statue__destroyEntityAt : float&)
  if stalker_statue__destroyEntityAt < 0.f
    stalker_statue__destroyEntityAt = info.curTime + stalker_statue__destroyTimer
  elif stalker_statue__destroyEntityAt < info.curTime
    destroyEntity(statue_eid)