require ecs
require active_matter.game.es.jetpack_common


[es(tag=server, track=jetpack__isInAir)]
def on_jetpack_is_in_air_changed(evt : Event;
                                 eid, item__containerOwnerEid : EntityId;
                                 jetpack__isInAir, jetpack__withdrawOnLanding : bool)
  if jetpack__withdrawOnLanding && !jetpack__isInAir
    withdraw_jetpack(eid, item__containerOwnerEid)
    print("jetpack: jetpack {eid} withdrawed from {item__containerOwnerEid} after landing due to jetpack__withdrawOnLanding=true")


[es(tag=server, track=human_jetpack__flightMode)]
def on_jetpack_flightmode_changed(evt : Event; human_jetpack__flightMode : bool; human_jetpack__eid : EntityId)
  if human_jetpack__flightMode
    query(human_jetpack__eid) <| $ [es] (var jetpack__flightsLeft : int&; var jetpack__withdrawOnLanding : bool&)
      jetpack__flightsLeft--
      jetpack__withdrawOnLanding = jetpack__flightsLeft <= 0
