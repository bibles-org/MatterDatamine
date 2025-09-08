require ecs
require game.utils.hero
require game.es.render.lut_switcher_common
require game.events.events_game
require game.es.game_effect_macro
require DagorSystem


def enable_color_grading_effect(watchedEid : EntityId)
  ecs::find_query() <| $ [es] (game_effect__attachedTo : EntityId; game_effect__colorGrading : Object)
    if game_effect__attachedTo == watchedEid
      ecs::query() <| $ [es] (var color_grading_items : ecs::Array)
        add_grading(ecs_hash("game_effect"), color_grading_items, game_effect__colorGrading)
      return true
    return false


def disable_color_grading_effect()
  ecs::query() <| $ [es] (var color_grading_items : ecs::Array)
    remove_grading(ecs_hash("game_effect"), color_grading_items)


[es_game_effect(bool_flag=human_effect__colorGrading, tag=game_effect__colorGrading)]
def color_grading_es() { pass; }


[es(on_appear, REQUIRE=watchedByPlr)]
def color_grading_watched_by_plr_appear(evt : Event;
                                        eid : EntityId;
                                        var human_effect__colorGrading : bool&)
  find_query() <| $ [es(REQUIRE=game_effect__colorGrading)] (game_effect__attachedTo : EntityId)
    if game_effect__attachedTo == eid
      human_effect__colorGrading = true
      return true
    return false


[es(tag=render, track=human_effect__colorGrading, REQUIRE=watchedByPlr)]
def color_grading_effect_track_es(evt : Event; eid : EntityId; human_effect__colorGrading : bool)
  if human_effect__colorGrading
    enable_color_grading_effect(eid)
  else
    disable_color_grading_effect()


[es(tag=render, on_appear, REQUIRE=watchedByPlr)]
def color_grading_effect_enable_es(evt : Event; eid : EntityId; human_effect__colorGrading : bool)
  if human_effect__colorGrading
    enable_color_grading_effect(eid)


[es(tag=render, on_event=EventComponentsDisappear, on_event=EventEntityDestroyed, REQUIRE=watchedByPlr)]
def color_grading_effect_disable_es(evt : Event; human_effect__colorGrading : bool)
  if human_effect__colorGrading
    disable_color_grading_effect()


[es(tag=render, track=game_effect__colorGrading, on_appear)]
def color_grading_effect_track_is_changed(evt : Event;
                                          game_effect__attachedTo : EntityId;
                                          game_effect__colorGrading : Object)
  query(game_effect__attachedTo) <| $ [es(REQUIRE=watchedByPlr)] ()
    ecs::query() <| $ [es] (var color_grading_items : ecs::Array)
      update_grading(ecs_hash("game_effect"), color_grading_items, game_effect__colorGrading)