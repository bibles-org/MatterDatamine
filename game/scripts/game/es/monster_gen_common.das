module monster_gen_common shared

require ecs
require ecs.common
require level
require math.base

def find_unoccupied_regions_in_the_zone(moving_zone__sourceRadius : float;
                                        moving_zone__sourcePos : float3;
                                        monster_gen_gen__type aka this_monster_gen__type : string;
                                        monster_gen_gen__regions : StringList)
  var occupiedRegions : array<string>
  var freeRegions : array<string>
  query() <| $ [es] (monster_gen__region, monster_gen__type aka another_monster_gen__type : string)
    if this_monster_gen__type == another_monster_gen__type
      occupiedRegions |> push(monster_gen__region)
  query() <| $ [es] (custom_region__name : string; transform : float3x4)
    if distance_sq(transform[3], moving_zone__sourcePos) < square(moving_zone__sourceRadius)
      if !has_value(occupiedRegions, custom_region__name) && has_value(monster_gen_gen__regions, custom_region__name)
        freeRegions |> push(custom_region__name)
  return <- freeRegions


def is_point_in_monster_gen_forbidden_zone(pos : float3)
  return find_query() <| $ [es] (monster_generator_forbidden_zone__radius : float;
                                 transform : float3x4)
    return distance_sq(transform[3], pos) < square(monster_generator_forbidden_zone__radius)