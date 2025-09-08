require ecs
require game.utils.hero
require danetlibs.renderer.includes.render_events


[es(tag=render)]
def unexpected_altitude_change_for_flying_hero_es(var evt : QueryUnexpectedAltitudeChange&)
  if evt.enabled
    return
  let heroEid = get_controlled_hero()
  var spectatingTarget : ecs::EntityId
  ecs::find_query() <| $ [es] (eid : ecs::EntityId;
                               watchedByPlr : ecs::EntityId)
    if watchedByPlr == heroEid
      spectatingTarget = eid
      return true
    return false

  for eid in fixed_array(heroEid, spectatingTarget)
    query(eid) <| $ [es] (monster_flight_mode__enabled : bool)
      if (monster_flight_mode__enabled)
        evt.enabled = true
    if evt.enabled
      return


