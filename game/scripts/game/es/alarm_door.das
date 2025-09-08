require ecs
require app
require ecs.common
require Dacoll
require DagorRandom
require DngNet
require BehNodes
require DngBehTree
require DngDm
require DagorMath
require level
require game.events.events_active_matter
require game.es.custom_region_common
require game.es.door_operations_common


[es(tag=server, no_order, REQUIRE_NOT=alarm_gen__finished)]
def create_door_alarms(act : ParallelUpdateFrameDelayed;
                       eid aka gen_eid : EntityId;
                       monster_gen__region : string;
                       alarm_gen__probability : float;
                       alarm_gen__maxLMeshHeight : float;
                       alarm_gen__doorTraces : float2;
                       alarm_gen__template : string)
  in_region_with_name(monster_gen__region) <| $(points, indicies, data)
    var processedPairs : array<EntityId>
    var count = 0
    query() <| $ [es] (eid aka door_eid : EntityId; pair_door__eid : EntityId; isDoor : bool; ri_extra : RiExtraComponent; transform : float3x4)
      count++
      if (isDoor &&
          gfrnd() < alarm_gen__probability &&
          transform[3].y - traceht_lmesh(transform[3]) < alarm_gen__maxLMeshHeight &&
          !has_value(processedPairs, door_eid) &&
          is_point_inside_region(transform[3], points, indicies, data.bbox) &&
          is_outside_door(ri_extra, transform, alarm_gen__doorTraces))
        remote_add_sub_template(door_eid, alarm_gen__template) <| $(init)
          init |> set("door_alarm__controllerEid", gen_eid)
        if pair_door__eid != INVALID_ENTITY_ID
          processedPairs |> push(pair_door__eid)
    if count > 0 //Assumes all doors are created at once
      addSubTemplate(gen_eid, "alarm_generation_finished")


def is_outside_door(ri_extra : RiExtraComponent; transform : float3x4; trace_param : float2)
  let riType = handle_to_ri_type(ri_extra.handle)
  let riCollres = get_ri_gen_extra_collres(int(riType))
  if riCollres == null
    return false
  let door_box = BBox3(riCollres.vFullBBox)
  let traceFrom = transform[3] + transform[0] * door_box.width * 0.5 + transform[1] * door_box.center.y
  let doorFrontDir = normalize(transform[2])
  let dirs = fixed_array<float3>(doorFrontDir, doorFrontDir * -1.0)
  let offset = 0.5
  let up = float3(0, 1, 0)
  for dir in dirs
    for i in range(3)
      let from = traceFrom + dir * (offset + trace_param.x * float(i))
      let t = trace_param.x * float(i + 1)
      let to = from + dir * t
      if rayhit_normalized(from, dir, t, ETF_DEFAULT, -1)
        break
      if !rayhit_normalized(to, up, trace_param.y, ETF_DEFAULT, -1)
        return true
  return false


[es(tag=server, track=door_operations__state, REQUIRE_NOT=alarm__active)]
def on_alarm_door_opened(evet : Event;
                         door_operations__state : int;
                         transform : float3x4;
                         door_alarm__duration : float;
                         door_alarm__controllerEid : EntityId;
                         door_alarm__alarmTemplate : string;
                         var door_alarm__isActivated : bool&)
  if door_operations__state == int(DoorState.OPENED) && !door_alarm__isActivated
    door_alarm__isActivated = true
    createEntity(door_alarm__alarmTemplate) <| $(init)
      init |> set("alarm__controllerEid", door_alarm__controllerEid)
      init |> set("alarm__endsAt", get_sync_time() + door_alarm__duration)
      init |> set("transform", transform)
    query(door_alarm__controllerEid) <| $ [es] (var alarm__activeCount : int&)
      alarm__activeCount++


[es(tag=server, no_order, REQUIRE=alarm__active)]
def track_door_alarm_ends(act : ParallelUpdateFrameDelayed;
                          eid : EntityId;
                          alarm__controllerEid : EntityId;
                          alarm__endsAt : float)
  if act.curTime > alarm__endsAt
    query(alarm__controllerEid) <| $ [es] (var alarm__activeCount : int&)
      alarm__activeCount--
    query() <| $ [es] (generated_monster__genEid : EntityId; var alarm__eid : EntityId&)
      if generated_monster__genEid == alarm__controllerEid && alarm__eid == eid
        alarm__eid = INVALID_ENTITY_ID
    destroyEntity(eid)


[es(tag=server, track=alarm__activeCount)]
def track_alarm_start_end(evt : Event;
                          eid : EntityId;
                          alarm__activeTemplate : string;
                          alarm__clearTemplate : string;
                          alarm__monsterWanderDuration : float;
                          alarm__active : Tag const?;
                          var clear_mosnters__updateAt : float?;
                          alarm__activeCount : int)
  if alarm__activeCount > 0 && alarm__active == null && !empty(alarm__activeTemplate)
    addSubTemplate(eid, alarm__activeTemplate)
  elif alarm__activeCount == 0 && alarm__active != null && !empty(alarm__activeTemplate)
    var tmpl = remove_sub_template_name(eid, alarm__activeTemplate)
    if clear_mosnters__updateAt == null && !empty(alarm__clearTemplate)
      tmpl = add_sub_template_name(eid, alarm__clearTemplate)
    else
      *clear_mosnters__updateAt = get_sync_time() + alarm__monsterWanderDuration
    reCreateEntityFrom(eid, tmpl) <| $(init)
      init |> set("clear_mosnters__updateAt", get_sync_time() + alarm__monsterWanderDuration)


[es(tag=server, on_appear)]
def guide_spawned_monster_to_alarm(evt : Event; generated_monster__genEid : EntityId; var alarm__eid : EntityId&)
  query() <| $ [es(REQUIRE=(alarm__active, alarm__activeCount))] (eid aka controller_eid : EntityId)
    if generated_monster__genEid == controller_eid
      var alarms : array<EntityId>
      query() <| $ [es(REQUIRE=alarm__active)] (eid aka alarm_eid, alarm__controllerEid : EntityId)
        if alarm__controllerEid == controller_eid
          alarms |> push(alarm_eid)
      if length(alarms) > 0
        alarm__eid = alarms[grnd() % length(alarms)]


[es(tag=server, on_appear, REQUIRE=alarm__active)]
def reguide_existing_monsters_to_the_new_alarm(evt : Event;
                                               eid : EntityId;
                                               door_alarm__controllerEid aka new_door_alarm__controllerEid : EntityId)
  var count = 0
  query() <| $ [es(REQUIRE=alarm__active)] (door_alarm__controllerEid aka another_door_alarm__controllerEid : EntityId)
    if another_door_alarm__controllerEid == new_door_alarm__controllerEid
      count++
  query() <| $ [es] (generated_monster__genEid : EntityId; var alarm__eid : EntityId&; var beh_tree : BehaviourTree)
    if generated_monster__genEid == door_alarm__controllerEid
      if count <= 1 || gfrnd() < 1.0 / float(count)
        alarm__eid = eid
        beh_tree_reset(beh_tree)


[es(tag=server, no_order)]
def clear_alarm_mosters(act : ParallelUpdateFrameDelayed;
                        eid aka controller_eid : EntityId;
                        alarm__activeCount : int;
                        alarm__clearTemplate : string;
                        clear_mosnters__interval : float;
                        var clear_mosnters__updateAt : float&)
  if alarm__activeCount == 0 && clear_mosnters__updateAt < act.curTime
    clear_mosnters__updateAt = act.curTime + clear_mosnters__interval
    var monsters : array<EntityId>
    query() <| $ [es] (eid aka monster_eid : EntityId; generated_monster__genEid : EntityId; isAlive : bool)
      if isAlive && generated_monster__genEid == controller_eid
        monsters |> push(monster_eid)
    if length(monsters) > 0
      let targetEid = monsters[grnd() % length(monsters)]
      query(targetEid) <| $ [es] (transform : float3x4; var deathDrop : Array)
        clear(deathDrop)
        let dmDesc = DamageDesc(DamageType.DM_ZONE, 99999.9, transform[3])
        damage_entity(targetEid, targetEid, dmDesc)
    else
      removeSubTemplate(controller_eid, alarm__clearTemplate)
