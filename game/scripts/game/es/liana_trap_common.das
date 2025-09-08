module liana_trap_common shared
require ecs
require app
require math
require math.base
require game.events.events
require DagorMath
require DagorRandom
require Dacoll
require AnimV20
require GeomNodeTree
require game.events.events_active_matter

def add_liana_tentacle(liana_eid : EntityId)
  var newTentacle = INVALID_ENTITY_ID
  query(liana_eid) <| $ [es] (liana_trap__tentacleTemplate : string;
                              transform : float3x4;
                              sphere_zone__radius : float;
                              liana_trap__maxDist : float;
                              liana_trap__deviationDirVel : float;
                              liana_trap__verticalGrowTime : float)
    newTentacle = createEntity(liana_trap__tentacleTemplate) <| $(init)
      set(init, "liana_tentacle__lianaEid", liana_eid)
      set(init, "liana_tentacle__spawnedAt", get_sync_time())
      let devVel = liana_trap__deviationDirVel * (0.5 + 0.5 * gfrnd())
      let devDir = gfrnd() > 0.5 ? 1.0 : -1.0
      set(init, "liana_tentacle__deviationDirVel", devDir * devVel)
      let vertGrowTime = (0.5 + 0.5 * gfrnd()) * liana_trap__verticalGrowTime
      set(init, "liana_tentacle__verticalGrowTime", vertGrowTime)
      let angle = gfrnd() * TWOPI
      let radius = gfrnd() * sphere_zone__radius
      var s, c : float
      sincos(angle, s, c)
      let randomPoint1 = transform[3] + float3(c, 0.0, s) * radius
      let randomPoint2 = randomPoint1 + float3(c, 0.0, s) * (radius + 0.1)
      set(init, "liana_tentacle__fromPos", randomPoint1)
      set(init, "liana_tentacle__toPos", randomPoint2)
      set(init, "liana_tentacle__maxLength", liana_trap__maxDist)
  return newTentacle


def assign_params_from_attach_node(tentacle_eid, attach_node_eid : EntityId; animchar : AnimcharBaseComponent)
  var success = false
  query(attach_node_eid) <| $ [es] (liana_attach_node__name : string;
                                    liana_attach_node__numCoilPoints : int;
                                    liana_attach_node__radius : float;
                                    liana_attach_node__num : float;
                                    liana_attach_node__thickness : float;
                                    liana_attach_node__dealsDamage : bool)
    let nodeId = geomtree_findNodeIndex(*animchar.nodeTree, liana_attach_node__name)
    if nodeId >= 0
      query(tentacle_eid) <| $ [es] (var liana_tentacle__nodeId : int&;
                                     var liana_tentacle__attachNodeEid : EntityId&;
                                     var liana_tentacle__dealsDamage : bool&;
                                     var liana_tentacle__coilThickness : float&;
                                     var liana_tentacle__numCoils : float&;
                                     var liana_tentacle__coilRadius : float&;
                                     var liana_tentacle__numCoilPoints : int&)
        success = true
        liana_tentacle__attachNodeEid = attach_node_eid
        liana_tentacle__nodeId = nodeId
        liana_tentacle__dealsDamage = liana_attach_node__dealsDamage
        liana_tentacle__coilThickness = liana_attach_node__thickness
        liana_tentacle__numCoils = liana_attach_node__num
        liana_tentacle__coilRadius = liana_attach_node__radius
        liana_tentacle__numCoilPoints = liana_attach_node__numCoilPoints
  return success


def set_tentacle_target(tentacle_eid : EntityId; animchar : AnimcharBaseComponent; tier : int)
  var tierNodes : array<EntityId>
  query() <| $ [es] (eid : EntityId; liana_attach_node__tier : int)
    if tier == liana_attach_node__tier
      push(tierNodes, eid)
  let roffs = grnd() % length(tierNodes)
  var success = false
  for i in iter_range(tierNodes)
    let idx = (i + roffs) % length(tierNodes)
    success = assign_params_from_attach_node(tentacle_eid, tierNodes[idx], animchar)
    if success
      break
  return success


def apply_tentacle_phys(var spline_gen_geometry__points : Point3List; from, to : int; segmentLength : float)
  for j in range(from + 1, to)
    assume midPoint = spline_gen_geometry__points[j]
    assume nextPoint = spline_gen_geometry__points[j - 1]
    if j < to - 1
      let prevPoint = spline_gen_geometry__points[j + 1]
      let fromPrev = midPoint - prevPoint
      if length(fromPrev) > VERY_SMALL_NUMBER
        if dot(normalize(fromPrev), normalize(nextPoint - midPoint)) < 0.90
          //Avoid crisp turns
          let avg = (prevPoint + nextPoint) * 0.5
          midPoint = midPoint * 0.95 + avg * 0.05
    let nextToMid = midPoint - nextPoint
    let thisLength = length(nextToMid)
    if j > 1
      if thisLength > segmentLength
        let half = nextToMid / thisLength * (thisLength - segmentLength) * 0.5
        if j != to - 1
          midPoint -= half
        nextPoint += half
    else
      midPoint = nextPoint + normalize(nextToMid) * min(thisLength, segmentLength)


def kill_liana_tentacle(eid : EntityId)
  query(eid) <| $ [es] (liana_tentacle__lianaEid : EntityId;
                        liana_tentacle__cooldownPerInjury : float;
                        var liana_tentacle__attachNodeEid : EntityId&;
                        var liana_tentacle__nodeId : int&;
                        var liana_tentacle__aliveAt : float&;
                        var liana_tentacle__isAttached : bool&;
                        var liana_tentacle__toPos : float3&)
    query(liana_tentacle__lianaEid) <| $ [es] (liana_trap__maxDist : float;
                                               liana_trap__injury : float)
      liana_tentacle__aliveAt = get_sync_time() + liana_tentacle__cooldownPerInjury * liana_trap__injury
      liana_tentacle__nodeId = -1
      liana_tentacle__attachNodeEid = INVALID_ENTITY_ID
      liana_tentacle__isAttached = false
      var t = liana_trap__maxDist
      tracedown_normalized(liana_tentacle__toPos, t, ETF_DEFAULT)
      liana_tentacle__toPos = liana_tentacle__toPos + float3(.0, -1.0, .0) * t


//x' = (x + k * dt) * exp ^ (nu * dt)
//nu and k are calculated based on desired max_value and half_life
def decay(value, max_value, half_life, dt, linear_increment : float)
  let nu = exp(calc_nu(half_life) * dt)
  let inc = -max_value * (nu - 1.0) * linear_increment
  return (value + inc) * nu

def calc_nu(half_life : float)
  return -safediv(log(2.0), half_life)

def apply_ct_to_look_dir(controls : float2; look_dir : float3)
  let normDir = cross(look_dir, float3(.0, 1.0, .0))
  return look_dir * controls.x + normDir * controls.y