options no_global_variables = false

require ecs
require DagorConsole
require CapsuleApproximation
require AnimV20
require GeomNodeTree
require math.base
require math.random
require GamePhys
require active_matter.game.es.skeleton_swarm_state_common
require game.events.events_active_matter


struct SwarmOwner
  eid : EntityId
  aiState : int
  resetSkeleton : bool
  pos : float3
  forciblyMoveDistSq : float
  animchar : AnimcharBaseComponent const?
  capsules : CapsuleApproximation const?
  radiusMulti : float


var seed = 42


def rnd_float_pow(a : float2; pow = 16f)
  return lerp(a.x, a.y, saturate(pow(_frnd(seed), pow)))


[es(tag=render, no_order, REQUIRE=attachedSkeletonSwarm)]
def move_skeleton_swarm_with_owner(act : ParallelUpdateFrameDelayed; eid, game_effect__attachedTo : EntityId;
                                   attached_skeleton__burningEffectTemplate : string;
                                   attached_skeleton__forciblyMoveDistSq : float;
                                   attached_skeleton__standMoveSpeed, attached_skeleton__moveSpeed : float;
                                   var attached_skeleton__burningEffectEid : EntityId&;
                                   var swarm__obstacleAversionDistance, swarm__groundAvoidanceDistStart, swarm__groundAvoidanceMin : float&;
                                   var attached_skeleton__resetSkeleton : bool&;
                                   var attached_skeleton__wishFlyOffset, attached_skeleton__currentflyOffset : float3&;
                                   var position, swarm_cluster__targetPos : float3&;
                                   var swarm__moveSpeed : float&;
                                   attached_skeleton__moveOffset = float3(0., 0.8, 0.))
  query(game_effect__attachedTo) <| $ [es] (transform : float3x4; skeleton_swarm__aiState : int; burning__isBurning = false)
    let skeleton = skeleton_swarm__aiState == int(SkeletonSwarmAiState.SKELETON_STAND) || skeleton_swarm__aiState == int(SkeletonSwarmAiState.DEAD)
    let inMove = skeleton_swarm__aiState == int(SkeletonSwarmAiState.MOVE)
    let lastPosition = position
    position = transform[3] + (inMove ? attached_skeleton__moveOffset : float3(0., 0.3, 0.))
    swarm__moveSpeed = inMove ? attached_skeleton__moveSpeed : attached_skeleton__standMoveSpeed
    if inMove
      attached_skeleton__currentflyOffset = approach(attached_skeleton__currentflyOffset, attached_skeleton__wishFlyOffset, act.dt, 0.9)
      position += attached_skeleton__currentflyOffset
    swarm_cluster__targetPos = position
    attached_skeleton__wishFlyOffset = approach(attached_skeleton__wishFlyOffset, float3(0), act.dt, 0.9)
    if skeleton
      if !has(eid, "swarmCustomSteering")
        eid |> addSubTemplate("swarm_custom_steering")
    else // fly
      if eid |> has("swarmCustomSteering")
        eid |> removeSubTemplate("swarm_custom_steering")
      attached_skeleton__resetSkeleton = true
      let dist = inMove ? attached_skeleton__moveOffset.y + attached_skeleton__wishFlyOffset.y : 0f
      swarm__obstacleAversionDistance = dist
      swarm__groundAvoidanceDistStart = dist
      swarm__groundAvoidanceMin = dist

      let curPos = transform[3]
      if distance_sq(lastPosition, curPos) > attached_skeleton__forciblyMoveDistSq
        query() <| $ [es(REQUIRE=attachedSkeletonBoid, REQUIRE_NOT=boidDead)] (parentSwarm : EntityId;
                                                                               var position : float3&)
          if parentSwarm == eid
            position = curPos

    if !burning__isBurning
      if attached_skeleton__burningEffectEid != INVALID_ENTITY_ID
        destroyEntity(attached_skeleton__burningEffectEid)
        attached_skeleton__burningEffectEid = INVALID_ENTITY_ID
    else
      if attached_skeleton__burningEffectEid == INVALID_ENTITY_ID && !empty(attached_skeleton__burningEffectTemplate)
        attached_skeleton__burningEffectEid = createEntity(attached_skeleton__burningEffectTemplate) <| $(init)
          var tm = IDENT_TM
          tm[3] = position
          init |> set("transform", tm)
          init |> set("effect_animation__transform", tm)
      query(attached_skeleton__burningEffectEid) <| $ [es] (var transform : float3x4&)
        transform[3] = position


[es(tag=render, no_order)]
def update_boid_state(act : ParallelUpdateFrameDelayed)
  var swarms : table<uint; SwarmOwner>
  query() <| $ [es(REQUIRE=(swarmCustomSteering, attachedSkeletonSwarm))] (eid aka swarm_eid : EntityId;
                                                                           attached_skeleton__forciblyMoveDistSq : float;
                                                                           attached_skeleton__radiusMult : float = 1.0;
                                                                           game_effect__attachedTo : EntityId;
                                                                           var attached_skeleton__resetSkeleton : bool&)
    query(game_effect__attachedTo) <| $ [es(REQUIRE=(animchar, capsule_approximation))] (skeleton_swarm__aiState : int = int(SkeletonSwarmAiState.MOVE);
                                                                                         transform : float3x4;
                                                                                         animchar : AnimcharBaseComponent const?;
                                                                                         @shared_comp capsule_approximation : CapsuleApproximation const?)
      swarms.insert(uint(swarm_eid), SwarmOwner(eid = game_effect__attachedTo, aiState = skeleton_swarm__aiState,
                                            resetSkeleton = attached_skeleton__resetSkeleton,
                                            forciblyMoveDistSq = attached_skeleton__forciblyMoveDistSq,
                                            pos = transform[3], animchar = animchar, capsules = capsule_approximation,
                                            radiusMulti = attached_skeleton__radiusMult))
      attached_skeleton__resetSkeleton = false

  if length(swarms) == 0
    return

  query() <| $ [es(REQUIRE=(attachedSkeletonBoid, boidDead))] (eid : EntityId; var staying_time : float&;
                                                               var velocity : float3&; var orientation_quat : vec4f&; var position : float3&)
    velocity += float3(0f, -gravity() / 2f * act.dt, 0f)
    let prevPos = position
    position += velocity * act.dt

    let lookDir = normalize(position - prevPos)
    orientation_quat = float4(dir_to_quat(lookDir))

    staying_time -= act.dt
    if staying_time < 0f
      destroyEntity(eid)

  query() <| $ [es(REQUIRE=attachedSkeletonBoid, REQUIRE_NOT=boidDead)] (parentSwarm : EntityId;
                                                                         boid__radiusRange = float2(0.03, 0.3);
                                                                         boid__nodeTimeStepRange = float2(0.1, 0.2);
                                                                         boid__angleStepRange = float2(100, 100);
                                                                         var boid__nodeIdx : int&;
                                                                         var boid__nodeTime : float&; var boid__nodeTimeStep : float&;
                                                                         var boid__angle : float&; var boid__angleStep : float&;
                                                                         var boid__targetPosition : float3&; var boid__radius : float&;
                                                                         var orientation_quat : vec4f&;
                                                                         var position : float3&)
    swarms |> get(uint(parentSwarm)) <| $(ownerData)

      let resetState = boid__radius <= 0f
      if resetState || ownerData.resetSkeleton
        boid__nodeIdx = _rnd(seed) % length(ownerData.capsules.capsuleDatas)
        boid__nodeTimeStep = (_frnd(seed) < 0.5 ? 1f : -1f) * _rnd_float(seed, boid__nodeTimeStepRange)
        boid__nodeTime = _frnd(seed)
        boid__radius = rnd_float_pow(boid__radiusRange)
        boid__angle = TWOPI * _frnd(seed)
        boid__angleStep = _rnd_float(seed, boid__angleStepRange)
        boid__targetPosition = position

      assume capsuleData = ownerData.capsules.capsuleDatas[boid__nodeIdx]
      var tm : float3x4
      geomtree_getNodeWtmScalar(*ownerData.animchar.nodeTree, int(capsuleData.nodeIndex), tm)

      if distance_sq(boid__targetPosition, position) < 0.01
        boid__angle += boid__angleStep
        boid__nodeTime += boid__nodeTimeStep

        if boid__nodeTime < 0f || boid__nodeTime > 1f
          boid__radius = rnd_float_pow(boid__radiusRange)
          boid__angleStep = _rnd_float(seed, boid__angleStepRange)

          var nearestNode = boid__nodeIdx
          var nearestNodeTime = 0f
          var nearestNodeDistSq = 0.1
          for i in iter_range(ownerData.capsules.capsuleDatas)
            if i == boid__nodeIdx
              continue
            assume nextData = ownerData.capsules.capsuleDatas[i]
            var nextTm : float3x4
            geomtree_getNodeWtmScalar(*ownerData.animchar.nodeTree, int(nextData.nodeIndex), nextTm)
            let aDistSq = distance_sq(nextTm * nextData.a, boid__targetPosition)
            if aDistSq < nearestNodeDistSq
              nearestNodeDistSq = aDistSq
              nearestNodeTime = 0f
              nearestNode = i
            let bDistSq = distance_sq(nextTm * nextData.b, boid__targetPosition)
            if bDistSq < nearestNodeDistSq
              nearestNodeDistSq = bDistSq
              nearestNodeTime = 1f
              nearestNode = i
          if nearestNode != boid__nodeIdx
            boid__nodeIdx = nearestNode
            boid__nodeTime = nearestNodeTime
            boid__nodeTimeStep = (nearestNodeTime < 0.5 ? 1f : -1f) * _rnd_float(seed, boid__nodeTimeStepRange)
            assume newCapsuleData = ownerData.capsules.capsuleDatas[boid__nodeIdx]
            geomtree_getNodeWtmScalar(*ownerData.animchar.nodeTree, int(newCapsuleData.nodeIndex), tm)
          else
            boid__nodeTimeStep = -boid__nodeTimeStep
            boid__nodeTime += boid__nodeTimeStep

        assume actualCapsuleData = ownerData.capsules.capsuleDatas[boid__nodeIdx]
        let addDir = normalize(actualCapsuleData.b - actualCapsuleData.a) * actualCapsuleData.rad
        boid__targetPosition = lerp(actualCapsuleData.a - addDir, actualCapsuleData.b + addDir, float3(boid__nodeTime))

        var s, c : float
        sincos(boid__angle, s, c)
        boid__targetPosition.y += c * boid__radius * ownerData.radiusMulti
        boid__targetPosition.z += s * boid__radius * ownerData.radiusMulti

        boid__targetPosition = tm * boid__targetPosition

        if ownerData.aiState == int(SkeletonSwarmAiState.MOVE)
          let targetDir = boid__targetPosition - position
          let offsetScale = 0.6
          let offset = normalize(float3(1f, s * offsetScale, c * offsetScale))
          let quat = dir_to_quat(offset)
          boid__targetPosition = position + quat * targetDir

      let prevPos = position
      let dirToPos = boid__targetPosition - prevPos
      let distToPosSq = length_sq(dirToPos)
      let distToPos = sqrt(distToPosSq)
      if !resetState && distToPosSq < ownerData.forciblyMoveDistSq
        position = approach(position, boid__targetPosition, act.dt, 0.2)
      else
        position = boid__targetPosition

      let lookDir = dirToPos * safeinv(distToPos)
      orientation_quat = float4(dir_to_quat(lookDir))


[es(before=boids_spawner, on_appear, REQUIRE=attachedSkeletonSwarm)]
def init_skeleton_swarm_with_owner(evt : Event; game_effect__attachedTo : EntityId; var position, swarm_cluster__targetPos : float3&)
  query(game_effect__attachedTo) <| $ [es] (transform : float3x4)
    position = transform[3]
    swarm_cluster__targetPos = position
