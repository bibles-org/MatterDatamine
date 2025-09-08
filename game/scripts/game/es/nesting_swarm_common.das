module nesting_swarm_common shared
require ecs
require Grid
require DagorMath
require Dacoll
require game.utils.team
require pathfinder


def find_nesting_swarm_snake_best_target(snake_eid : EntityId;
                                         radius : float)
  var bestTarget = INVALID_ENTITY_ID
  query(snake_eid) <| $ [es] (transform aka snake_transform : float3x4;
                              nesting_swarm_snake__alwaysAttackRadius : float;
                              nesting_swarm_snake__navmeshRadiusMult : float;
                              team aka snake_team : int;
                              truce_id aka snake_truce_id : int = -1;
                              swarm_warrior__nests : EidList;
                              personal_enemies__enemies : EidList)
    var bestDistance = FLT_MAX
    for_each_entity_in_grid(ecs_hash("humans"), BSphere3(transform[3], radius), GridEntCheck.POS) <| $(eid : EntityId)
      query(eid) <| $ [es(REQUIRE_NOT=deadEntity, REQUIRE=nestedSwarmTarget)] (transform aka t_transform : float3x4;
                                                                               isAlive : bool;
                                                                               team aka danger_team : int;
                                                                               truce_id aka danger_truce_id : int = -1)
        if !isAlive || !is_hostile(snake_team, snake_truce_id, personal_enemies__enemies, snake_eid, danger_team, danger_truce_id)
          return

        let targetPos = t_transform[3] + t_transform[1]
        let dst = distance(snake_transform[3], targetPos)
        if dst < bestDistance
          bestDistance = dst
          if dst > nesting_swarm_snake__alwaysAttackRadius
            // check visibility
            let dir = normalize(targetPos - snake_transform[3])
            if !rayhit_normalized(snake_transform[3], dir, dst, ETF_DEFAULT, -1)
              bestDistance = dst
              bestTarget = eid
              return
            for nest_eid in swarm_warrior__nests //contains a single element actually
              query(nest_eid) <| $ [es] (transform aka nest_transform : float3x4)
                let dirNest = normalize(targetPos - nest_transform[3])
                let dstNest = distance(targetPos, nest_transform[3])
                if !rayhit_normalized(nest_transform[3], dirNest, dstNest, ETF_DEFAULT, -1)
                  bestDistance = dst
                  bestTarget = eid
            if bestTarget == eid
              return
            // Check navmesh dst
            let threshold = 1.0
            let extents = float3(threshold, FLT_MAX, threshold)
            using(snake_transform[3], targetPos, extents) <| $(var req : FindRequest#)
              req.includeFlags |= int(PolyFlag.POLYFLAG_JUMP)
              req.maxJumpUpHeight = FLT_MAX
              let res = calc_approx_path_length(req, threshold, FLT_MAX)
              if res < radius * nesting_swarm_snake__navmeshRadiusMult
                bestDistance = dst
                bestTarget = eid
                return
          else
            bestDistance = dst
            bestTarget = eid
            return
  return bestTarget