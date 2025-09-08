require ecs
require ecs.safe
require DagorRandom
require game.utils.team

[es(tag=server, on_event=EventLevelLoaded)]
def item_spawner(evt : Event;
                 transform : float3x4;
                 spawnItemList : Array;
                 spawnItemStep : float3;
                 team : int = TEAM_UNASSIGNED)
  var tm = transform
  for itemC in spawnItemList
    let item = get_ecs_object(itemC)
    let count = item?.count ?? 1
    let templ = item?.templ ?? ""

    if templ == ""
      return

    for _ in 0..count
      createEntity(templ) <| $(init)
        init |> set("team", team)
        init |> set("transform", tm)
      tm[3] += spawnItemStep


[es(tag=server, on_appear)]
def spawn_entity_from_list(evt : Event;
                           spawn_entity_from_list__entitiesToSpawn : Array;
                           transform : float3x4)
  var totalChanceSum = 0.0
  var chances : array<float>
  for entity in spawn_entity_from_list__entitiesToSpawn
    let chance = (entity as Object)?.chance ?? 0.0
    chances |> push(chance)
    totalChanceSum += chance
  // fast weight based rnd
  var counter = 0.0
  let rndNum = gfrnd()
  for i in iter_range(chances)
    counter += chances[i] / totalChanceSum
    if counter >= rndNum
      let templateName = (spawn_entity_from_list__entitiesToSpawn[i] as Object)?.name ?? ""
      if templateName != ""
        createEntity(templateName) <| $(var init)
          init |> set("transform", transform)
      break
