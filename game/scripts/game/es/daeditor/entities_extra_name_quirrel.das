require ecs.ecs_quirrel
require game.es.daEditor.entities_extra_name_common

[quirrel_bind(module_name="das.daeditor")]
def get_entity_extra_name(eid : EntityId)
  return get_entity_extra_name_common(eid)
