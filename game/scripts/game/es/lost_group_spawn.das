require ecs
require ecs.safe
require level
require math.random
require math.base
require DagorMath
require danetlibs.pathfinder.main.pathfinder_common
require DagorSystem
require Dacoll


def has_collision(tm : float3x4; radius : float) : bool
  let collisionTm = tm * scale_tm(radius)
  var collision = false
  dacoll_use_box_collision() <| $(var coll : CollisionObject)
    coll |> dacoll_set_collision_object_tm(collisionTm)
    let box = BBox3(tm[3], radius)
    collision = test_collision_ri(coll, box)
  return collision


[es(tag=server, on_event=EventLevelLoaded, on_appear)]
def lost_group_spawn_appear(evt : Event;
                            eid : EntityId;
                            lost_group_spawn__botTemplate : string;
                            lost_group_spawn__botPlayerTemplate : string;
                            lost_group_spawn__botSpawnEffect : string;
                            lost_group_spawn__botsPerGroupNum : int2;
                            lost_group_spawn__groupsNum : int2;
                            lost_group_spawn__distToPossibleSpawn : float2;
                            lost_group_spawn__botToGroupCenterDist : float2;
                            lost_group_spawn__items : Object)
  if !is_level_loaded()
    return
  var spawns : array<float3>
  query() <| $ [es(REQUIRE=respbase)] (transform : float3x4)
    spawns |> push(transform[3])

  if length(spawns) == 0
    logerr("{eid}: lost_group_spawn: no spawnBase found")
    return

  query() <| $ [es] (bot_spawner__heroTemplateSuits : StringList const?)
    let groupsNum = rnd_int(lost_group_spawn__groupsNum)
    var spawnedGroups = 0
    print("{eid}: lost_group_spawn: spawn {groupsNum} lost groups")
    var spawnsTries = groupsNum * 2
    while spawnedGroups < groupsNum && spawnsTries-- > 0
      let spawnIdx = rnd_int(0, length(spawns) - 1)
      let spawnPos = spawns[spawnIdx]
      let pos = find_nav_point_around(spawnPos, spawnPos, rnd_float(lost_group_spawn__distToPossibleSpawn), /*tries*/2) <| $ [unused_argument(_)] (_ : float3)
        return true

      if pos is invalid
        continue

      spawns |> erase(spawnIdx)
      let groupCenterPos = pos as pos
      spawnedGroups += 1

      let botsNum = rnd_int(lost_group_spawn__botsPerGroupNum)
      var spawnedBots = 0
      var butsSpawnTries = botsNum * 2
      while spawnedBots < botsNum && butsSpawnTries-- > 0

        let botPos = find_nav_point_around(spawnPos, groupCenterPos, rnd_float(lost_group_spawn__botToGroupCenterDist), /*tries*/2) <| $ [unused_argument(_)] (_ : float3)
          return true
        if botPos is invalid
          continue

        spawnedBots += 1

        let suit = bot_spawner__heroTemplateSuits != null ? string((*bot_spawner__heroTemplateSuits)[rnd_int(0, length(*bot_spawner__heroTemplateSuits) - 1)]) : ""
        let heroTemplateName = suit != "" ? "{lost_group_spawn__botTemplate}+{suit}" : lost_group_spawn__botTemplate

        let heroEid = createEntity(heroTemplateName) <| $(init)
          var tm = IDENT_TM
          rotyTM(rnd_float(0.0f, PI * 2.0f), tm)
          tm[3] = botPos as pos
          tm[3].y += 2.5 // above ground
          init |> set("transform", tm)

        createEntity(lost_group_spawn__botPlayerTemplate) <| $(init) // create hero to trigger give_bot_initial_equip
          init |> set("possessed", heroEid)

        createEntity(lost_group_spawn__botSpawnEffect) <| $(init)
          init |> set("game_effect__attachedTo", heroEid)

      if spawnedBots > 0
        for item in lost_group_spawn__items
          let itemConfig = item.value as Object
          if gfrnd() > itemConfig?.chance ?? 0.
            continue

          let distToCenter = itemConfig?.toGroupCenterDist ?? lost_group_spawn__botToGroupCenterDist
          let itemPos = find_nav_point_around(spawnPos, groupCenterPos, rnd_float(distToCenter), /*tries*/2) <| $ [unused_argument(_)] (_ : float3)
            return true
          if itemPos is invalid
            continue

          var tm = IDENT_TM
          rotyTM(rnd_float(0.0f, PI * 2.0f), tm)
          tm[3] = itemPos as pos

          let collresCenter = itemConfig?.collresCenter ?? float3()
          let collresRadius = itemConfig?.collresRadius ?as float

          if collresRadius != null && has_collision(tm * pos_tm(collresCenter), *collresRadius)
            continue

          createEntity(item.key) <| $(init)
            init |> set("transform", tm)

      print("{eid}: lost_group_spawn: spawn {spawnedBots}/{botsNum} bots @ {groupCenterPos}")

    print("{eid}: lost_group_spawn: spawned {spawnedGroups}/{groupsNum}")
