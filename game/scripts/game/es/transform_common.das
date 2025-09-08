module transform_common shared
require ecs
require ecs.safe
require math.base
require DagorMath


def is_point_in_box_or_sphere_zone(point : float3;
                                   zone_pos : float3;
                                   zone_itm : float3x4;
                                   zone_radius_sq : float)
  if zone_radius_sq > 0.0
    if distance_sq(zone_pos, point) <= zone_radius_sq
      return true
  return IDENT_BBOX & (zone_itm * point)


def is_point_in_box_zone(pos : float3; transform : float3x4)
  let zonePos = inverse(transform) * pos
  return IDENT_BBOX & zonePos


def is_point_in_sphere_zone(point : float3;
                            zone_pos : float3;
                            zone_radius_sq : float)
  return distance_sq(zone_pos, point) <= zone_radius_sq
