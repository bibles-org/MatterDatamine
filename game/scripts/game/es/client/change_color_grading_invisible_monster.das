require ecs
require game.es.render.lut_switcher_common


[es(tag=render, on_disappear, REQUIRE=monster_invisibility_affect_out)]
def monster_color_grading_effect_disappring(evt : Event;
                                            game_effect__attachedTo aka disappering_effect_game_effect__attachedTo : EntityId)
  query() <| $ [es(REQUIRE=invisible_monster_effect)] (game_effect__colorGrading : Object;
                                                       game_effect__attachedTo aka monster_game_effect__attachedTo : EntityId)
    if disappering_effect_game_effect__attachedTo == monster_game_effect__attachedTo
      query(monster_game_effect__attachedTo) <| $[es(REQUIRE=watchedByPlr)] ()
        query() <| $ [es] (var color_grading_items : Array)
          update_grading(ecs_hash("game_effect"), color_grading_items, game_effect__colorGrading)