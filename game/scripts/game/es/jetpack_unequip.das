require ecs

[es(on_appear, REQUIRE_NOT=slot_attach__attachedTo)]
def jetpack_unequip_es(evt : Event; var jetpack__active : bool&)
  jetpack__active = false
