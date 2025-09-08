require ecs
require app


[es(on_appear)]
def create_entity_on_appear_with_delay_init(evt : Event;
                                            create_entity_on_appear_with_delay__delay : float;
                                            var create_entity_on_appear_with_delay__createAt : float&)
  create_entity_on_appear_with_delay__createAt = get_sync_time() + create_entity_on_appear_with_delay__delay


[es(no_order)]
def create_entity_on_appear_with_delay(update : UpdateStageInfoAct;
                                       eid : EntityId;
                                       create_entity_on_appear_with_delay__createAt : float;
                                       create_entity_on_appear_with_delay__template : string;
                                       transform : float3x4 const?)
  if get_sync_time() < create_entity_on_appear_with_delay__createAt
    return

  createEntity(create_entity_on_appear_with_delay__template) <| $(init)
    if transform != null
      set(init, "transform", *transform)
  destroyEntity(eid)


[es(on_disappear)]
def create_entity_on_disappear_with_delay(evt : Event;
                                          create_entity_on_disappear_with_delay__delay : float;
                                          create_entity_on_disappear_with_delay__template : string;
                                          transform : float3x4 const?)
  createEntity("create_entity_on_appear_with_delay+destroy_self_after_delayed_creation") <| $(init)
    set(init, "create_entity_on_appear_with_delay__delay", create_entity_on_disappear_with_delay__delay)
    set(init, "create_entity_on_appear_with_delay__template", create_entity_on_disappear_with_delay__template)
    if transform != null
      set(init, "transform", *transform)
