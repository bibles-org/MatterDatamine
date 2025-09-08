require ecs

def disable_jetpack(human_jetpack__eid)
  query(human_jetpack__eid) <| $ [es] (var jetpack__active : bool&)
    jetpack__active = false

[es(REQUIRE=disableUpdate, track=human_jetpack__eid)]
def jetpack_disable_on_disabled_human_es(evt : Event; human_jetpack__eid : EntityId)
  disable_jetpack(human_jetpack__eid)

[es(REQUIRE_NOT=disableUpdate, track=(human_jetpack__eid, human_anim__vehicleSelected, human_use_object__lockJetpackUse))]
def jetpack_disable_es(evt : Event;
                       human_jetpack__eid : EntityId;
                       human_anim__vehicleSelected : EntityId;
                       human_use_object__lockJetpackUse : bool)
  if !!human_anim__vehicleSelected || human_use_object__lockJetpackUse
    disable_jetpack(human_jetpack__eid)
