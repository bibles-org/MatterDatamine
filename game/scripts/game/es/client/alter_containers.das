require ecs
require ecs.safe
require math.base
require game.events.events_active_matter


def update_suit_in_flask(alter_tube_place__number : int;
                         player_profile__alterIds : StringList;
                         var alter_tube_place__alterEid : EntityId&;
                         player_profile__allItems : Array;
                         alter_tube_place__alterTemplate : string;
                         transform : float3x4;
                         alter_tube_place__alterOffset : float3;
                         var alter_tube_place__decoratorEids : EidList&;
                         alter_tube_place__decorators : Array)
  if alter_tube_place__number >= length(player_profile__alterIds)
    if alter_tube_place__alterEid != INVALID_ENTITY_ID
      destroyEntity(alter_tube_place__alterEid)
      alter_tube_place__alterEid = INVALID_ENTITY_ID
  else
    for item in player_profile__allItems
      let itemObj = item as Object
      if (itemObj?.itemId ?? "0") == player_profile__alterIds[alter_tube_place__number]
        let templateName = itemObj?.templateName ?? ""
        if !empty(templateName)
          let templ = getTemplateByName(templateName)
          let animcharName = getTemplateComponent(*templ, "animchar__res") ?? ""
          var isSameAnimchar = false
          query(alter_tube_place__alterEid) <| $ [es] (animchar__res : string)
            isSameAnimchar = animchar__res == animcharName
          if !isSameAnimchar && !empty(animcharName)
            if alter_tube_place__alterEid != INVALID_ENTITY_ID
              destroyEntity(alter_tube_place__alterEid)
            alter_tube_place__alterEid = createEntity(alter_tube_place__alterTemplate) <| $(var init)
              init |> set("animchar__res", animcharName)
              var tm = transform
              tm[3] += alter_tube_place__alterOffset
              init |> set("transform", tm)
        break
  if alter_tube_place__alterEid == INVALID_ENTITY_ID && !empty(alter_tube_place__decoratorEids)
    for decoratorEid in alter_tube_place__decoratorEids
      destroyEntity(decoratorEid)
    alter_tube_place__decoratorEids |> clear()
  elif alter_tube_place__alterEid != INVALID_ENTITY_ID && empty(alter_tube_place__decoratorEids)
    for decorator in alter_tube_place__decorators
      let decoratorName = (decorator as Object)?.name ?? ""
      if empty(decoratorName)
        continue
      let decoratorEid = createEntity(decoratorName) <| $(var init)
        init |> set("transform", transform * ((decorator as Object)?.tm ?? IDENT_TM))
      alter_tube_place__decoratorEids |> push(decoratorEid)


[es(tag=gameClient, track=player_profile__alterIdsChanged)]
def update_alters_bodies(evt : Event;
                         player_profile__alterIds : StringList;
                         player_profile__allItems : Array;
                         var player_profile__alterIdsChanged : bool&)
  if !player_profile__alterIdsChanged
    return
  player_profile__alterIdsChanged = false
  query() <| $ [es] (alter_tube_place__alterTemplate : string;
                     alter_tube_place__number : int;
                     alter_tube_place__alterOffset : float3;
                     transform : float3x4;
                     alter_tube_place__decorators : Array;
                     var alter_tube_place__decoratorEids : EidList;
                     var alter_tube_place__alterEid : EntityId&)
    update_suit_in_flask(alter_tube_place__number,
                         player_profile__alterIds,
                         alter_tube_place__alterEid,
                         player_profile__allItems,
                         alter_tube_place__alterTemplate,
                         transform,
                         alter_tube_place__alterOffset,
                         alter_tube_place__decoratorEids,
                         alter_tube_place__decorators)


[es(tag=gameClient, on_appear)]
def create_alters_bodies(evt : Event;
                         alter_tube_place__alterTemplate : string;
                         alter_tube_place__number : int;
                         alter_tube_place__alterOffset : float3;
                         transform : float3x4;
                         alter_tube_place__decorators : Array;
                         var alter_tube_place__decoratorEids : EidList;
                         var alter_tube_place__alterEid : EntityId&)
  query() <| $ [es] (player_profile__alterIds : StringList;
                     player_profile__allItems : Array)
    update_suit_in_flask(alter_tube_place__number,
                         player_profile__alterIds,
                         alter_tube_place__alterEid,
                         player_profile__allItems,
                         alter_tube_place__alterTemplate,
                         transform,
                         alter_tube_place__alterOffset,
                         alter_tube_place__decoratorEids,
                         alter_tube_place__decorators)


[es]
def set_alter_tube_light(evt : EventAlterHighlight)
  find_query() <| $ [es] (alter_tube__key : string; var light__brightness : float&)
    if evt.alterTubeKey != alter_tube__key
      return false

    light__brightness = evt.highlightIntence

    return true


[es]
def set_alter_tube_effects(evt : EventActivateShowroom)
  query() <| $ [es(REQUIRE=selected_tube_distortion)] (eid : EntityId; var transform : float3x4&)
    transform[0] *= -1.0
    eid |> removeSubTemplate("selected_tube_distortion")
  query() <| $ [es] (eid : EntityId; alter_tube__key : string; var transform : float3x4&)
    if evt.showroomKey == alter_tube__key
      eid |> addSubTemplate("selected_tube_distortion")
      transform[0] *= -1.0


[es]
def remove_alter_tube_effects(evt : EventCloseShowroom)
  let isEditorActive = find_query() <| $ [es] (editor_active_marker__isActive : bool)
    return editor_active_marker__isActive
  if isEditorActive
    return
  query() <| $ [es(REQUIRE=selected_tube_distortion)] (eid : EntityId; var transform : float3x4&)
    transform[0] *= -1.0
    eid |> removeSubTemplate("selected_tube_distortion")
