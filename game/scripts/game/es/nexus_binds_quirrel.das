require ecs
require ecs.ecs_quirrel
require game.es.nexus_loadout_common


[quirrel_bind(module_name="das.nexus")]
def get_generator_indexes_bind(seed : int; generators_count : int; loadouts_count : int)
  return get_generator_indexes(seed, generators_count, loadouts_count)
