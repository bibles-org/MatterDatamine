require app
require ecs
require math.base
require DagorMath
require DagorSystem
require walkerai
require pathfinder
require DagorMathUtils
require DngWalkerai
require GamePhys
require danetlibs.navmesh_phys.main.nphys_events
require danetlibs.navmesh_phys.main.nphys_common
require danetlibs.pathfinder.main.pathfinder_common
require math.shooter_phys_common

[es(tag=server)]
def nphys_push_handler(evt : CmdPushPhys;
                       nphys_pushable__lockDuration : float;
                       navmesh_phys__currentPos : float3;
                       navmesh_phys__currentPoly : int64;
                       var obstacle_avoider__updateAt : float?;
                       var navmesh_phys__currentWalkVelocity : float3&;
                       var nphys_pushable__unlockMovementAt : float&)
  nphys_pushable__unlockMovementAt = get_sync_time() + nphys_pushable__lockDuration
  if obstacle_avoider__updateAt != null
    *obstacle_avoider__updateAt = 0.0

  let pushSpd = length(evt.vel)
  var pushDir = evt.vel * safeinv(pushSpd)
  let walkNormal = get_surface_normal_by_pos(navmesh_phys__currentPos, dtPolyRef(navmesh_phys__currentPoly))
  let dirToNormalDot = dot(pushDir, walkNormal)
  if dirToNormalDot < 0.0
    pushDir = pushDir - walkNormal * 2.f * dirToNormalDot
  let curProj = dot(navmesh_phys__currentWalkVelocity, pushDir)
  if curProj < pushSpd
    navmesh_phys__currentWalkVelocity += pushDir * (pushSpd - max(curProj, 0.f))


[es(tag=server, before=update_navmesh_phys, REQUIRE_NOT=(deadEntity, nphys__disabled))]
def nphys_push_update(act : UpdateStageInfoAct;
                      navmesh_phys__timeStep : float;
                      agent_obstacles : AgentObstacles;
                      navmesh_phys__maxWalkSpeed : float;
                      navmesh_phys__friction : float;
                      var navmesh_phys__currentPoly : int64&;
                      var navmesh_phys__atTime : float&;
                      var navmesh_phys__prevTime : float&;
                      var navmesh_phys__prevPos : float3&;
                      var navmesh_phys__currentPos : float3&;
                      var navmesh_phys__currentWalkVelocity : float3&;
                      var nphys_pushable__unlockMovementAt : float&;
                      var nphys_pushable__prevElevation : float&;
                      var nphys_pushable__elevation : float&)
  while navmesh_phys__atTime < act.curTime && navmesh_phys__atTime <= nphys_pushable__unlockMovementAt
    let dt = navmesh_phys__timeStep

    navmesh_phys__currentWalkVelocity.y -= gravity() * dt

    nphys_pushable__prevElevation = nphys_pushable__elevation
    navmesh_phys__prevPos = navmesh_phys__currentPos
    let stepBefore = navmesh_phys__currentWalkVelocity * dt
    var collisionResult = collide_with_obstacles(navmesh_phys__currentPos, stepBefore.xz, agent_obstacles)
    collisionResult.step.y = stepBefore.y
    if collisionResult.hasCollided
      collisionResult.vel.y = stepBefore.y
      navmesh_phys__currentWalkVelocity = collisionResult.vel * safeinv(dt)
    navmesh_phys__currentPos += x0z(collisionResult.step)

    nphys_pushable__elevation += collisionResult.step.y

    let extents = float3(0.5)
    using(navmesh_phys__prevPos, navmesh_phys__currentPos, extents) <| $(var req : FindRequest#)
      req.startPoly = uint64(navmesh_phys__currentPoly)
      if move_along_surface(req)
        //Account for moving downhill/uphill
        let surfaceDelta = req.end.y - navmesh_phys__prevPos.y
        nphys_pushable__elevation = max(0.0, nphys_pushable__elevation + collisionResult.step.y - surfaceDelta)
        if !collisionResult.hasCollided
          //resulting velocity is deduced based on move_along_surface resulting movement.
          //But collide_with_obstacles may have already altered the velocity, so movement this step doesn't represent the velocity
          //So don't change the velocity if collide_with_obstacles did it
          var delta = req.end - navmesh_phys__prevPos
          delta.y = collisionResult.step.y
          navmesh_phys__currentWalkVelocity = delta * safeinv(dt)


        navmesh_phys__currentPos = req.end
        navmesh_phys__currentPoly = int64(req.endPoly)

    navmesh_phys__prevTime = navmesh_phys__atTime
    navmesh_phys__atTime += dt

    if nphys_pushable__elevation > 0.01
      nphys_pushable__unlockMovementAt = max(nphys_pushable__unlockMovementAt, navmesh_phys__atTime + dt * 2.0)
    else
      navmesh_phys__currentWalkVelocity *= phys_calc_friction_mult(length(navmesh_phys__currentWalkVelocity),
          navmesh_phys__maxWalkSpeed, navmesh_phys__friction, dt)
      navmesh_phys__currentWalkVelocity.y = -nphys_pushable__elevation


[es(tag=server, after=(move_navmesh_phys_pos, move_navmesh_phys_lookdir), REQUIRE_NOT=(deadEntity, nphys__disabled))]
def lerp_nphys_height(act : UpdateStageInfoAct;
                      navmesh_phys__prevTime : float;
                      navmesh_phys__atTime : float;
                      nphys_pushable__unlockMovementAt : float;
                      nphys_pushable__prevElevation : float;
                      nphys_pushable__elevation : float;
                      var transform : float3x4)
  //As of now, height > 0 or prevHeight > 0 implies that navmesh_phys__atTime <= nphys_pushable__unlockMovementAt
  if nphys_pushable__unlockMovementAt >= act.curTime
    let step = navmesh_phys__atTime - navmesh_phys__prevTime
    if step > 0f
      let k = (act.curTime - navmesh_phys__prevTime) / step
      let targetHeight = lerp(nphys_pushable__prevElevation, nphys_pushable__elevation, k)
      transform[3].y += targetHeight