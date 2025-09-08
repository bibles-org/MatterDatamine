require ecs
require ecs.safe
require app
require math.random
require math.base
require game.events.events_active_matter


[es(tag=server, on_event=EventLevelLoaded)]
def miniboss_manager_on_level_loaded(evt : Event;
                                     miniboss_manager__spawnData : Object)
  var spawnPoints : table<string; array<float3>>
  query() <| $ [es] (miniboss_spawn_point__type : string;
                     transform : float3x4)
    spawnPoints[miniboss_spawn_point__type] |> push(transform[3])

  for spawnData in miniboss_manager__spawnData
    let spawnDataKey = spawnData.key
    let spawnDataValue = spawnData.value as Object
    let countRng = spawnDataValue?.count ?? int2(0, 0)

    assume spawnPointDataValue = spawnPoints[spawnDataKey]
    spawnPointDataValue |> shuffle()

    let count = min(rnd_int(countRng), length(spawnPointDataValue))

    let spawnTemplates = get_ecs_StringList(spawnDataValue?.templates)
    if spawnTemplates != null
      for templateName in *spawnTemplates
        for i in range(count)
          createEntity(string(templateName)) <| $(var init : ComponentsInitializer)
            var tm = IDENT_TM
            tm[3] = spawnPointDataValue[i]
            init |> set("transform", tm)



[es(tag=server, on_disappear, REQUIRE=sleeping_monster)]
def miniboss_minion_on_awake(evt : Event;
                             miniboss_minion__type : string;
                             miniboss_minion__detectBossDistanceSq : float = square(10.0);
                             transform aka minion_transform : float3x4;
                             var miniboss_minion__bossEid : EntityId&)
  var isBossValid = false
  query(miniboss_minion__bossEid) <| $ [es] (isAlive : bool = true)
    isBossValid = isAlive

  if !isBossValid
    find_query() <| $ [es] (eid aka miniboss_eid : EntityId;
                            miniboss__type : string;
                            transform aka miniboss_transform : float3x4)
      if miniboss__type != miniboss_minion__type
        return false

      let distanceSq = distance_sq(minion_transform[3], miniboss_transform[3])
      if distanceSq > miniboss_minion__detectBossDistanceSq
        return false

      miniboss_minion__bossEid = miniboss_eid
      return true
