require ecs


[es(tag=server, on_disappear, REQUIRE=human_weap__gunEids)]
def human_weap_destroy(evt : Event; eid aka hero_eid : EntityId)
  query() <| $ [es] (eid aka gun_eid, gun__owner : EntityId)
    if gun__owner == hero_eid
      query(gun_eid) <| $ [es] (var gun_mods__curModInSlots : Object&)
        for gunMod in gun_mods__curModInSlots
          let gunModEid = get_Eid(gunMod.value) ?? INVALID_ENTITY_ID
          destroyEntity(gunModEid)
      destroyEntity(gun_eid)
