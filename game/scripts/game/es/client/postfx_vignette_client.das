require ecs
require app
require math.color
require game.events.events
require game.es.client.postfx_fade_common
require game.es.system_common
require game.es.ecs_common
require game.events.events_active_matter
require player
require DagorMath
require DagorSystem



def is_actor_postfx_vignette_affected(actor_eid : EntityId)
  var result = false
  query(actor_eid) <| $ [es] (watchedByPlr : EntityId const?;
                              createdByPlr : EntityId const?)
    result = (watchedByPlr != null)
    if !result && createdByPlr != null
      result = (*createdByPlr == get_local_player_eid())

  return result


def set_vignette_factor(factor : float)
  find_query() <| $ [es] (var postfx_vignette_controller__vignetteFactor : float&)
    postfx_vignette_controller__vignetteFactor = factor
    return true


[es(tag=gameClient, on_appear)]
def postfx_vignette_affect_appear(evt : Event;
                                  postfx_vignette_affect__factor : float;
                                  game_effect__attachedTo : EntityId)
  if is_actor_postfx_vignette_affected(game_effect__attachedTo)
    set_vignette_factor(postfx_vignette_affect__factor)


[es(tag=gameClient, on_disappear, REQUIRE=postfx_vignette_affect__factor)]
def postfx_vignette_affect_disappear(evt : Event;
                                     game_effect__attachedTo : EntityId)
  if is_actor_postfx_vignette_affected(game_effect__attachedTo)
    set_vignette_factor(0.0)


[es(tag=gameClient, on_appear, REQUIRE=watchedByPlr)]
def actor_appear_update_postfx_vignette_affect(evt : Event;
                                               eid : EntityId)
  if is_actor_postfx_vignette_affected(eid)
    find_query() <| $ [es] (game_effect__attachedTo : EntityId;
                            postfx_vignette_affect__factor : float)
      if game_effect__attachedTo == eid
        set_vignette_factor(postfx_vignette_affect__factor)
        return true

      return false
