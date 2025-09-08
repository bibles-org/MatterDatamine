module grav_zones_common shared
require ecs
require DagorMath
require math.base
require DagorSystem
require DngHuman
require PhysDecl
require Grid

let gridSphereRadius = 1.0

enum GravityZoneType
  LINEAR = 0
  RADIAL
  RADIAL_INVERTED
  CYLINDRICAL


def gravity_force(zone_tm : float3x4;
                  phys_pos : float3;
                  zone_type : int)
  if zone_type == int(GravityZoneType.LINEAR)
    return normalize(zone_tm[1])
  elif zone_type == int(GravityZoneType.RADIAL)
    return normalize(zone_tm[3] - phys_pos)
  elif zone_type == int(GravityZoneType.RADIAL_INVERTED)
    return normalize(phys_pos - zone_tm[3])
  elif zone_type == int(GravityZoneType.CYLINDRICAL)
    let dirVec = phys_pos - zone_tm[3]
    return normalize(zone_tm[2] * dot(dirVec, zone_tm[2]) - dirVec)
  else
    logerr("[Gravity Zone] Unknown gravity zone type: <{zone_type}>")
  return float3(0.0)


struct PossibleClosestBorderPoint
  projLen : float
  projPoint : float3


def calc_gravity_sphere_zone_closest_border_point(phys_pos : float3; zone_transform : float3x4; gravity_zone_radius : float)
  return zone_transform[3] + normalize(phys_pos - zone_transform[3]) * gravity_zone_radius


def calc_gravity_box_zone_closest_border_point(phys_pos : float3; grav_zone__itm : float3x4; zone_transform : float3x4; gravity_zone__boxSize : float3)
  let physPosBoxCoords = grav_zone__itm * phys_pos

  let bbox = BBox3(-gravity_zone__boxSize * 0.5, gravity_zone__boxSize * 0.5)
  let isInside = bbox & physPosBoxCoords
  if !isInside
    // When point is outside it is easy to find the closest border point:
    // just clamp each coordinate independently
    let resBoxCoords = float3(
      clamp(physPosBoxCoords.x, bbox.boxMin.x, bbox.boxMax.x),
      clamp(physPosBoxCoords.y, bbox.boxMin.y, bbox.boxMax.y),
      clamp(physPosBoxCoords.z, bbox.boxMin.z, bbox.boxMax.z)
    )
    return zone_transform * resBoxCoords
  else
    /*  When point is inside, we need to determine the closest border point. Example in 2d
        Here depending on wich of the 4 values [x, a-x, y, b-y] is the smallest, we determine
        wich projection to choose. In 3d it is similar, but we project to the closest face of the box.

    (0, b) __________________________ (a, b)
          |\     |                  /|
          | \    1                 / |
          |-2|--------------------|4-|
          | /               3      \ |
    (0,0) |/________________|_______\| (a, 0)
    */
    let possibleResults = [PossibleClosestBorderPoint(projLen = physPosBoxCoords.x - bbox.boxMin.x, projPoint = float3(bbox.boxMin.x, physPosBoxCoords.y, physPosBoxCoords.z)), // Front
                           PossibleClosestBorderPoint(projLen = bbox.boxMax.x - physPosBoxCoords.x, projPoint = float3(bbox.boxMax.x, physPosBoxCoords.y, physPosBoxCoords.z)), // Back
                           PossibleClosestBorderPoint(projLen = physPosBoxCoords.y - bbox.boxMin.y, projPoint = float3(physPosBoxCoords.x, bbox.boxMin.y, physPosBoxCoords.z)), // Bot
                           PossibleClosestBorderPoint(projLen = bbox.boxMax.y - physPosBoxCoords.y, projPoint = float3(physPosBoxCoords.x, bbox.boxMax.y, physPosBoxCoords.z)), // Top
                           PossibleClosestBorderPoint(projLen = physPosBoxCoords.z - bbox.boxMin.z, projPoint = float3(physPosBoxCoords.x, physPosBoxCoords.y, bbox.boxMin.z)), // Left
                           PossibleClosestBorderPoint(projLen = bbox.boxMax.z - physPosBoxCoords.z, projPoint = float3(physPosBoxCoords.x, physPosBoxCoords.y, bbox.boxMin.z))  // Right
    ]
    var minLen = possibleResults[0].projLen
    var res = possibleResults[0].projPoint
    for possbleRes in possibleResults
      if possbleRes.projLen < minLen
        minLen = possbleRes.projLen
        res = possbleRes.projPoint
    return zone_transform * res


def calc_gravity_cylinder_zone_closest_border_point(phys_pos : float3;
                                                    grav_zone__itm : float3x4;
                                                    zone_transform : float3x4;
                                                    cylinder_length : float;
                                                    cylinder_radius : float)
  let physPosCylinderCoords = grav_zone__itm * phys_pos

  let isBetweenSides = abs(dot(physPosCylinderCoords, float3(0.0, 0.0, 1.0))) <= cylinder_length
  let isInTube = length_sq(float3(physPosCylinderCoords.x, physPosCylinderCoords.y, 0.0)) <= square(cylinder_radius)
  // outside, closest point is projection to one of the sides
  if isInTube && !isBetweenSides
    if physPosCylinderCoords.z > 0.0
      let projectionRight = float3(physPosCylinderCoords.x, physPosCylinderCoords.y, cylinder_length)
      return zone_transform * projectionRight
    else
      let projectionLeft = float3(physPosCylinderCoords.x, physPosCylinderCoords.y, -cylinder_length)
      return zone_transform * projectionLeft
  // outside, closest point is projection to the tube
  elif !isInTube && isBetweenSides
    let axisProjection = float3(0.0, 0.0, physPosCylinderCoords.z)
    return zone_transform * (axisProjection + normalize(float3(physPosCylinderCoords.x, physPosCylinderCoords.y, 0.0)) * cylinder_radius)
  // outside, closest point is projection to one of the border circles
  elif !isInTube && !isBetweenSides
    var circleProjection = normalize(float3(physPosCylinderCoords.x, physPosCylinderCoords.y, 0.0)) * cylinder_radius
    if physPosCylinderCoords.z > 0.0
      circleProjection.z = cylinder_length
    else
      circleProjection.z = -cylinder_length
    return zone_transform * circleProjection
  // inside the cylinder. Choose minimum between tube and side projections
  else
    let rightProjection = float3(physPosCylinderCoords.x, physPosCylinderCoords.y, cylinder_length)
    let leftProjection = float3(physPosCylinderCoords.x, physPosCylinderCoords.y, -cylinder_length)
    let sideProjection = physPosCylinderCoords.z > 0.0 ? rightProjection : leftProjection
    let tubeProjection = normalize(float3(physPosCylinderCoords.x, physPosCylinderCoords.y, 0.0)) * cylinder_radius + float3(0.0, 0.0, physPosCylinderCoords.z)
    let closest = length_sq(physPosCylinderCoords - sideProjection) < length_sq(physPosCylinderCoords - tubeProjection) ? sideProjection : tubeProjection
    return zone_transform * closest


// if INSIDE the zone, still returns a point on the BORDER
def calc_gravity_zone_closest_border_point(zone : EntityId; phys_pos : float3)
  var res = float3(0.0)

  query(zone) <| $ [es] (transform aka zone_transform : float3x4;
                         grav_zone__itm : float3x4;
                         grav_zone__outerRadius : float const?;
                         gravity_zone__boxSize : float3 const?;
                         grav_zone__length : float const?;
                         grav_zone__radius : float const?)
    // 1. sphere zone
    if grav_zone__outerRadius != null
      res = calc_gravity_sphere_zone_closest_border_point(phys_pos, zone_transform, *grav_zone__outerRadius)
    // 2. box zone
    elif gravity_zone__boxSize != null
      res = calc_gravity_box_zone_closest_border_point(phys_pos, grav_zone__itm, zone_transform, *gravity_zone__boxSize)
    // 3. cylinder
    elif grav_zone__length != null && grav_zone__radius != null
      res = calc_gravity_cylinder_zone_closest_border_point(phys_pos, grav_zone__itm, zone_transform, *grav_zone__length, *grav_zone__radius)
    else
      error("calc_gravity_zone_closest_border_point: unknown zone type (<{zone}> \"{getEntityTemplateName(zone)}\"")
  return res


def is_inside_sphere_zone(pos : float3;
                          zone_tm : float3x4;
                          zone_outer_radius : float)
  return length_sq(pos - zone_tm[3]) < square(zone_outer_radius)


def calc_gravity_for_sphere(zone_tm, zone_itm : float3x4;
                            phys_pos : float3;
                            zone_type : int;
                            zone_inner_radius, zone_outer_radius : float;
                            grav_zone__weight : float;
                            grav_zone__level : int;
                            var zone_wt : float&;
                            var zone_force : float3&;
                            var zone_level : int&)
  let distSq = length_sq(zone_itm * phys_pos)
  if distSq > 1e-6 && distSq < square(zone_outer_radius)
    let dist = sqrt(distSq)
    let wt = cvt(dist, zone_inner_radius, zone_outer_radius, grav_zone__weight, 0.0)
    zone_wt = wt
    zone_force = gravity_force(zone_tm, phys_pos, zone_type) * wt
    zone_level = grav_zone__level
    return true
  return false


def is_inside_box_zone(pos : float3;
                       zone_itm : float3x4;
                       zone_box_size : float3)
  let posLS = zone_itm * pos
  return BBox3(-zone_box_size * 0.5, zone_box_size * 0.5) & posLS


def safediv(a, b)
  return float3(abs(b.x) > FLT_EPSILON ? a.x / b.x : 1.f,
                abs(b.y) > FLT_EPSILON ? a.y / b.y : 1.f,
                abs(b.z) > FLT_EPSILON ? a.z / b.z : 1.f)


def calc_gravity_for_box(zone_tm, zone_itm : float3x4;
                         phys_pos : float3;
                         zone_type : int;
                         zone_box_size : float3;
                         zone_scale : float3;
                         border_x : float2;
                         border_y : float2;
                         border_z : float2;
                         grav_zone__weight : float;
                         grav_zone__level : int;
                         var zone_wt : float&;
                         var zone_force : float3&;
                         var zone_level : int&)
  let posLS = zone_itm * phys_pos
  if BBox3(-zone_box_size * 0.5, zone_box_size * 0.5) & posLS
    let topLS = float3(border_x.y, border_y.y, border_z.y) / zone_scale
    let botLS = float3(border_x.x, border_y.x, border_z.x) / zone_scale
    let k = min(safediv(zone_box_size * 0.5 - posLS, topLS), safediv(zone_box_size * 0.5 + posLS, botLS), float3(1.f))
    let wt = k.x * k.y * k.z * grav_zone__weight // triple linear interpolation
    zone_wt = wt
    zone_force = gravity_force(zone_tm, phys_pos, zone_type) * wt
    zone_level = grav_zone__level
    return true
  return false


def is_inside_cylinder_zone(pos : float3;
                            zone_tm : float3x4;
                            zone_itm : float3x4;
                            zone_length : float;
                            zone_radius : float)
  let posLS = zone_itm * pos
  let dirVec = pos - zone_tm[3]
  let isOkByLen = abs(dot(dirVec, zone_tm[2])) <= zone_length
  let isOkByRad = length_sq(float3(posLS.x, posLS.y, 0.0)) <= square(zone_radius)
  return isOkByLen && isOkByRad


def calc_gravity_for_cylinder(zone_tm, zone_itm : float3x4;
                              phys_pos : float3;
                              zone_type : int;
                              zone_length : float;
                              zone_radius : float;
                              grav_zone__weight : float;
                              grav_zone__level : int;
                              var zone_wt : float&;
                              var zone_force : float3&;
                              var zone_level : int&)
  let posLS = zone_itm * phys_pos
  let dirVec = phys_pos - zone_tm[3]
  let isOkByLen = abs(dot(dirVec, zone_tm[2])) <= zone_length
  let isOkByRad = length_sq(float3(posLS.x, posLS.y, 0.0)) <= square(zone_radius)
  if isOkByLen && isOkByRad
    zone_wt = grav_zone__weight
    zone_force = gravity_force(zone_tm, phys_pos, zone_type) * grav_zone__weight
    zone_level = grav_zone__level
    return true
  return false

//Note: there may be more than one
def find_gravity_zone(pos : float3)
  let sphere = BSphere3(pos, gridSphereRadius)
  var res : EntityId
  find_entity_in_grid(ecs_hash("gravity_zones"), sphere, GridEntCheck.BOUNDING) <| $ [es] (zone_eid : EntityId)
    query(zone_eid) <| $ [es] (transform : float3x4;
                               grav_zone__itm : float3x4;
                               eid : EntityId;
                               grav_zone__outerRadius : float const?;
                               gravity_zone__boxSize : float3 const?;
                               grav_zone__length : float const?;
                               grav_zone__radius : float const?)
      if grav_zone__outerRadius != null
        if is_inside_sphere_zone(pos, transform, *grav_zone__outerRadius)
          res = eid
      elif gravity_zone__boxSize != null
        if is_inside_box_zone(pos, grav_zone__itm, *gravity_zone__boxSize)
          res = eid
      elif grav_zone__length != null && grav_zone__radius != null
        if is_inside_cylinder_zone(pos, transform, grav_zone__itm, *grav_zone__length, *grav_zone__radius)
          res = eid
      else
        error("is_inside_gravity_zone: unknown zone type (<{eid}> \"{getEntityTemplateName(eid)}\" [{transform[3]}]")
    return res != INVALID_ENTITY_ID
  return res


def is_inside_gravity_zone(pos : float3; zone : EntityId)
  var res = false
  query(zone) <| $ [es] (transform : float3x4;
                         grav_zone__itm : float3x4;
                         grav_zone__outerRadius : float const?;
                         gravity_zone__boxSize : float3 const?;
                         grav_zone__length : float const?;
                         grav_zone__radius : float const?)
    if grav_zone__outerRadius != null
      res = is_inside_sphere_zone(pos, transform, *grav_zone__outerRadius)
    elif gravity_zone__boxSize != null
      res = is_inside_box_zone(pos, grav_zone__itm, *gravity_zone__boxSize)
    elif grav_zone__length != null && grav_zone__radius != null
      res = is_inside_cylinder_zone(pos, transform, grav_zone__itm, *grav_zone__length, *grav_zone__radius)
    else
      error("is_inside_gravity_zone: unknown zone type (<{zone}> \"{getEntityTemplateName(zone)}\" [{transform[3]}]")
  return res


def are_grav_zones_loaded()
  var res = false
  find_query() <| $ [es] (level__levelLoaded, level__gameObjectsEntitiesCreated, level__localSceneEntitiesCreated : bool)
    res = level__levelLoaded && level__gameObjectsEntitiesCreated && level__localSceneEntitiesCreated
    return true
  return res


def wake_me_up_when_gravzones_are_loaded(eid : EntityId)
  var prereqLoaded = false
  find_query() <| $ [es] (level__levelLoaded, level__gameObjectsEntitiesCreated, level__localSceneEntitiesCreated : bool;
                          var level__retriggerEids : EidList)
    prereqLoaded = level__levelLoaded && level__gameObjectsEntitiesCreated && level__localSceneEntitiesCreated
    if !prereqLoaded
      level__retriggerEids |> push(eid)
    return true
  return !prereqLoaded


def calc_grav_dir_from_weight_and_force(total_force : float3; total_weight : float; upDir : float3 = float3(0.0, 1.0, 0.0))
  let normForceUpDir = normalize(total_force)
  let rotAxis = normalize(cross(upDir, total_force))
  var finalQuat = dir_and_up_to_quat(upDir, rotAxis)
  if total_weight >= 1.0
    finalQuat = dir_and_up_to_quat(normForceUpDir, rotAxis)
  elif total_weight > 0.0
    finalQuat = slerp(finalQuat, dir_and_up_to_quat(normForceUpDir, rotAxis), total_weight)

  return -quat_get_forward(finalQuat)


def calc_zone_gravity_if_inside(zone_eid : EntityId; pos : float3; var zone_force : float3&; var zone_weight : float&; var zone_level : int&)
  var isInside = false
  var queried = false
  query(zone_eid) <| $ [es] (transform, grav_zone__itm : float3x4;
                             grav_zone__outerRadius : float;
                             grav_zone__innerRadius : float;
                             grav_zone__weight : float;
                             grav_zone__level : int;
                             grav_zone__type : int)
    queried = true
    isInside = calc_gravity_for_sphere(transform, grav_zone__itm, pos, grav_zone__type,
                              grav_zone__innerRadius, grav_zone__outerRadius,
                              grav_zone__weight, grav_zone__level,
                              zone_weight, zone_force, zone_level)

  if queried
    return isInside

  query(zone_eid) <| $ [es] (transform, grav_zone__itm : float3x4;
                             grav_zone__precalcScale : float3;
                             gravity_zone__boxSize : float3;
                             grav_zone__boxBorderX : float2;
                             grav_zone__boxBorderY : float2;
                             grav_zone__boxBorderZ : float2;
                             grav_zone__weight : float;
                             grav_zone__level : int;
                             grav_zone__type : int)
    queried = true
    isInside = calc_gravity_for_box(transform, grav_zone__itm, pos, grav_zone__type, gravity_zone__boxSize, grav_zone__precalcScale,
                         grav_zone__boxBorderX, grav_zone__boxBorderY, grav_zone__boxBorderZ, grav_zone__weight, grav_zone__level,
                         zone_weight, zone_force, zone_level)

  if queried
    return isInside

  query(zone_eid) <| $ [es] (transform, grav_zone__itm : float3x4;
                             grav_zone__length, grav_zone__radius : float;
                             grav_zone__weight : float;
                             grav_zone__level : int;
                             grav_zone__type : int)
    queried = true
    isInside = calc_gravity_for_cylinder(transform, grav_zone__itm, pos, grav_zone__type,
                              grav_zone__length, grav_zone__radius, grav_zone__weight, grav_zone__level,
                              zone_weight, zone_force, zone_level)

  return isInside


def get_grav_dir(var zones : array<tuple<level : int; weight : float; force : float3>>)
  sort(zones) <| $(a, b) { return a.level < b.level; }

  var lastLevelUp = float3(0.0, 1.0, 0.0)
  var curLevel = 0
  var curForce = float3(0.0, 0.0, 0.0)
  var curWeight = 0.0

  for zone in zones
    if zone.level > curLevel
      curLevel = zone.level
      lastLevelUp = -calc_grav_dir_from_weight_and_force(curForce, curWeight, lastLevelUp)
      curForce = float3(0.0, 0.0, 0.0)
      curWeight = 0.0
    curForce += zone.force
    curWeight += zone.weight

  return calc_grav_dir_from_weight_and_force(curForce, curWeight, lastLevelUp)


def get_grav_dir(phys_pos : float3; allow_premature_calls = false)

  if !allow_premature_calls && get_DAECS_EXTENSIVE_CHECKS() != 0
    find_query() <| $ [es] (var level__gravDirRequested : bool&)
      level__gravDirRequested = true
      return true

  let sphere = BSphere3(phys_pos, gridSphereRadius)
  var zones : array<tuple<level : int; weight : float; force : float3>>
  for_each_entity_in_grid(ecs_hash("gravity_zones"), sphere, GridEntCheck.BOUNDING) <| $(zone_eid : EntityId)
    var zone_force = float3(0.0, 0.0, 0.0)
    var zone_weight = 0.0
    var zone_level = 0
    if calc_zone_gravity_if_inside(zone_eid, phys_pos, zone_force, zone_weight, zone_level)
      zones |> push((zone_level, zone_weight, zone_force))

  return get_grav_dir(zones)


def build_grav_tm(point : float3;
                  grav_dir : float3)

  let up = -grav_dir
  let forward = normalize(perpendicular(-grav_dir))

  var tm : float3x4
  tm[0] = forward
  tm[1] = up
  tm[2] = cross(forward, up)
  tm[3] = point

  return tm


def get_grav_tm(point : float3; allow_premature_calls = false)
  return build_grav_tm(point, get_grav_dir(point, allow_premature_calls))


def set_grav_for_phys_body(dt : float; var body : PhysBody?)
  var tm : float3x4
  phys_body_getTm(*body, tm)
  let baseGravity = -float3(0f, gravity(), 0f) * dt
  let bodyGravDir = get_grav_dir(tm[3], true) * gravity() * dt
  let vel = phys_body_getVelocity(*body) + bodyGravDir - baseGravity
  phys_body_setVelocity(*body, vel, true)

//There is no good mathematical way to do it consistently.
def rotate_vec_to_new_zone(vec, from_grav, to_grav)
  let rotateAxis = normalize(cross(from_grav, to_grav))
  if length_sq(rotateAxis) < 0.1
    return vec //grav vectors are too similar, rounding errors dominate
  else
    return quat_rotation_arc(from_grav, to_grav) * vec
