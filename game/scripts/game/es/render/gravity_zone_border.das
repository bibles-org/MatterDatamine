require ecs
require game.es.grav_zones_common
require DagorMathUtils


def build_effect_transform(militant_transform : float3x4;
                           closest_point : float3;
                           var effect_transform : float3x4&;
                           effect__scale : float = 1.0)
  let fwd = normalize(militant_transform[3] - closest_point)
  let up = get_some_normal(fwd)//militant_transform[1]
  let right = cross(up, fwd)
  // effect is rotated 90 degrees around z axis, so transform is built accordingly
  effect_transform[0] = up * effect__scale
  effect_transform[1] = fwd * effect__scale
  effect_transform[2] = right * effect__scale
  effect_transform[3] = closest_point


def is_point_inside_another_gravity_zone(point : float3; parent_zone : EntityId)
  return find_query() <| $ [es(REQUIRE=grav_zone__type, REQUIRE_NOT=allow_inner_gravity_zones_visual_effects)] (eid aka zone_eid : EntityId)
    return zone_eid != parent_zone && is_inside_gravity_zone(point, zone_eid)


[es(no_order, REQUIRE=watchedByPlr, tag=gameClient)]
def update_gravity_zone_border_fx(update : UpdateStageInfoAct;
                                  transform : float3x4;
                                  gravity_zone_border__maxRadius : float;
                                  gravity_zone_border__effectName : string)
  var militant_transform = transform
  // vertical offset to make effect appear at a proper height and face militant directly
  militant_transform[3] += militant_transform[1]
  // 1. update current zones (with relevant subtemplate)
  query() <| $ [es] (eid aka zone_eid : EntityId; var gravity_zone_with_visual_effect__effect : EntityId&)
    let closestPoint = calc_gravity_zone_closest_border_point(zone_eid, militant_transform[3])
    let distance = length(closestPoint - militant_transform[3])
    // sidestep weirdness at a very close distance
    if distance < 1e-6
      return

    // remove effect of zone is too far
    if distance > gravity_zone_border__maxRadius || is_point_inside_another_gravity_zone(closestPoint, zone_eid)
      destroyEntity(gravity_zone_with_visual_effect__effect)
      gravity_zone_with_visual_effect__effect = INVALID_ENTITY_ID
      removeSubTemplate(zone_eid, "gravity_zone_with_visual_effect")
      return

    // update effect for a still relevant zone
    query(gravity_zone_with_visual_effect__effect) <| $ [es] (effect__scale : float; var transform aka effect_transform : float3x4&)
      build_effect_transform(militant_transform, closestPoint, effect_transform,  effect__scale)

  // 2. find new zones. Cool thing is that recently deleted zones will be ignored, as their subtemplate is only scheduled for deletion
  // TODO: search in a grid
  query() <| $ [es(REQUIRE_NOT=gravity_zone_with_visual_effect__effect, REQUIRE=grav_zone__type)] (eid aka zone_eid : EntityId)
    let closestPoint = calc_gravity_zone_closest_border_point(zone_eid, militant_transform[3])
    let distance = length(closestPoint - militant_transform[3])
    if distance > gravity_zone_border__maxRadius || is_point_inside_another_gravity_zone(closestPoint, zone_eid)
      return

    let effect = createEntity(gravity_zone_border__effectName) <| $(init)
      var tm : float3x4
      build_effect_transform(militant_transform, closestPoint, tm)
      set(init, "transform", tm)

    addSubTemplate(zone_eid, "gravity_zone_with_visual_effect") <| $(init)
      set(init, "gravity_zone_with_visual_effect__effect", effect)
  return


[es(on_disappear)]
def clear_gravity_zone_border_effect(evt : Event; gravity_zone_with_visual_effect__effect : EntityId)
  destroyEntity(gravity_zone_with_visual_effect__effect)
