require ecs
require app
require Grid
require Dacoll
require level
require math.base
require DagorMath
require DagorRandom
require DagorSystem
require game.events.events
require debug.logerr_once
require game.events.events_active_matter


struct SpawnManagerSpawnPosInfo
  eid : EntityId
  pos : float3
  priority : float


[es(tag=server, no_order)]
def spawn_manager_create_entities(evt : ParallelUpdateFrameDelayed;
                                  eid : EntityId;
                                  dynamic_spawn_manager__updateDt : float;
                                  dynamic_spawn_manager__beforeSuccessUpdateDt : float;
                                  dynamic_spawn_manager__hasSuccess : bool;
                                  dynamic_spawn_manager__entitiesInWorldNumLimits : int2;
                                  var dynamic_spawn_manager__nextUpdateAtTime : float&)
  if dynamic_spawn_manager__entitiesInWorldNumLimits.x > dynamic_spawn_manager__entitiesInWorldNumLimits.y
    logerr_once("[Entity Spawn Manager] Manager {eid}({getEntityTemplateName(eid)}): dynamic_spawn_manager__entitiesInWorldNumLimits.x is bigger than dynamic_spawn_manager__entitiesInWorldNumLimits.y")
    return

  if dynamic_spawn_manager__nextUpdateAtTime > evt.curTime
    return

  let interval = dynamic_spawn_manager__hasSuccess ? dynamic_spawn_manager__updateDt : dynamic_spawn_manager__beforeSuccessUpdateDt
  dynamic_spawn_manager__nextUpdateAtTime = evt.curTime + interval

  var managedEntitiesAmount = 0
  query() <| $ [es] (dynamic_spawn_item__managerEid : EntityId)
    if dynamic_spawn_item__managerEid == eid
      ++managedEntitiesAmount

  if managedEntitiesAmount < dynamic_spawn_manager__entitiesInWorldNumLimits.x
    let spawnAmount = rnd_int(clamp(dynamic_spawn_manager__entitiesInWorldNumLimits.x - managedEntitiesAmount,
                                    0, dynamic_spawn_manager__entitiesInWorldNumLimits.x),
                              dynamic_spawn_manager__entitiesInWorldNumLimits.y - managedEntitiesAmount)
    for _ in range(spawnAmount)
      sendEvent(eid, EventDropLootRequest())


def generate_entities(manager_eid : EntityId;
                      item_templates : StringList;
                      get_priority_cb : block<(pos : float3) : float>)
  var possibleSpawnPoints : array<SpawnManagerSpawnPosInfo>
  query(manager_eid) <| $ [es] (dynamic_spawn_manager__spawnPosTag : string; var dynamic_spawn_manager__hasSuccess : bool&)
    query() <| $ [es] (eid aka spawn_pos_eid : EntityId;
                       transform aka spawn_pos_transform : float3x4;
                       spawn_pos__managedEntityEid : EntityId)
      if (!has(spawn_pos_eid, dynamic_spawn_manager__spawnPosTag, ecs_hash(dynamic_spawn_manager__spawnPosTag))
        || (spawn_pos__managedEntityEid != INVALID_ENTITY_ID && doesEntityExist(spawn_pos__managedEntityEid)))
        return

      possibleSpawnPoints |> push(SpawnManagerSpawnPosInfo(eid = spawn_pos_eid,
                                                             pos = spawn_pos_transform[3],
                                                             priority = invoke(get_priority_cb, spawn_pos_transform[3])))

    if length(possibleSpawnPoints) > 0
      dynamic_spawn_manager__hasSuccess = true
      sort(possibleSpawnPoints) <| $(lhs, rhs : SpawnManagerSpawnPosInfo)
        return lhs.priority < rhs.priority
      for possibleSpawnPoint, itemTemplate in possibleSpawnPoints, item_templates
        query(possibleSpawnPoint.eid) <| $ [es] (transform aka spawn_pos_transform : float3x4;
                                                 var spawn_pos__managedEntityEid : EntityId&)
          var tm = IDENT_TM
          tm[3] = spawn_pos_transform[3]
          spawn_pos__managedEntityEid = createEntity("{itemTemplate}+dynamic_spawn_item") <| $(var init)
            set(init, "transform", tm)
            set(init, "dynamic_spawn_item__managerEid", manager_eid)


[es(tag=server, on_appear, before=loot_drop_system_drop_loot_finalizer, REQUIRE=randomSpawnPreset)]
def spawn_manager_place_entities_randomly(evt : Event;
                                          drop_preset__itemTemplates : StringList;
                                          drop_preset__ownerEid : EntityId)
  generate_entities(drop_preset__ownerEid, drop_preset__itemTemplates) <| $ [unused_argument(pos)] (pos)
    return gfrnd()


[es(tag=server, on_appear, before=loot_drop_system_drop_loot_finalizer)]
def spawn_manager_place_entities_far_from_people(evt : Event;
                                                 drop_preset__itemTemplates : StringList;
                                                 drop_preset__ownerEid : EntityId;
                                                 spawn_preset__searchForHumansRadius : float)
  generate_entities(drop_preset__ownerEid, drop_preset__itemTemplates) <| $(pos)
    var searchPos = pos
    searchPos.y = traceht_lmesh(pos)
    var curPriority = 0.f
    for_each_entity_in_grid(ecs_hash("humans"),
                            BSphere3(searchPos, spawn_preset__searchForHumansRadius),
                            GridEntCheck.BOUNDING) <| $(human_eid : EntityId; human_pos : float3)
      query(human_eid) <| $ [es(REQUIRE=human, REQUIRE_NOT=deadEntity)] ()
        curPriority += clamp((1.f - safediv(distance_sq(searchPos, human_pos), square(spawn_preset__searchForHumansRadius))), 0.f, 1.f)
    return curPriority


[es(tag=server, on_disappear, REQUIRE=dynamic_spawn_item__managerEid)]
def spawn_manager_clean_spawn_pos(evt : Event;
                                  dynamic_spawn_item__managerEid : EntityId;
                                  eid : EntityId)
  if is_level_unloading()
    return
  if dynamic_spawn_item__managerEid == INVALID_ENTITY_ID
    return
  let spawnPosFound = find_query() <| $ [es] (var spawn_pos__managedEntityEid : EntityId&)
    if eid != spawn_pos__managedEntityEid
      return false

    spawn_pos__managedEntityEid = INVALID_ENTITY_ID
    return true

  if !spawnPosFound
    var pos = float3(-1.0, -1.0, -1.0)
    query(eid) <| $ [es] (transform : float3x4)
      pos = transform[3]
    logerr("[Entity Spawn Manager] Entity <{eid}>({getEntityTemplateName(eid)}))[{pos}] doesn't belong to any Spawn Manager.")
