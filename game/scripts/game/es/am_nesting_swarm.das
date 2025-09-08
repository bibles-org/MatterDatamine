require app
require ecs
require ecs.extra_set
require ecs.common
require Grid
require GridCollision
require DagorRandom
require DagorMath
require Dacoll
require Daphys
require DngDm
require game.events.events_game
require game.events.events_active_matter


[es(tag=server, on_appear)]
def init_nesting_swarm_nest_pos(evt : Event; transform : float3x4; var swarm_cluster__targetPos : float3&)
  swarm_cluster__targetPos = transform[3]

[es(tag=server, on_appear)]
def init_nesting_swarm_nest_warrior(evt : Event;
                                    eid : EntityId;
                                    transform : float3x4;
                                    nesting_swarm_nest__warriorTemplate : string;
                                    var nesting_swarm_nest__warriorEid : EntityId&)
  if nesting_swarm_nest__warriorEid == INVALID_ENTITY_ID
    nesting_swarm_nest__warriorEid = createEntity(nesting_swarm_nest__warriorTemplate) <| $(init)
      init |> set("transform", transform)
      init |> set("swarm_warrior__targetPos", transform[3])
      init |> set("swarm_warrior__primaryNest", eid)
      init |> set("swarm_warrior__nests", [ eid])


[es(tag=server, on_appear)]
def init_nesting_swarm_warrior(evt : Event; count : int; var swarm_warrior__lastActionAt : float&; var swarm_warrior__startingBoidsCount : int&)
  swarm_warrior__lastActionAt = get_sync_time()
  swarm_warrior__startingBoidsCount = count


[es(no_order)]
def move_nesting_swarm_warrior(act : ParallelUpdateFrameDelayed;
                               transform : float3x4;
                               walker_agent__standShootLocalPos : float3;
                               var swarm_cluster__targetPos : float3&)
  swarm_cluster__targetPos = transform[3] + walker_agent__standShootLocalPos


[es(tag=server, no_order, REQUIRE_NOT=deadEntity)]
def swarm_warrior_update_es(act : ParallelUpdateFrameDelayed;
                            eid aka swarm_eid : EntityId;
                            transform : float3x4;
                            team aka warrior_team : int;
                            swarm_warrior__boidsMin : int;
                            swarm_warrior__boidsLostOnDamage : int;
                            swarm_warrior__damage : float;
                            swarm_warrior__damageRadius : float;
                            swarm_warrior__damagePeriod : float;
                            swarm_warrior__teleportLastActionTimeout : float;
                            swarm_warrior__teleportActiveInc : float;
                            swarm_warrior__teleportPassiveInc : float;
                            swarm_warrior__lastActionAt : float;
                            var count : int&;
                            var swarm_warrior__teleportDesire : float&;
                            var swarm_warrior__nextUpdateAt : float&)
  if act.curTime > swarm_warrior__nextUpdateAt
    swarm_warrior__nextUpdateAt = act.curTime + swarm_warrior__damagePeriod
    var hasDamagedSomeone = false
    gather_entities_in_grid(ecs_hash("humans"), BSphere3(transform[3], swarm_warrior__damageRadius), GridEntCheck.BOUNDING) <| $(target_list)
      for target_eid in target_list
        query(target_eid) <| $ [es(REQUIRE=(human, ai_target))] (isAlive : bool; team aka target_team : int)
          if target_team == warrior_team
            return
          if isAlive
            hasDamagedSomeone = true
            let dmDesc = DamageDesc(DamageType.DM_MELEE, swarm_warrior__damage, transform[3])
            damage_entity(target_eid, swarm_eid, dmDesc)
    if hasDamagedSomeone
      count = max(swarm_warrior__boidsMin, count - swarm_warrior__boidsLostOnDamage)
    let passive = act.curTime - swarm_warrior__lastActionAt > swarm_warrior__teleportLastActionTimeout
    swarm_warrior__teleportDesire += passive ? swarm_warrior__teleportPassiveInc : swarm_warrior__teleportActiveInc


[es(tag=server, no_order, REQUIRE_NOT=deadEntity)]
def nesting_swarm_scan(act : ParallelUpdateFrameDelayed;
                       transform aka nest_transform : float3x4;
                       nesting_swarm_nest__detectionRadius : float;
                       nesting_swarm_nest__nextScanPeriod : float;
                       var nesting_swarm_nest__nextScanAt : float&;
                       nesting_swarm_nest__warriorEid : EntityId)
  if act.curTime > nesting_swarm_nest__nextScanAt
    nesting_swarm_nest__nextScanAt = act.curTime + nesting_swarm_nest__nextScanPeriod
    var nearestPos : float3
    var bestDstSq = FLT_MAX
    gather_entities_in_grid(ecs_hash("humans"), BSphere3(nest_transform[3], nesting_swarm_nest__detectionRadius), GridEntCheck.BOUNDING) <| $(target_list)
      for target_eid in target_list
        query(target_eid) <| $ [es(REQUIRE=(human, ai_target))] (isAlive : bool; transform aka hero_transform : float3x4)
          if isAlive
            let dstSq = distance_sq(hero_transform[3], nest_transform[3])
            if dstSq < bestDstSq
              bestDstSq = dstSq
              nearestPos = hero_transform[3]
    if bestDstSq != FLT_MAX
      query(nesting_swarm_nest__warriorEid) <| $ [es] (var swarm_warrior__targetPos : float3&; var swarm_warrior__investigationsLeft : int&)
        swarm_warrior__targetPos = nearestPos
        swarm_warrior__investigationsLeft = 1


[es(tag=server, on_event=EventEntityDied, REQUIRE=nesting_swarm_nest)]
def on_nesting_swarm_nest_died(evt : Event;
                               eid aka nest_eid : EntityId;
                               swarm__deadBoidTemplateName : string;
                               nesting_swarm_nest__warriorEid : EntityId;
                               var nesting_swarm_nest__supplyEids : EidList;
                               nesting_swarm_teleportation__holderEid : EntityId const?)
  query(nesting_swarm_nest__warriorEid) <| $ [es] (var beh_tree__enabled : bool&)
    beh_tree__enabled = false
  query() <| $ [es(REQUIRE_NOT=boidDead)] (eid aka boid_eid, parentSwarm : EntityId; var velocity : float3&)
    if parentSwarm == nest_eid || parentSwarm == nesting_swarm_nest__warriorEid
      reCreateEntityFrom(boid_eid, swarm__deadBoidTemplateName)
      velocity.y = min(velocity.y, 200f)
  query() <| $ [es] (eid aka warrior_eid : EntityId;
                     var swarm_warrior__nests : EidList;
                     var swarm_warrior__primaryNest : EntityId&)
    let idx = find_index(swarm_warrior__nests, nest_eid)
    if idx != -1
      erase(swarm_warrior__nests, idx)
    if length(swarm_warrior__nests) == 0
      destroyEntity(warrior_eid)
    elif swarm_warrior__primaryNest == nest_eid
      swarm_warrior__primaryNest = swarm_warrior__nests[0]
  if nesting_swarm_teleportation__holderEid != null
    destroyEntity(*nesting_swarm_teleportation__holderEid)
  for supplyEid in nesting_swarm_nest__supplyEids
    destroyEntity(supplyEid)


[es(tag=server, REQUIRE=human)]
def on_swarm_warrior_killed_enemy(evt : EventEntityDied; eid : EntityId)
  query(evt.offender) <| $ [es] (swarm_warrior__embryoTemplate : string; swarm_warrior__embryoDelay : float)
    createEntity(swarm_warrior__embryoTemplate) <| $(init)
      init |> set("game_effect__attachedTo", eid)
      init |> set("nesting_swarm_embryo__convertAt", get_sync_time() + swarm_warrior__embryoDelay)
      init |> set("nesting_swarm_embryo__warriorEid", evt.offender)


[es(tag=server, no_order)]
def nesting_swarm_embryo_es(act : ParallelUpdateFrameDelayed;
                            eid : EntityId;
                            nesting_swarm_embryo__convertAt : float;
                            nesting_swarm_embryo__offset : float3;
                            game_effect__attachedTo : EntityId;
                            nesting_swarm_embryo__warriorEid : EntityId;
                            nesting_swarm_embryo__template : string)
  if act.curTime > nesting_swarm_embryo__convertAt
    query(nesting_swarm_embryo__warriorEid) <| $ [es] (var swarm_warrior__nests : EidList)
      query(game_effect__attachedTo) <| $ [es] (transform : float3x4; animchar__res : string)
        destroyEntity(game_effect__attachedTo)
        let newNest = createEntity(nesting_swarm_embryo__template) <| $(init)
          var tm := transform
          tm[3] += nesting_swarm_embryo__offset
          init |> set("animchar__res", animchar__res)
          init |> set("transform", tm)
          init |> set("nesting_swarm_nest__warriorEid", nesting_swarm_embryo__warriorEid)
        swarm_warrior__nests |> push(newNest)
    destroyEntity(eid)


[es(tag=server, on_appear)]
def init_nesting_swarm_teleportation(evt : Event; nesting_swarm_teleportation__duration : float; var nesting_swarm_teleportation__endsAt : float&)
  nesting_swarm_teleportation__endsAt = get_sync_time() + nesting_swarm_teleportation__duration


[es(tag=server, no_order)]
def nesting_swarm_teleportation_es(act : ParallelUpdateFrameDelayed;
                                   eid : EntityId;
                                   nesting_swarm_teleportation__endsAt : float;
                                   nesting_swarm_teleportation__holderEid : EntityId;
                                   nesting_swarm_teleportation__removeTemplate : string;
                                   transform__dropOnGroundMaxHeight : float = 5.0;
                                   transform__dropOnGroundOffset : float = 0.0;
                                   var transform aka nest_transform : float3x4;
                                   var swarm_cluster__targetPos : float3&;
                                   var static_sinusoidal_oscillation__origin : float3?)
  if act.curTime > nesting_swarm_teleportation__endsAt
    query(nesting_swarm_teleportation__holderEid) <| $ [es] (transform aka holder_transform : float3x4)
      nest_transform = holder_transform
      if transform__dropOnGroundOffset > 0.0
        var height = transform__dropOnGroundMaxHeight
        if tracedown_normalized(nest_transform[3], height, ETF_DEFAULT)
          nest_transform[3].y = nest_transform[3].y - height + transform__dropOnGroundOffset

      if static_sinusoidal_oscillation__origin != null
        *static_sinusoidal_oscillation__origin = nest_transform[3]

      swarm_cluster__targetPos = nest_transform[3]
      destroyEntity(nesting_swarm_teleportation__holderEid)
      removeSubTemplate(eid, nesting_swarm_teleportation__removeTemplate)



[es(tag=server, no_order, REQUIRE_NOT=deadEntity)]
def swarm_warrior__boids_control(act : ParallelUpdateFrameDelayed;
                                 eid : EntityId;
                                 transform aka warrior_transform : float3x4;
                                 swarm_warrior__boidsRate : int;
                                 swarm_warrior__boidsInterval : float;
                                 swarm_warrior__boidsMin : int;
                                 swarm_warrior__startingBoidsCount : int;
                                 swarm_warrior__boidsNestRange : float;
                                 swarm_warrior__nests : EidList;
                                 var swarm_warrior__primaryNest : EntityId&;
                                 var swarm_warrior__checkBoidsAt : float&;
                                 var count : int&)
  if act.curTime < swarm_warrior__checkBoidsAt
    return
  swarm_warrior__checkBoidsAt = act.curTime + swarm_warrior__boidsInterval
  var dstToNest = FLT_MAX
  for nestEid in swarm_warrior__nests
    query(nestEid) <| $ [es] (transform aka nest_transform : float3x4)
      let dst = distance(warrior_transform[3], nest_transform[3])
      if dstToNest > dst
        dstToNest = dst
        swarm_warrior__primaryNest = nestEid
  let isFarFromNest = dstToNest > swarm_warrior__boidsNestRange
  if isFarFromNest
    count = max(count - swarm_warrior__boidsRate, swarm_warrior__boidsMin)
  if count < swarm_warrior__startingBoidsCount
    if isFarFromNest
      query(swarm_warrior__primaryNest) <| $ [es] (transform aka nest_transform : float3x4;
                                                   nesting_swarm_nest__supplyTemplate : string;
                                                   nesting_swarm_nest__maxSupplyCount : int;
                                                   var nesting_swarm_nest__supplyEids : EidList)
        if nesting_swarm_nest__maxSupplyCount > length(nesting_swarm_nest__supplyEids)
          let supplyEid = createEntity(nesting_swarm_nest__supplyTemplate) <| $(init)
            init |> set("transform", nest_transform)
            init |> set("swarm_supply__targetEid", eid)
            init |> set("swarm_supply__nestEid", swarm_warrior__primaryNest)
          nesting_swarm_nest__supplyEids |> push(supplyEid)
    else
      count = min(swarm_warrior__startingBoidsCount, count + swarm_warrior__boidsRate)

[es(tag=server, no_order, REQUIRE=nestingSwarmAI)]
def update_nesting_swarm_ai_pos_dir(act : ParallelUpdateFrameDelayed;
                                    transform : float3x4;
                                    flyer__wishLookDir : float3;
                                    walker_agent__standShootLocalPos : float3;
                                    var agent_dangers__standShootPos : float3&;
                                    var agent_dangers__standShootDir : float3&)
  agent_dangers__standShootPos = transform * walker_agent__standShootLocalPos
  agent_dangers__standShootDir = flyer__wishLookDir


[es(tag=server, on_disappear)]
def clean_nest_warrior(evt : Event; nesting_swarm_nest__warriorEid : EntityId)
  destroyEntity(nesting_swarm_nest__warriorEid)


[es(tag=server)]
def am_nesting_swarm_nest_died(evt : EventEntityDied;
                               eid : EntityId;
                               transform : float3x4;
                               nesting_swarm_nest__createOnDestroyTemplate : string;
                               nesting_swarm_nest__createOnDestroyOffset : float3)
  if nesting_swarm_nest__createOnDestroyTemplate != ""
    createEntity(nesting_swarm_nest__createOnDestroyTemplate) <| $(var init : ComponentsInitializer)
      init |> set("ownerEid", eid)

      var tm = transform
      tm[3] += rotate(transform, nesting_swarm_nest__createOnDestroyOffset)
      init |> set("transform", tm)