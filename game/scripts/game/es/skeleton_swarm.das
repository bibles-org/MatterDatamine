require app
require ecs
require math.random
require active_matter.game.es.skeleton_swarm_state_common
require game.events.events_active_matter
require danetlibs.swarm.main.swarm_events


[es(on_appear)]
def init_swarm_initial_count(evt : Event; count : int; var swarm__initialBoidsCount : int&)
  swarm__initialBoidsCount = count


[es(tag=server, no_order, REQUIRE=attachedSkeletonSwarm)]
def move_skeleton_swarm_with_owner_on_server(act : ParallelUpdateFrameDelayed; game_effect__attachedTo : EntityId; var position, swarm_cluster__targetPos : float3&)
  query(game_effect__attachedTo) <| $ [es] (transform : float3x4)
    position = transform[3]
    swarm_cluster__targetPos = position


[es(tag=server, REQUIRE=attachedSkeletonSwarm)]
def skeleton_swarm_boid_died(evt : EventSomeSwarmBoidDied;
                             game_effect__attachedTo : EntityId;
                             attached_skeleton__minBoidsCount : int;
                             position : float3;
                             var count : int&;
                             var attached_skeleton__wishFlyOffset : float3&;
                             attached_skeleton__deathAvoidDist = 0.5)
  count -= 1
  if count > attached_skeleton__minBoidsCount
    attached_skeleton__wishFlyOffset += normalize(evt.pos - position) * attached_skeleton__deathAvoidDist
  else
    query(game_effect__attachedTo) <| $ [es] (var skeleton_swarm__aiState : int&;
                                              var hitpoints__hp : float&)
      if skeleton_swarm__aiState != int(SkeletonSwarmAiState.DEAD)
        hitpoints__hp = 0.0
        skeleton_swarm__aiState = int(SkeletonSwarmAiState.DEAD)


[es(tag=server, on_disappear, REQUIRE=skeleton_swarm__aiState)]
def skeleton_swarm_destroy_attachments(evt : Event; eid : EntityId)
  let ownerEid = eid
  find_query() <| $ [es(REQUIRE=attachedSkeletonSwarm)] (eid, game_effect__attachedTo : EntityId)
    if game_effect__attachedTo == ownerEid
      destroyEntity(eid)
      return true
    return false


[es(tag=server, track=hitpoints__hp)]
def track_skeleton_swarm_hp(evt : Event; eid : EntityId; transform : float3x4;
                            skeleton_swarm__aiState : int;
                            hitpoints__maxHp : float;
                            var hitpoints__hp : float&)
  if (skeleton_swarm__aiState != int(SkeletonSwarmAiState.DEAD)
      && hitpoints__hp < hitpoints__maxHp
      && hitpoints__maxHp > 0f)
    let delta = hitpoints__maxHp - hitpoints__hp
    hitpoints__hp = hitpoints__maxHp // restore hp
    let ownerEid = eid
    find_query() <| $ [es(REQUIRE=attachedSkeletonSwarm)] (eid, game_effect__attachedTo : EntityId;
                                                           swarm__initialBoidsCount : int;
                                                           swarm__deadBoidTemplateName : string;
                                                           var count : int&)
      if game_effect__attachedTo == ownerEid
        let pt = delta / hitpoints__maxHp
        var minusBoids = (float(swarm__initialBoidsCount) * pt) |> ceil |> int()
        count -= minusBoids + 1 // -1 will be added in skeleton_swarm_boid_died
        sendEvent(eid, EventSomeSwarmBoidDied(pos = transform[3]))

        let swarmEid = eid
        find_query() <| $ [es(REQUIRE_NOT=boidDead)] (eid, parentSwarm : EntityId; var velocity : float3&)
          if parentSwarm == swarmEid
            reCreateEntityFrom(eid, swarm__deadBoidTemplateName)
            velocity.y = min(velocity.y, -2f)
            minusBoids -= 1
          return minusBoids <= 0
        return true
      return false


[es(tag=server, REQUIRE=attachedSkeletonSwarm)]
def wakeup_skeleton_on_hit(evt : EventSomeSwarmBoidDied;
                           game_effect__attachedTo : EntityId)
  query(game_effect__attachedTo) <| $ [es(REQUIRE_NOT=sleep_mode_wakeup_forbidden)] (sleep_mode__updateInterval : float2;
                                                                                     var sleep_mode__isSleeping : bool&;
                                                                                     var sleep_mode__nextUpdateAt : float&)
    sleep_mode__isSleeping = false
    sleep_mode__nextUpdateAt = max(sleep_mode__nextUpdateAt, get_sync_time() + rnd_float(sleep_mode__updateInterval))