require ecs
require ecs.common
require ecs.safe
require game.es.ecs_common
require app
require math.base
require math.random
require game.events.events_active_matter
require game.events.events_game
require game.es.monster_common
require game.es.grav_zones_common
require game.utils.team
require AnimV20
require GeomNodeTree
require GridCollision
require DngNet
require DagorSystem
require DagorMath
require Dacoll
require DngDm
require CollisionTraces


[es(tag=server, on_appear)]
def energy_attack_controller_init(evt : Event;
                                  eid : EntityId;
                                  animchar : AnimcharBaseComponent;
                                  energy_attack_controller__geomtreeNodes : StringList;
                                  var energy_attack_controller__geomtreeNodeIds : IntList)
  energy_attack_controller__geomtreeNodeIds |> resize(length(energy_attack_controller__geomtreeNodes))
  for nodeId, nodeName in energy_attack_controller__geomtreeNodeIds, energy_attack_controller__geomtreeNodes
    nodeId = *animchar.nodeTree |> geomtree_findNodeIndex(string(nodeName))
    if nodeId < 0
      logerr("{get_entity_info(eid)}: Unknown geomtree node: {nodeName}")


[es(tag=server, no_order, REQUIRE_NOT=deadEntity)]
def energy_attack_controller_update(act : UpdateStageInfoAct;
                                    sleep_mode__isSleeping : bool const?;
                                    sleeping_monster : Tag const?;
                                    energy_attack_controller__readyAt : float;
                                    var energy_attack_controller__visualAffectAvailable : bool&)
  let isReady = energy_attack_controller__readyAt < act.curTime
  let isSleeping = is_monster_sleeping(sleep_mode__isSleeping, sleeping_monster)
  energy_attack_controller__visualAffectAvailable = isReady && !isSleeping


[es(tag=server, on_appear, REQUIRE=deadEntity)]
def energy_attack_controller_on_death(evt : Event;
                                      var energy_attack_controller__visualAffectAvailable : bool&)
  energy_attack_controller__visualAffectAvailable = false


[es(tag=server, track=energy_attack_controller__visualAffectAvailable, on_appear)]
def energy_attack_controller_visual_affect_server(evt : Event;
                                                  eid : EntityId;
                                                  energy_attack_controller__visualAffectTemplate : string;
                                                  energy_attack_controller__visualAffectAvailable : bool;
                                                  var energy_attack_controller__visualAffectEid : EntityId&)
  assume visualAffectTemplate = energy_attack_controller__visualAffectTemplate
  assume visualAffectAvailable = energy_attack_controller__visualAffectAvailable
  assume visualAffectEid = energy_attack_controller__visualAffectEid

  let visualAffectRequired = visualAffectAvailable
  let visualAffectExists = visualAffectEid != INVALID_ENTITY_ID

  if visualAffectRequired && !visualAffectExists
    if visualAffectTemplate != ""
      visualAffectEid = createEntity(visualAffectTemplate) <| $(init)
        init |> set("game_effect__attachedTo", eid)
  elif !visualAffectRequired && visualAffectExists
    destroyEntity(visualAffectEid)
    visualAffectEid = INVALID_ENTITY_ID


[es(tag=server)]
def game_effect_energy_attack(evt : ApplyGameAffect;
                              game_effect__attachedTo : EntityId;
                              game_effect__energyAttackProjectileTemplate : string)
  query(game_effect__attachedTo) <| $ [es] (animchar aka offender_animchar : AnimcharBaseComponent;
                                            energy_attack_controller__geomtreeNodeIds : IntList;
                                            energy_attack_controller__cooldown : float2;
                                            walker_agent__targetEid : EntityId;
                                            team aka owner_team : int = -1;
                                            var energy_attack_controller__readyAt : float&)
    let curTime = get_sync_time()
    if energy_attack_controller__readyAt >= curTime
      return

    var targetPos : float3
    var targetPosValid = false
    query(walker_agent__targetEid) <| $ [es] (ai_target_node__nodeId : int;
                                              animchar aka target_animchar : AnimcharBaseComponent)
      var targetTm : float3x4
      *target_animchar.nodeTree |> geomtree_getNodeWtmScalar(ai_target_node__nodeId, targetTm)
      targetPos = targetTm[3]
      targetPosValid = true

    energy_attack_controller__readyAt = curTime + rnd_float(energy_attack_controller__cooldown)
    for nodeId in energy_attack_controller__geomtreeNodeIds
      var nodeWtm : float3x4
      *offender_animchar.nodeTree |> geomtree_getNodeWtmScalar(nodeId, nodeWtm)

      let spawnPos = nodeWtm[3]
      let dirForward = targetPosValid ? normalize(targetPos - spawnPos) : normalize(nodeWtm[0])
      let dirRight = normalize(nodeWtm[0])

      var projectileTm : float3x4
      projectileTm[3] = spawnPos

      createEntity(game_effect__energyAttackProjectileTemplate) <| $(init)
        init |> set("transform", projectileTm)
        init |> set("team", owner_team)
        init |> set("energy_attack_projectile__owner", game_effect__attachedTo)
        init |> set("energy_attack_projectile__startPos", spawnPos)
        init |> set("energy_attack_projectile__startTimestamp", get_sync_time())
        init |> set("energy_attack_projectile__dirForward", dirForward)
        init |> set("energy_attack_projectile__dirRight", dirRight)
        init |> set("energy_attack_projectile__salt", rnd_float(-100000.0, 100000.0))


[es(tag=server, on_appear)]
def energy_attack_projectile_init(evt : Event;
                                  energy_attack_projectile__startPos : float3;
                                  var energy_attack_projectile__damageTracePos : float3&)
  energy_attack_projectile__damageTracePos = energy_attack_projectile__startPos


[es(no_order)]
def energy_attack_projectile_update(act : UpdateStageInfoAct;
                                    eid aka energy_attack_projectile_eid : EntityId;
                                    energy_attack_projectile__owner : EntityId;
                                    energy_attack_projectile__startPos : float3;
                                    energy_attack_projectile__startTimestamp : float;
                                    energy_attack_projectile__dirForward : float3;
                                    energy_attack_projectile__dirRight : float3;
                                    energy_attack_projectile__velocity : float;
                                    energy_attack_projectile__maxDistance : float;
                                    energy_attack_projectile__offsetFrequency : float;
                                    energy_attack_projectile__offsetAmplitude : float;
                                    energy_attack_projectile__offsetStartSmoothDist : float = 1.0;
                                    energy_attack_projectile__salt : float;
                                    energy_attack_projectile__damageTraceDistSq : float;
                                    energy_attack_projectile__damageTraceRadius : float = 0.1;
                                    energy_attack_projectile__damageRng : float2;
                                    energy_attack_projectile__pushRng : float2;
                                    energy_attack_projectile__pushGravMult : float = 0.1;
                                    team aka energy_attack_projectile_team : int = -1;
                                    var energy_attack_projectile__damagedEntities : EidList;
                                    var energy_attack_projectile__damageTracePos : float3&;
                                    var transform : float3x4)
  assume salt = energy_attack_projectile__salt
  assume offsetFrequency = energy_attack_projectile__offsetFrequency
  assume offsetAmplitude = energy_attack_projectile__offsetAmplitude

  let isServer = is_server()

  let time = act.curTime - energy_attack_projectile__startTimestamp
  var dist = time * energy_attack_projectile__velocity
  if dist >= energy_attack_projectile__maxDistance
    dist = energy_attack_projectile__maxDistance
    if isServer
      destroyEntity(energy_attack_projectile_eid)

  let dirUp = cross(energy_attack_projectile__dirForward, energy_attack_projectile__dirRight)

  let offsetMult = offsetAmplitude * saturate(dist / energy_attack_projectile__offsetStartSmoothDist)
  let offset = dirUp * perlin_noise1(offsetFrequency * time + salt) * offsetMult

  let newPos = energy_attack_projectile__startPos + dist * energy_attack_projectile__dirForward + offset
  transform[3] = newPos

  if isServer
    let traceDistSq = distance_sq(energy_attack_projectile__damageTracePos, newPos)
    if traceDistSq >= energy_attack_projectile__damageTraceDistSq
      let traceDist = sqrt(traceDistSq)

      let gravDir = get_grav_dir(newPos)

      query(energy_attack_projectile__owner) <| $ [es] (personal_enemies__enemies : EidList const?)
        using() <| $(var intersections : IntersectedEntities)
          var t = traceDist
          let traceDir = normalize(newPos - energy_attack_projectile__damageTracePos)
          trace_entities_in_grid_by_capsule(ecs_hash("humans"),
                                            energy_attack_projectile__damageTracePos,
                                            traceDir, t, energy_attack_projectile__damageTraceRadius,
                                            INVALID_ENTITY_ID, intersections, SortIntersections.NO)
          for isect in intersections
            if isect.eid == energy_attack_projectile__owner
              continue

            query(isect.eid) <| $ [es(REQUIRE=ai_target)] (team aka target_team : int = -1)
              let isFriendly = (is_teams_friendly(energy_attack_projectile_team, target_team) &&
                                !is_personal_enemy(personal_enemies__enemies, isect.eid))
              if isFriendly
                return

              if energy_attack_projectile__damagedEntities |> find_index(isect.eid) < 0
                let damageDesc = DamageDesc(DamageType.DM_MELEE, rnd_float(energy_attack_projectile__damageRng), isect.pos)
                damage_entity(isect.eid, eid, damageDesc)

                let pushDir = normalize(traceDir - gravDir * energy_attack_projectile__pushGravMult)
                sendEvent(isect.eid, CmdPushPhys(vel = pushDir * rnd_float(energy_attack_projectile__pushRng), push_immunity = 0.0))

                energy_attack_projectile__damagedEntities |> push(isect.eid)

      energy_attack_projectile__damageTracePos = newPos
