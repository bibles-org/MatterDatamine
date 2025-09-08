require ecs
require game.events.events_game
require game.es.game_effect_macro

[es]
def locked_person_view_set_es(evt : GameEffectStateChanged; eid : EntityId; locked_view__lockPersonView : int)
  if has(evt.attachedTo, "hero")
    let excludeEid = eid
    let isActive = evt.activated || ecs::find_query() <| $ [es(REQUIRE=locked_view__lockPersonView)] (eid, game_effect__attachedTo : EntityId)
      return eid != excludeEid && game_effect__attachedTo == evt.attachedTo
    ecs::query(evt.attachedTo) <| $ [es] (var human__lockPersonView : int&)
      human__lockPersonView = isActive ? locked_view__lockPersonView : 0

[es_game_effect(bool_flag=human__lockZoom, tag=locked_view__lockZoom)]
def locked_aim_zoom_es() { pass; }
