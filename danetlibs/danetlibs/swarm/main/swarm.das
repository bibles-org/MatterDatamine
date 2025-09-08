require ecs
require swarm
require level
require Dacoll
require DagorMath
require DagorRandom
require danetlibs.swarm.main.swarm_events


let
  CREATION_SEED = 10111


def create_boid(template_name : string;
                var seed : int&;
                radius : float;
                position : float3;
                lmesh_orientation : bool;
                swarm__projectOnGround : bool;
                parent_eid : EntityId;
                swarm__animationSpeed : float;
                ground_avoidance_dist_start : float;
                swarm_idx : int)
  let upDir = float3(0.0, 1.0, 0.0)
  var pos = normalize(float3(_srnd(seed), _srnd(seed), _srnd(seed))) * radius + position
  var orientationQuat = quat(upDir, PI * _srnd(seed))

  if lmesh_orientation
    let lmeshY = traceht_lmesh(pos)
    if lmeshY > pos.y
      pos.y = lmeshY
  else
    pos += float3(0.0, 100.0, 0.0)
    var t = swarm__projectOnGround ? 200.0 : 100.0
    var outNorm : float3
    if tracedown_normalized(pos, t, outNorm, ETF_DEFAULT)
      orientationQuat = orientationQuat * quat_rotation_arc(upDir, outNorm)
    pos.y -= t

  createEntity(template_name) <| $(var init)
    init |> setVec4f("orientation_quat", orientationQuat)
    init |> set("position", pos)
    init |> set("boid_state", BOID_STAYING + int(uint32_hash(uint(seed))) % BOID_STATE_MUL)
    init |> set("boid_animationSpeed", swarm__animationSpeed)
    init |> set("groundAvoidanceDist", ground_avoidance_dist_start)
    init |> set("parentSwarm", parent_eid)
    init |> set("parentSwarmIdx", swarm_idx)


[es(tag=gameClient, on_appear, on_event=EventLevelLoaded,
  REQUIRE=boids_spawner, REQUIRE_NOT=(steer__dasScript, flying_critters))]
def boids_spawner(evt : Event;
                  eid : EntityId;
                  var boids_spawner__created : bool&;
                  count = 5000)
  if !is_level_loaded() || boids_spawner__created
    return
  sendEvent(eid, EventSomeSwarmBoidBorn(count = count))
  boids_spawner__created = true


[es(REQUIRE_NOT=(steer__dasScript, flying_critters))]
def boids_born_request(evt : EventSomeSwarmBoidBorn;
                       eid : EntityId;
                       swarm__boidTemplateName : string;
                       var swarmIdx : int&;
                       swarm__lmeshOrientation = false;
                       swarm__projectOnGround = true;
                       swarm__groundAvoidanceDistStart = 40.0;
                       swarm__animationSpeed : float;
                       radius = 25.0;
                       position = float3(0.0, 30.0, 0.0))
  if swarmIdx < 0 // new swarm
    var currentSwarmIdxs : array<int>
    query() <| $ [es] (swarmIdx : int)
      if swarmIdx >= 0
        currentSwarmIdxs |> push(swarmIdx)
    currentSwarmIdxs |> sort()

    for i in iter_range(currentSwarmIdxs)
      if currentSwarmIdxs[i] != i
        swarmIdx = i
        break
    if swarmIdx < 0
      swarmIdx = length(currentSwarmIdxs)

  var seed = CREATION_SEED
  for _ in range(evt.count)
    create_boid(swarm__boidTemplateName,
                seed,
                radius,
                position,
                swarm__lmeshOrientation,
                swarm__projectOnGround,
                eid,
                swarm__animationSpeed,
                swarm__groundAvoidanceDistStart,
                swarmIdx)


[es(tag=gameClient, REQUIRE=(boidIdle, boidAriseByShooting), REQUIRE_NOT=(invulnerableBoid, boid__disabled))]
def boid_arise_on_shoot(evt : EventProjectileFlight;
                        eid, parentSwarm : EntityId;
                        boid_state : int;
                        var staying_time : float&;
                        var position : float3&)
  if abs(evt.dist) < 1.0e-5f
    return
  query(parentSwarm) <| $ [es] (projectileTargetSwarm : Tag const?;
                                flyingSwarmObject : Tag const?;
                                steer__dasScript : Tag const?;
                                flying_critters : Tag const?)
    let hasProjectileTargetSwarmTag = projectileTargetSwarm != null
    let hasFlyingSwarmObjectTag = flyingSwarmObject != null
    let hasSteerDasScriptTag = steer__dasScript != null
    let hasDasSwarmTag = flying_critters != null
    if !(hasProjectileTargetSwarmTag && hasFlyingSwarmObjectTag) || hasSteerDasScriptTag || hasDasSwarmTag
      return

    var seed = boid_state
    staying_time = _frnd(seed) * 0.1
    position.y += 0.05
    reCreateEntityFrom(eid, "boidElement")


[es(tag=render, before=steer_es, parallel_for=64, REQUIRE=boidElement, REQUIRE_NOT=boid__disabled)]
def update_boids_prev_positions(act : UpdateStageInfoAct;
                                position : float3;
                                orientation_quat : vec4f;
                                boid_animationSpeed : float;
                                var boid_state : int&;
                                var prevPosition : float3&;
                                var prev_orientation_quat : vec4f&;
                                var prev_boid_state : int&)
  let dt = int(act.dt * (float(BOID_STATE_MASK) * boid_animationSpeed))
  prevPosition = position
  prev_orientation_quat = orientation_quat
  prev_boid_state = boid_state
  boid_state = (boid_state & ~BOID_STATE_MASK) | ((boid_state + dt) & BOID_STATE_MASK)


[es(tag=render, track=swarm__animationSpeed, REQUIRE=flyingSwarmObject)]
def track_swarm_anim_speed(evt : Event; eid : EntityId; swarm__animationSpeed : float)
  query() <| $ [es(REQUIRE=boidElement)] (parentSwarm : EntityId; var boid_animationSpeed : float&)
    if eid == parentSwarm
      boid_animationSpeed = swarm__animationSpeed

[es(on_appear)]
def oscillating_cluster_init_prev_pos(evt : Event;
                                      transform : float3x4;
                                      var oscillating_swarm__prevPos : float3&;
                                      var oscillating_swarm__forward : float3&;
                                      var oscillating_swarm__side : float3&)
  oscillating_swarm__prevPos = transform[3]
  oscillating_swarm__forward = transform[0]
  oscillating_swarm__side = transform[2]


[es(on_appear)]
def init_oscillating_boid(evt : Event;
                          var oscillating_boid__oscilationAngle : float&;
                          var oscillating_boid__lateralAngle : float&;
                          var oscillating_swarm__oscilationRadiusMulti : float&)
  oscillating_boid__lateralAngle = gfrnd() * 2.0 * PI
  oscillating_boid__oscilationAngle = gfrnd() * 2.0 * PI
  oscillating_swarm__oscilationRadiusMulti = sqrt(gfrnd())