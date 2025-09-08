require ecs
require DngNet
require ecs.safe
require game.events.events_active_matter
require DagorSystem
require DagorRandom
require game.events.events_game
require game.events.inventory_events
require game.es.ecs_common


def process_update_ribbons_color(ribbonColors : int2;
                                 ribbonInvalidColor : float4;
                                 ribbonColorsList : Point4List;
                                 actor_eid : EntityId;
                                 watchedByPlr : EntityId const?;
                                 var shader_color__colors : Point4List)
  if length(shader_color__colors) != 2
    logerr("[RIBBONS] Hero <{actor_eid}> <{getEntityTemplateName(actor_eid)}> have shader_color__colors with size <{length(shader_color__colors)}>, expected 2.")
    return
  shader_color__colors[0] = ribbonColors.x < 0 ? ribbonInvalidColor : ribbonColorsList[ribbonColors.x]
  shader_color__colors[1] = ribbonColors.y < 0 ? ribbonInvalidColor : ribbonColorsList[ribbonColors.y]
  if watchedByPlr != null
    broadcastEvent(EventLocalPlayerRibbonsChanged())


def set_invalid_color(var shader_color__colors : Point4List)
  find_query() <| $ [es] (ribbonInvalidColor : float4)
    shader_color__colors[0] = ribbonInvalidColor
    shader_color__colors[1] = ribbonInvalidColor
    return true


def process_set_ribbons_color(actor_eid : EntityId;
                              var shader_color__colors : Point4List)
  find_query() <| $ [es] (ribbonInvalidColor : float4;
                          ribbonColorsList : Point4List)
    query(actor_eid) <| $ [es] (possessedByPlr : EntityId;
                                watchedByPlr : EntityId const?)
      query(possessedByPlr) <| $ [es] (player_ribbons__curColors : int2)
        process_update_ribbons_color(player_ribbons__curColors, ribbonInvalidColor, ribbonColorsList, actor_eid, watchedByPlr, shader_color__colors)
      if possessedByPlr == INVALID_ENTITY_ID
        process_update_ribbons_color(int2(-1, -1), ribbonInvalidColor, ribbonColorsList, actor_eid, watchedByPlr, shader_color__colors)
    return true


def randomize_ribbon_colors(seed : uint)
  var result = int2(-1)
  find_query() <| $ [es] (ribbonColorsList : Point4List)
    let colorCount = length(ribbonColorsList)
    var s = int(seed)
    if colorCount > 0
      result = int2(_rnd_int(s, 0, colorCount - 1), _rnd_int(s, 0, colorCount - 1))
    return true
  return result


def update_actor_ribbons(actor_eid : EntityId)
  find_query() <| $ [es] (ribbonInvalidColor : float4; ribbonColorsList : Point4List)
    query(actor_eid) <| $ [es] (eid : EntityId;
                                possessedByPlr : EntityId;
                                watchedByPlr : EntityId const?;
                                attachable_suit_controller__attachedAnimcharEids : Object const?;
                                human_equipment__slots : Object const?;
                                var shader_color__colors aka hero_shader_color__colors : Point4List?)
      query(possessedByPlr) <| $ [es] (player_ribbons__curColors : int2)
        if attachable_suit_controller__attachedAnimcharEids != null
          for item in *attachable_suit_controller__attachedAnimcharEids
            let animcharEid = get_Eid(item.value) ?? INVALID_ENTITY_ID
            query(animcharEid) <| $ [es] (var shader_color__colors aka item_shader_color__colors : Point4List&)
              process_update_ribbons_color(player_ribbons__curColors, ribbonInvalidColor, ribbonColorsList, eid, watchedByPlr, item_shader_color__colors)
        if human_equipment__slots != null
          let helmetEid = (*human_equipment__slots)["helmet"] ?? INVALID_ENTITY_ID
          query(helmetEid) <| $ [es] (var shader_color__colors aka helmet_shader_color__colors : Point4List&)
            process_update_ribbons_color(player_ribbons__curColors, ribbonInvalidColor, ribbonColorsList, eid, watchedByPlr, helmet_shader_color__colors)
        if hero_shader_color__colors != null
          process_update_ribbons_color(player_ribbons__curColors, ribbonInvalidColor, ribbonColorsList, eid, watchedByPlr, *hero_shader_color__colors)
    return true


[es(tag=gameClient, REQUIRE=human, on_appear)]
def set_ribbons_color_default(evt : Event;
                              eid aka actor_eid : EntityId;
                              var shader_color__colors aka hero_shader_color__colors : Point4List)
  process_set_ribbons_color(actor_eid, hero_shader_color__colors)


[es(tag=gameClient,
  on_appear,
  track=(attachable_suit_controller__attachedAnimcharEids,
         possessedByPlr,
         human_equipment__slots),
  REQUIRE=(attachable_suit_controller__attachedAnimcharEids,
           possessedByPlr,
           human_equipment__slots))]
def possessed_by_plr_set_ribbons_color(evt : Event;
                                       eid aka actor_eid : EntityId)
  update_actor_ribbons(actor_eid)


[es(tag=gameClient, REQUIRE=suit_militant_attachable_animchar, on_appear, track=slot_attach__attachedTo)]
def attachable_suit_set_ribbons_color(evt : Event;
                                      slot_attach__attachedTo : EntityId;
                                      var shader_color__colors aka suit_shader_color__colors : Point4List&)
  process_set_ribbons_color(slot_attach__attachedTo, suit_shader_color__colors)


[es(tag=gameClient, on_appear, REQUIRE=possessedByPlr)]
def soldier_with_ribbons_update_equipment_on_appear(evt : Event; eid aka actor_eid : EntityId)
  query() <| $ [es] (slot_attach__attachedTo : EntityId; var shader_color__colors : Point4List)
    if slot_attach__attachedTo == actor_eid
      process_set_ribbons_color(actor_eid, shader_color__colors)


[es(tag=gameClient, REQUIRE=attachable_backpack_animchar, on_appear, track=slot_attach__attachedTo)]
def attachable_backpack_set_ribbons_color(evt : Event;
                                          slot_attach__attachedTo : EntityId;
                                          var shader_color__colors aka backpack_shader_color__colors : Point4List&)
  process_set_ribbons_color(slot_attach__attachedTo, backpack_shader_color__colors)


[es(tag=gameClient, REQUIRE=attachable_helmet_animchar, on_appear, track=slot_attach__attachedTo)]
def attachable_helmet_set_ribbons_color(evt : Event;
                                        slot_attach__attachedTo : EntityId;
                                        var shader_color__colors aka helmet_shader_color__colors : Point4List&)
  process_set_ribbons_color(slot_attach__attachedTo, helmet_shader_color__colors)


[es(tag=gameClient, REQUIRE=attachable_backpack_animchar)]
def attachable_backpack_set_ribbons_color_on_drop(evt : EventOnDropItem;
                                                  var shader_color__colors aka backpack_shader_color__colors : Point4List&)
  set_invalid_color(backpack_shader_color__colors)


[es(tag=gameClient, REQUIRE=attachable_helmet_animchar)]
def attachable_helmet_set_ribbons_color_on_drop(evt : EventOnDropItem;
                                                var shader_color__colors aka helmet_shader_color__colors : Point4List&)
  set_invalid_color(helmet_shader_color__colors)


[es(tag=gameClient, on_appear, track=player_ribbons__curColors, REQUIRE=player_ribbons__curColors)]
def update_ribbons_color(evt : Event;
                         possessed : EntityId)
  update_actor_ribbons(possessed)


[es(tag=server, on_appear)]
def player_randomize_ribbon_colors(evt : Event;
                                   team : int;
                                   player_ribbons__rndColors : bool;
                                   var player_ribbons__curColors : int2&)
  let isRibbonColorsHasDefaultValue = (player_ribbons__curColors == int2(-1))
  if player_ribbons__rndColors && isRibbonColorsHasDefaultValue
    player_ribbons__curColors = randomize_ribbon_colors(uint(team) + uint(get_session_id()))
