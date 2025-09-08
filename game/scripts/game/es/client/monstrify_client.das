require ecs
require DngNet
require game.es.client.postfx_fade_common


[es(tag=gameClient, on_appear, REQUIRE=player_controlled_monster)]
def monstrify_trap_fade_out(evt : Event;
                            possessedByPlr : EntityId)
  let fadeOutTime = 1.5

  if has_network()
    query(possessedByPlr) <| $ [es] (is_local : bool)
      if is_local
        postfx_fadeout(fadeOutTime, int(ecs_hash("monstrify_trap")))
  else
    postfx_fadeout(fadeOutTime, int(ecs_hash("monstrify_trap")))


[es(tag=gameClient, on_appear, REQUIRE=watchedByPlr)]
def disable_traps_fx_if_they_cant_be_used(evt : Event;
                                          trigger_trap_activator__mask : uint)
  query() <| $[es(REQUIRE=optimised_effect_source__template)] (eid aka trap_eid : EntityId;
                                                               trigger_trap__mask : uint;
                                                               var anomaly_trap__triggerFx : das_string&;
                                                               var trap_trigger_sound__path : das_string&)
    if (trigger_trap__mask & trigger_trap_activator__mask) == 0u
      addSubTemplate(trap_eid, "disable_optimised_visual_effect")
      anomaly_trap__triggerFx := ""
      trap_trigger_sound__path := ""