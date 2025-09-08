require ecs
require game.events.events_active_matter


[es(tag=gameClient, REQUIRE=watchedByPlr)]
def watched_by_plr_camera_magnification_blink_effect(evt : EventOnPlayerDash;
                                                     eid : EntityId;
                                                     camera_magnification_blink_effect_controller__effectTemplate : string)
  createEntity(camera_magnification_blink_effect_controller__effectTemplate) <| $(var init : ComponentsInitializer)
    init |> set("game_effect__attachedTo", eid)