require ecs

[es(on_disappear, tag=server, REQUIRE=animchar)]
def cleanup_attaches_on_destroy_es_server(evt : Event; eid : EntityId)
  let parentEid = eid
  ecs::query() <| $ [es(REQUIRE=slot_attach__destroyWithParent)] (eid, slot_attach__attachedTo : EntityId)
    if slot_attach__attachedTo == parentEid
      destroyEntity(eid)

[es(on_disappear, tag=netClient, REQUIRE=animchar)]
def cleanup_attaches_on_destroy_es_client(evt : Event; eid : EntityId) // when attach created on client side
  let parentEid = eid
  ecs::query() <| $ [es(REQUIRE=slot_attach__clientDestroyWithParent)] (eid, slot_attach__attachedTo : EntityId)
    if slot_attach__attachedTo == parentEid
      destroyEntity(eid)
