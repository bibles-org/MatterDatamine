require ecs
require app
require DagorMath
require Dacoll
require DngNet
require GamePhys
require DngHelicopter
require game.events.events
require game.events.events_active_matter
require Grid


[es(no_order, REQUIRE=isDrone, REQUIRE_NOT=helicopter)]
def drone_ccd_es(act : CmdPostPhysUpdate;
                 eid : EntityId;
                 drone__maxSpeed : float;
                 transform aka drone_transform : float3x4;
                 helicopter__ccdUnstuckEnabled : bool;
                 helicopter__ccdUnstuckVelocityPerTime : float;
                 helicopter__ccdUnstuckTimeBetweenCollisions : float;
                 helicopter__ccdUnstuckVelocityToExplode : float;
                 var helicopter_net_phys : HelicopterActor;
                 var helicopter__ccdLastCollisionTime : float&;
                 var helicopter__ccdUnstuckVelocity : float&;
                 isAlive : bool = true;
                 helicopter__ccdSphereOffset : float3 = float3(0.0, 0.5, 0.0);
                 helicopter__ccdSphereRadius : float = 0.45;
                 helicopter__ccdVelocityReductionMult : float = 0.35;
                 helicopter__ccdNoDriverMinVelocitySq : float = 1.0;
                 helicopter__ccdMinVelocityAfterCollision : float = 0.25)
  assume previousState = helicopter_net_phys.phys.previousState
  assume currentState = helicopter_net_phys.phys.currentState

  if distance_sq(previousState.location.P, currentState.location.P) <= 1e-6
    return

  let currentVelocitySq = length_sq(currentState.velocity)
  if currentVelocitySq < helicopter__ccdNoDriverMinVelocitySq
    return

  let previousCcdOffset = previousState.location.O.quat * helicopter__ccdSphereOffset
  let previousCcdPos = float3(previousState.location.P) + previousCcdOffset
  let currentCcdOffset = currentState.location.O.quat * helicopter__ccdSphereOffset
  let currentCcdPos = float3(currentState.location.P) + currentCcdOffset

  var ccdCastRes = ShapeQueryOutput()
  if sphere_cast(previousCcdPos, currentCcdPos, helicopter__ccdSphereRadius, ccdCastRes, -1)
    if currentVelocitySq > drone__maxSpeed * drone__maxSpeed
      sendEvent(eid, DroneDestroyEvent())
      return
    let curTime = get_sync_time()
    let timeFromLastCollision = curTime - helicopter__ccdLastCollisionTime

    let isServer = is_server()

    if isAlive && helicopter__ccdUnstuckEnabled
      if timeFromLastCollision <= helicopter__ccdUnstuckTimeBetweenCollisions
        helicopter__ccdUnstuckVelocity += timeFromLastCollision * helicopter__ccdUnstuckVelocityPerTime
        if helicopter__ccdUnstuckVelocity >= helicopter__ccdUnstuckVelocityToExplode
          helicopter__ccdUnstuckVelocity = 0.0
          if isServer
            sendEvent(eid, DroneDestroyEvent())
            return
      else
        helicopter__ccdUnstuckVelocity = 0.0
    else
      helicopter__ccdUnstuckVelocity = 0.0

    let currentVelocity = sqrt(currentVelocitySq)

    // Workaround ccd realization. Very primitive arcade collision simulation.
    // No network synchronization. Used only to protect against flying in collisions.
    // It is recommended to replace it with something more serious in the future.
    let velocityAfterCcd = max(helicopter__ccdMinVelocityAfterCollision + helicopter__ccdUnstuckVelocity,
                               currentVelocity * helicopter__ccdVelocityReductionMult) * ccdCastRes.norm
    currentState.velocity = velocityAfterCcd
    let penetration = (currentCcdPos - previousCcdPos) * (1.0 - ccdCastRes.t)
    let correctedPos = (currentCcdPos - penetration) - currentCcdOffset
    currentState.location.P = DPoint3(correctedPos)

    helicopter__ccdLastCollisionTime = curTime

  if (currentVelocitySq > drone__maxSpeed * drone__maxSpeed)
    var is_crash = false

    let dir = normalize(currentState.velocity)
    var dirT = 0.3f
    var outVel : float3
    is_crash = trace_game_objects(drone_transform[3], dir, dirT, outVel, int(uint(eid)), -1)
    if is_crash
      sendEvent(eid, DroneDestroyEvent())
      return

    let sphere = BSphere3(drone_transform[3], 0.1f)
    for_each_entity_in_grid(ecs_hash("loot"), sphere, GridEntCheck.BOUNDING) <| $ [unused_argument(smEid)] (smEid : EntityId)
      is_crash = true
    if is_crash
      sendEvent(eid, DroneDestroyEvent())
      return

    var waterLevel = 0.
    let hasWater = traceht_water(drone_transform[3], waterLevel)
    is_crash = hasWater && waterLevel > drone_transform[3].y
    if is_crash
      sendEvent(eid, DroneDestroyEvent())
      return
