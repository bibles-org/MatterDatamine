require ecs


[es(tag=sound, on_appear, REQUIRE=droneCamera)]
def get_sound_from_dronen_owner(evt : Event;
                                camera__target : EntityId)
  query(camera__target) <| $[es] (drone__owner : EntityId;
                                  drone_sound__droneOwnerTemplate : string)
    addSubTemplate(drone__owner, drone_sound__droneOwnerTemplate)


[es(tag=sound, on_disappear, REQUIRE=droneCamera)]
def get_sound_from_camera(evt : Event;
                          camera__target : EntityId)
  query(camera__target) <| $[es] (drone__owner : EntityId;
                                  drone_sound__droneOwnerTemplate : string)
    removeSubTemplate(drone__owner, drone_sound__droneOwnerTemplate)