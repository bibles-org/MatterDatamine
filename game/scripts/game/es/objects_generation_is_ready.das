require ecs
require game.events.events


[es(tag=server, on_appear, REQUIRE=objectsGenerationIsDone)]
def destroy_objects_generation_is_done(evt : Event; eid : EntityId)
  destroyEntity(eid)