require ecs
require AnimV20
require GamePhys
require PhysDecl
require DagorMath
require DagorSystem
require DngWeapon
require danetlibs.navmesh_phys.main.nphys_common
require danetlibs.navmesh_phys.main.nphys_jumplink_climb_common
require debug.logerr_once



[es(tag=server, after=beh_tree_update_es, before=update_navmesh_phys, REQUIRE_NOT=(nphys__disabled, nphys__climbDisabled))]
def nmesh_phys_should_climb(act : UpdateStageInfoAct;
                            var navmesh_phys__shouldClimbUp : bool&;
                            path_corridor__overJumpLink : bool; navmesh_phys__climbMinHeight : float;
                            path_corridor__jumpLinkStart, path_corridor__jumpLinkEnd : float3)
  navmesh_phys__shouldClimbUp = should_climb(path_corridor__overJumpLink, path_corridor__jumpLinkStart, path_corridor__jumpLinkEnd, navmesh_phys__climbMinHeight)

[es(tag=server, after=(beh_tree_update_es, nmesh_phys_should_climb), before=update_navmesh_phys,
    REQUIRE_NOT=(navmesh_phys__climbJumpStartSpeed, nphys__disabled, nphys__climbDisabled))]
def scale_jumplink_climb_speed(act : UpdateStageInfoAct;
                               navmesh_phys__shouldClimbUp : bool;
                               path_corridor__jumpLinkEnd : float3;
                               var navmesh_phys__prevPos : float3&;
                               var navmesh_phys__currentPos : float3&;
                               navmesh_phys__climbSpeed : float;
                               navmesh_phys__defaultClimbHeight : float;
                               nphys_levitating__elevation : float = .0;
                               var navmesh_phys__currentWalkVelocity : float3&;
                               var path_corridor__isClimbing : bool&;
                               var path_corridor__prevDstToJLEndSq : float&)
  if navmesh_phys__shouldClimbUp
    path_corridor__isClimbing = true
    path_corridor__prevDstToJLEndSq = distance_sq(navmesh_phys__currentPos, path_corridor__jumpLinkEnd)
    let restHeight = max(0f, path_corridor__jumpLinkEnd.y - navmesh_phys__currentPos.y + nphys_levitating__elevation)
    let progress = saturate(1f - safediv(restHeight, navmesh_phys__defaultClimbHeight))
    let scale = pow(progress, 3.)
    navmesh_phys__currentWalkVelocity = path_corridor__jumpLinkEnd - navmesh_phys__currentPos + float3(.0, nphys_levitating__elevation, .0)
    // slowdown horizontal speed
    navmesh_phys__currentWalkVelocity.x *= scale
    navmesh_phys__currentWalkVelocity.z *= scale
    navmesh_phys__currentWalkVelocity = normalize(navmesh_phys__currentWalkVelocity) * navmesh_phys__climbSpeed

    navmesh_phys__prevPos = navmesh_phys__currentPos
    let posDelta = navmesh_phys__currentWalkVelocity * act.dt
    navmesh_phys__currentPos += posDelta

[es(tag=server, after=(beh_tree_update_es, nmesh_phys_should_climb), before=update_navmesh_phys, REQUIRE_NOT=(nphys__disabled, nphys__climbDisabled))]
def scale_jumplink_jump_speed(act : UpdateStageInfoAct;
                              eid : EntityId;
                              navmesh_phys__shouldClimbUp : bool;
                              path_corridor__overJumpLinkStart : bool;
                              var path_corridor__jumpLinkStart : float3&;
                              path_corridor__jumpLinkEnd : float3;
                              var navmesh_phys__prevPos : float3&;
                              var navmesh_phys__currentPos : float3&;
                              navmesh_phys__climbJumpStartSpeed : float;
                              var path_corridor__isClimbing : bool&;
                              var navmesh_phys__climbJumpStartVelocity : float3&;
                              var navmesh_phys__currentWalkVelocity : float3&;
                              var path_corridor__prevDstToJLEndSq : float&)
  if !navmesh_phys__shouldClimbUp
    return

  // shouldJump == true
  if !path_corridor__isClimbing
    path_corridor__jumpLinkStart = navmesh_phys__currentPos
    send_path_corridor_jump_link_start_end_changed_event(eid, path_corridor__jumpLinkStart, path_corridor__jumpLinkEnd)
    path_corridor__isClimbing = true
    path_corridor__prevDstToJLEndSq = distance_sq(navmesh_phys__currentPos, path_corridor__jumpLinkEnd)
    if calculate_arc_low_start_dir(path_corridor__jumpLinkStart, path_corridor__jumpLinkEnd, navmesh_phys__climbJumpStartSpeed, navmesh_phys__climbJumpStartVelocity)
      navmesh_phys__climbJumpStartVelocity *= navmesh_phys__climbJumpStartSpeed
      navmesh_phys__currentWalkVelocity = navmesh_phys__climbJumpStartVelocity
    elif path_corridor__overJumpLinkStart
      //logerr_once("{eid}: failed to find jump arc with params navmesh_phys__currentPos={navmesh_phys__currentPos}, path_corridor__jumpLinkEnd={path_corridor__jumpLinkEnd}, navmesh_phys__climbJumpStartSpeed={navmesh_phys__climbJumpStartSpeed}")
      navmesh_phys__climbJumpStartVelocity = float3()
      let walkDir = normalize(path_corridor__jumpLinkEnd - path_corridor__jumpLinkStart)
      navmesh_phys__currentWalkVelocity = navmesh_phys__climbJumpStartSpeed * walkDir
    else
      path_corridor__isClimbing = false
      return
  elif length_sq(navmesh_phys__climbJumpStartVelocity) > .0
    let curVelY = navmesh_phys__currentWalkVelocity.y - gravity() * act.dt
    navmesh_phys__currentWalkVelocity.x = navmesh_phys__climbJumpStartVelocity.x
    navmesh_phys__currentWalkVelocity.y = curVelY
    navmesh_phys__currentWalkVelocity.z = navmesh_phys__climbJumpStartVelocity.z
  navmesh_phys__prevPos = navmesh_phys__currentPos
  let posDelta = navmesh_phys__currentWalkVelocity * act.dt
  navmesh_phys__currentPos += posDelta


[es(tag=server, after=(beh_tree_update_es, nmesh_phys_should_climb), before=update_navmesh_phys, REQUIRE_NOT=(nphys__disabled, nphys__climbDisabled))]
def scale_falldown_speed(act : UpdateStageInfoAct;
                         path_corridor__overJumpLink : bool;
                         navmesh_phys__shouldClimbUp : bool;
                         path_corridor__jumpLinkEnd : float3;
                         navmesh_phys__maxWalkSpeed : float;
                         navmesh_phys__walkSpeedMult : float = 1.0;
                         navmesh_phys__acceleration : float;
                         var navmesh_phys__currentWalkVelocity : float3&;
                         var path_corridor__isClimbing : bool&;
                         var navmesh_phys__prevPos : float3&;
                         var navmesh_phys__currentPos : float3&;
                         var path_corridor__prevDstToJLEndSq : float&)
  if path_corridor__overJumpLink && !navmesh_phys__shouldClimbUp
    if !path_corridor__isClimbing
      path_corridor__isClimbing = true
      path_corridor__prevDstToJLEndSq = distance_sq(navmesh_phys__currentPos, path_corridor__jumpLinkEnd)
    let walkDir = normalize(path_corridor__jumpLinkEnd - navmesh_phys__currentPos)
    let wishVel = navmesh_phys__maxWalkSpeed * navmesh_phys__walkSpeedMult
    let wishAccel = navmesh_phys__maxWalkSpeed * navmesh_phys__acceleration
    navmesh_phys__currentWalkVelocity = length(navmesh_phys__currentWalkVelocity) * walkDir
    navmesh_phys__currentWalkVelocity = accelerate_dir(navmesh_phys__currentWalkVelocity, walkDir, wishVel, wishAccel, act.dt)

    navmesh_phys__prevPos = navmesh_phys__currentPos
    let posDelta = navmesh_phys__currentWalkVelocity * act.dt
    navmesh_phys__currentPos += posDelta
