module swarm_common shared

require ecs
require ecs.common
require app
require math.base
require math.random
require danetlibs.swarm.main.swarm_events
require DagorMath
require DagorSystem
require game.utils.hero


enum BoidState
  BOID_FLYING = 0 * 65536
  BOID_STAYING = 1 * 65536
  BOID_DEAD = 2 * 65536


def apply_swarm_fire_cloud_damage(damage_dealer : EntityId;
                                  from, dir : float3;
                                  len, radius : float)
  let fireCloudEnd = from + dir * len
  let cloudBBox = BBox3(min(from, fireCloudEnd) - float3(radius),
                        max(from, fireCloudEnd) + float3(radius))
  query() <| $ [es(REQUIRE=(flyingSwarmObject, fireTargetSwarm))] (eid aka swarm_eid : EntityId;
                                                                   swarm__elementsBBoxMin : float3;
                                                                   swarm__elementsBBoxMax : float3;
                                                                   swarm__moveSpeed : float = 5.0;
                                                                   swarm__deadBoidTemplateName : string = "";
                                                                   swarm__deadBoidFiredTemplateName : string = "";
                                                                   swarm__fireDeathSpeedSlowdown : float = 0.1;
                                                                   swarm__fireDeathFallingImpulse : float2 = float2(2.0, 5.0);
                                                                   var count : int&)
    let swarmBBox = BBox3(swarm__elementsBBoxMin, swarm__elementsBBoxMax)
    if cloudBBox & swarmBBox
      let dirRight = -dir_to_quat(dir) |> quat_get_left()
      let dirUp = cross(dir, dirRight)
      var tm : float3x4
      tm[0] = dirRight * 2.0 * radius
      tm[1] = dirUp * 2.0 * radius
      tm[2] = dir * len
      tm[3] = from + dir * len * 0.5
      let itm = inverse(tm)

      let isKillerControlledHero = (damage_dealer == get_controlled_hero())

      query() <| $ [es(REQUIRE_NOT=(boidDead, invulnerableBoid))] (eid aka boid_eid : EntityId;
                                                                   parentSwarm : EntityId;
                                                                   position : float3;
                                                                   boid__dyingTime : float = 5.0;
                                                                   trajectoryPos : Point4List const?;
                                                                   orientation_quat : vec4f;
                                                                   var velocity : float3&;
                                                                   var staying_time : float&;
                                                                   var boid_state : int&;
                                                                   var boid__isHitted : bool&)
        if parentSwarm == swarm_eid
          let localPoint = itm * position
          if IDENT_BBOX & localPoint
            if isKillerControlledHero
              sendEvent(parentSwarm, EventSomeSwarmBoidDied(pos = position))
            count -= 1

            if staying_time <= 0.0
              let forward = quat(float4(orientation_quat)) |> quat_get_forward
              velocity = forward * swarm__moveSpeed * swarm__fireDeathSpeedSlowdown
              velocity.y = min(velocity.y, 0.5)
            else
              velocity = float3(0.0, 0.0, 0.0)

            let phi = 2.0 * PI * eid_frnd(eid)
            let theta = acos(-1.0 + eid_frnd(eid) * 2.0)
            let randDir = float3(sin(theta) * cos(phi), sin(theta) * sin(phi), cos(theta))
            velocity += randDir * (0.5 + eid_frnd(eid))

            velocity.y -= rnd_float(swarm__fireDeathFallingImpulse)

            boid_state = int(BoidState.BOID_DEAD)
            staying_time = boid__dyingTime
            boid__isHitted = true
            var deadBoidTemplateName : string
            if swarm__deadBoidTemplateName != ""
              deadBoidTemplateName := swarm__deadBoidTemplateName
            elif trajectoryPos == null
              deadBoidTemplateName := "deadBoid"
            else
              deadBoidTemplateName := "trajectoryDeadBoid"

            if swarm__deadBoidFiredTemplateName != ""
              deadBoidTemplateName := "{deadBoidTemplateName}+{swarm__deadBoidFiredTemplateName}"

            reCreateEntityFrom(boid_eid, deadBoidTemplateName)