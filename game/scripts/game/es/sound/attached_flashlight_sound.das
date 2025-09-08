require ecs
require soundEvent


[es(tag=sound, track=attached_flashlight__isOn)]
def attached_flashlight_sound(evt : Event;
                              attached_flashlight__isOn : bool;
                              attached_flashlight__actorEid : EntityId;
                              attached_flashlight_sound__onPath : string;
                              attached_flashlight_sound__offPath : string)

  query(attached_flashlight__actorEid) <| $ [es(REQUIRE=watchedByPlr)] (transform : float3x4)
    oneshot(attached_flashlight__isOn ? attached_flashlight_sound__onPath : attached_flashlight_sound__offPath, transform[3])

