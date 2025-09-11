require ecs
require math.base
require Plane
require DngPlane
require DagorMath
require GamePhys
require CollRes

[cpp_event(broadcast)]
struct UpdatePhysEvent
  curTime : float
  dt : float

[cpp_event(unicast)]
struct QueryPhysActorsNotCollidable
  shouldCollide : bool
  otherEid : EntityId

[cpp_event(unicast)]
struct EventOnGunPayloadCreated
  gunEid : EntityId
  index : int
  pos_in : float3
  mass_in : float
  drag_in : float
  ammo_in : int

[cpp_event(unicast)]
struct EventOnGunsPayloadAmmoUpdate
  ammoEid : EntityId
  ammoList : IntList

[cpp_event(unicast)]
struct EventOnGunsPayloadDestroyed
  gunEid : ecs::EntityId

[es(before=after_net_phys_sync, after=before_net_phys_sync, on_event=UpdatePhysEvent, REQUIRE_NOT=disableUpdate)]
def set_wind_to_plane_phys_es(evt : Event;
                              var plane_net_phys : PlaneActor&)
  if get_difficulty().Wind_N_Turbulence
    let wind = get_wind()
    plane_net_phys.phys.currentState.Vwind = DPoint3(double(wind.x), double(wind.y), double(wind.z))
    let maxTurbulence = min(abs(float(plane_net_phys.phys.currentState.Vwind.x)) + abs(float(plane_net_phys.phys.currentState.Vwind.z)), 15.0f)
    plane_net_phys.phys.turbStr = cvt(plane_net_phys.phys.currentAlt, 20.f, 400.f, maxTurbulence, 0.1f)

  else
    plane_net_phys.phys.currentState.Vwind = DPoint3(0.lf, 0.lf, 0.lf)
    plane_net_phys.phys.turbStr = 0.0f


[es(before=after_net_phys_sync, after=before_net_phys_sync, REQUIRE_NOT=disableUpdate)]
def seaplane_anchor_phys_es(info : UpdatePhysEvent;
                            transform : float3x4;
                            var plane_net_phys : PlaneActor&;
                            var parking_anchor_pos : float3&;
                            var parking_anchor_dir : float3&;
                            is_seaplane : bool = true;
                            operable : bool = true;
                            is_parking_brake_on : bool = true)
  if !is_seaplane || !operable || !is_parking_brake_on
    return

  let anchorSpeedThreshold = 3.0f
  assume velocity = plane_net_phys.phys.currentState.velocity
  let vel_x0z = float3(float(velocity.x), 0.f, float(velocity.z))
  if length_sq(vel_x0z) > square(anchorSpeedThreshold)
    return

  if length_sq(parking_anchor_pos.xz - transform[3].xz) > 1.0f
    parking_anchor_pos = transform[3]
    parking_anchor_dir = transform[0]

  var vect = x0z(parking_anchor_pos) - x0z(transform[3])
  if dot(vel_x0z, vect) < 0.f
    velocity.x = 0.lf
    velocity.z = 0.lf

  vect *= length(vect)
  let wishForce = vect * plane_net_phys.phys.M.state.mass * 10.0f
  assume externalForce = plane_net_phys.phys.currentState.externalForce
  externalForce.x = approach(externalForce.x, wishForce.x, info.dt, 0.2f)
  externalForce.z = approach(externalForce.z, wishForce.z, info.dt, 0.2f)
  let parking_anchor_dir_xz = float2(float(parking_anchor_dir.x), float(parking_anchor_dir.z))

  let dotProduct = dot(parking_anchor_dir_xz, transform[2].xz)
  plane_net_phys.phys.currentState.omega.y = double(approach(float(plane_net_phys.phys.currentState.omega.y), dotProduct, info.dt, 0.2f))


[es(on_appear)]
def plane_spawn_in_the_air_es(evt : Event;
                              transform : float3x4;
                              var plane_net_phys : PlaneActor&;
                              setupOnGround : bool = true;
                              startRelativeSpeed : float;
                              startRelativeSpeedVMin : float = -1.0;
                              startRelativeSpeedVMax : float = -1.0;
                              startPowerControlAll : float = -1.0;
                              startVelDir : float3 = float3(1.0, 0.0, 0.0))
  if setupOnGround
    return

  assume phys = plane_net_phys.phys
  phys |> flight_model_startEngines()

  assume propulsion = *phys.EI
  propulsion |> propulsion_setEnginesRunning(phys)

  if startRelativeSpeed >= 0.0
    let startDir = normalize(transform[0] * startVelDir.x + transform[1] * startVelDir.y + transform[2] * startVelDir.z)
    let vMin = startRelativeSpeedVMin > 0.0 ? startRelativeSpeedVMin : phys.Vmin
    let vMax = startRelativeSpeedVMax > 0.0 ? startRelativeSpeedVMax : phys.Vmax
    let startSpd = lerp(vMin, vMax, startRelativeSpeed)
    phys |> flight_model_forcePower(1.f, -1)
    phys |> flight_model_forceLeftAndRightBrakeControls(1.f)
    propulsion |> propulsion_setEnginesSpeedByPower(phys.appliedCT.powerAverage)
    phys |> flight_model_setVelocityRough(startDir * startSpd)

  if phys.bHasGearControl
    phys |> flight_model_forceGear(0.0f)

  if startPowerControlAll >= 0.0
    phys |> flight_model_setPowerControlAll(startPowerControlAll)


[es(no_order, REQUIRE=airplane)]
def deny_collision_for_exploded_airplane_es(var evt : QueryPhysActorsNotCollidable&;
                                            isExploded : bool)
  if isExploded
    evt.shouldCollide = false


def is_on_water(var planePhysCollisionContext : PlanePhysCollisionContext; pos : float3; time : float; at_tick : int)
  var height = 0.f
  var mat = 0
  var norm = float3(0.f, 0.f, 0.f)
  var isWater = false
  var landHeight = 0.f
  var waterHeight = 0.f
  planePhysCollisionContext |> flight_model_traceDownSurface(pos, time, at_tick, height, mat, norm, isWater, landHeight, waterHeight)
  return isWater

[es(on_appear)]
def plane_spawn_on_the_ground_es(evt : Event;
                                 collres : CollisionResource;
                                 var plane_net_phys : PlaneActor&;
                                 setup_on_ground__setupMaxHeight : float = 2000.0f;
                                 setupOnGround : bool = true)

  if !setupOnGround
    return

  assume phys = plane_net_phys.phys
  phys |> flight_model_forcePower(0.f, -1)
  phys |> flight_model_stopEngines()
  phys |> flight_model_forceLeftAndRightBrakeControls(1.f)

  assume propulsion = *phys.EI
  propulsion |> propulsion_setEnginesStops()
  propulsion |> propulsion_setEnginesOmega(0.0f)
  propulsion |> propulsion_setEnginesTurboChargerOmega(0.0f)

  using(collres) <| $(var planePhysCollisionContext : PlanePhysCollisionContext)
    if phys.bHasGearControl
      let isOnWater = is_on_water(planePhysCollisionContext, float3(phys.currentState.location.P), float(phys.currentState.atTick) * phys.timeStep, phys.currentState.atTick)
      assume gear = *plane_net_phys.phys.Gears
      if isOnWater != gear.props.haveWheels
        phys |> flight_model_forceGear(1.f)
      else
        phys |> flight_model_forceGear(0.f)
    else
      phys |> flight_model_forceGear(0.f)

    let speed = float3()
    if phys |> flight_model_setupOnGround(planePhysCollisionContext, true, speed, setup_on_ground__setupMaxHeight)
      var physTm : float3x4
      phys.currentState.location |> location_toTM(physTm)
      plane_net_phys |> plane_actor_teleportTo(physTm, true)
    else
      phys |> flight_model_setVelocityRough(float3())
