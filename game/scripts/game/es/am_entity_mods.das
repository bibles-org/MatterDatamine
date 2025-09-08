require ecs
require game.es.entity_mods_common


[es(on_event=EventOnModsChanged, track=entity_mods__visualAttractMaxDistMultMods)]
def entity_change_visual_attract_max_dist(evt : Event; var entity_mods__visualAttractMaxDistMult : float&;
                                          entity_mods__visualAttractMaxDistMultMods : Object)
  entity_mods__visualAttractMaxDistMult = calc_change_mult_attr(entity_mods__visualAttractMaxDistMultMods)


[es(on_event=EventOnModsChanged, track=entity_mods__attractPointSearchRadiusMultMods)]
def entity_change_attract_max_search_radius(evt : Event; var entity_mods__attractPointSearchRadiusMult : float&;
                                            entity_mods__attractPointSearchRadiusMultMods : Object)
  entity_mods__attractPointSearchRadiusMult = calc_change_mult_attr(entity_mods__attractPointSearchRadiusMultMods)
