require ecs
require soundHash
require soundEvent
require sound_utils.modules.sound_player_common
require game.events.events
require game.events.events_game
require game.events.events_active_matter
require game.es.dynamic_zone_mode_common
require player


[es(tag=sound, track=dynamic_zone_controller__state)]
def dynamic_zone_controller_play_sound_by_state(evt : Event;
                                                dynamic_zone_controller__state : int)
  if dynamic_zone_controller__state == int(DynamicZoneControllerState.ZONE_SHRINKING)
    query() <| $ [es(REQUIRE=hero, REQUIRE_NOT=deadEntity)] (possessedByPlr : EntityId)
      sendEvent(possessedByPlr, CmdStartAssistantSpeak(scriptName = "zone_start_move_message", skipBeepSound = true))


[es(tag=sound, REQUIRE=dynamic_zone_controller)]
def dynamic_zone_controller_play_sound_on_final_extraction_appear(evt : EventFinalExtractionAppear)
  query() <| $ [es(REQUIRE=hero, REQUIRE_NOT=deadEntity)] (possessedByPlr : EntityId)
    sendEvent(possessedByPlr, CmdStartAssistantSpeak(scriptName = "portal_appear_message", skipBeepSound = true))
