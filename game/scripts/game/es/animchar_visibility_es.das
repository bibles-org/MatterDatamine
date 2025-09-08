require ecs
require app
require game.es.game_effect_macro
require net


// One and only place that defines final visibility of a human.
def calc_human_visibility(isInVehicleHidden : bool; human__visible : bool)
  return !isInVehicleHidden && human__visible

// One and only place that defines final visibility of an attachable item (such as a gun, hat, grenade, etc.)
def calc_attachable_visibility(slot_attach__attachedTo : ecs::EntityId;
                               slot_attach__visible : bool;
                               slot_attach__ignoreParentVisibility : bool = false)
  // Attachable is visible if it's human inventory visible or it's a weapon that's visible (i.e. not holstered)
  var res = slot_attach__visible

  if !slot_attach__ignoreParentVisibility
    ecs::query(slot_attach__attachedTo) <| $ [es] (isInVehicleHidden : bool; human__visible : bool)
      // If it's attached to a human and human is invisible, then the item is also invisible.
      res &&= calc_human_visibility(isInVehicleHidden, human__visible)

    ecs::query(slot_attach__attachedTo) <| $ [es] (slot_attach__attachedTo aka parent_slot_attach__attachedTo : ecs::EntityId = INVALID_ENTITY_ID;
                                                   slot_attach__visible aka parent_slot_attach__visible : bool;
                                                   slot_attach__ignoreParentVisibility aka parent_slot_attach__ignoreParentVisibility : bool = false)

      let tmpRes = calc_attachable_visibility(
        parent_slot_attach__attachedTo,
        parent_slot_attach__visible,
        parent_slot_attach__ignoreParentVisibility)
      // If it's attached to a weapon, then it's a weapon mod.
      res = tmpRes

  return res

// Recursively update visibilities of all attached stuff.
def update_attached_visibility(parentEid : ecs::EntityId)
  ecs::query() <| $ [es] (eid : ecs::EntityId; slot_attach__attachedTo : ecs::EntityId; var animchar_render__enabled : bool&;
                          slot_attach__visible : bool;
                          slot_attach__ignoreParentVisibility : bool = false)
    if slot_attach__attachedTo == parentEid
      animchar_render__enabled = calc_attachable_visibility(
        slot_attach__attachedTo,
        slot_attach__visible,
        slot_attach__ignoreParentVisibility)

      if parentEid != eid
        update_attached_visibility(eid)

[es(track=(isInVehicleHidden, human__visible, human__selfVisible), on_appear)]
def animchar_human_visibility_es(evt : Event; eid : ecs::EntityId; isInVehicleHidden : bool; human__visible : bool;
                                 human__selfVisible = true; var animchar_render__enabled : bool&)
  animchar_render__enabled = human__selfVisible && calc_human_visibility(isInVehicleHidden, human__visible)

  update_attached_visibility(eid)
  ecs::query() <| $ [es] (skeleton_attach__attachedTo : ecs::EntityId; var animchar_render__enabled : bool&;
                          slot_attach__visible : bool)
    if skeleton_attach__attachedTo == eid
      animchar_render__enabled = calc_human_visibility(isInVehicleHidden, human__visible) && slot_attach__visible

[es(on_appear, on_disappear, track=slot_attach__visible, track=slot_attach__attachedTo)]
def animchar_attachable_visibility_es(evt : Event; eid : ecs::EntityId; slot_attach__attachedTo : ecs::EntityId;
                                      var animchar_render__enabled : bool&; slot_attach__visible : bool = true;
                                      slot_attach__ignoreParentVisibility : bool = false)
  animchar_render__enabled = calc_attachable_visibility(
    slot_attach__attachedTo,
    slot_attach__visible,
    slot_attach__ignoreParentVisibility)

  update_attached_visibility(eid)

[es(track=slot_attach__ignoreParentVisibility)]
def animchar_attachable_visibility_track_ignore_parent_visibility(evt : Event; eid : ecs::EntityId; slot_attach__attachedTo : ecs::EntityId;
                                                                  var animchar_render__enabled : bool&; slot_attach__visible : bool;
                                                                  slot_attach__ignoreParentVisibility : bool)
  animchar_render__enabled = calc_attachable_visibility(
    slot_attach__attachedTo,
    slot_attach__visible,
    slot_attach__ignoreParentVisibility)

  update_attached_visibility(eid)


[es(on_appear, track=skeleton_attach__attachedTo, track=slot_attach__visible)]
def animchar_skeleton_visibility_es(evt : Event; skeleton_attach__attachedTo : ecs::EntityId;
                                    var animchar_render__enabled : bool&; slot_attach__visible : bool)
  ecs::query(skeleton_attach__attachedTo) <| $ [es] (isInVehicleHidden : bool; human__visible : bool)
    animchar_render__enabled = calc_human_visibility(isInVehicleHidden, human__visible) && slot_attach__visible


[es(on_appear)]
def hide_animchar_attaches_game_effect_on_appear(evt : Event;
                                                 game_effect__attachedTo : EntityId;
                                                 var game_effect__hiddenAnimcharAttaches : EidList)
  query() <| $ [es] (eid aka attach_eid : EntityId;
                     slot_attach__attachedTo : EntityId;
                     slot_attach__visible : bool = true;
                     var animchar_render__enabled : bool&)
    if slot_attach__attachedTo != game_effect__attachedTo
      return
    if !slot_attach__visible
      return
    animchar_render__enabled = false
    push(game_effect__hiddenAnimcharAttaches, attach_eid)


[es(on_disappear)]
def hide_animchar_attaches_game_effect_on_disappear(evt : Event;
                                                    game_effect__hiddenAnimcharAttaches : EidList)
  for eid in game_effect__hiddenAnimcharAttaches
    query(eid) <| $ [es] (var animchar_render__enabled : bool&)
      animchar_render__enabled = true


[es_game_effect(bool_flag=animchar__actWhenInvisible, tag=game_effect__animcharActWhenInvisble)]
def set_animchar_act_when_invisible_es() { pass; }


[es(on_appear, REQUIRE=item__invisible)]
def hide_animchar(evt : Event;
                  eid : EntityId;
                  var animchar_render__enabled : bool&;
                  var slot_attach__visible : bool?)
  animchar_render__enabled = false
  if slot_attach__visible != null
    *slot_attach__visible = false
  update_attached_visibility(eid)


[es(on_disappear, REQUIRE=item__invisible)]
def unhide_animchar(evt : Event;
                    eid : EntityId;
                    var animchar_render__enabled : bool&;
                    var slot_attach__visible : bool?)
  animchar_render__enabled = true
  if slot_attach__visible != null
    *slot_attach__visible = true
  update_attached_visibility(eid)


[es(tag=server, on_appear)]
def slot_attach_show_after_appear_init(evt : Event;
                                       slot_attach_show_after_appear__time : float;
                                       var slot_attach__visible : bool&;
                                       var slot_attach_show_after_appear__showAt : float&)
  slot_attach__visible = false
  slot_attach_show_after_appear__showAt = get_sync_time() + slot_attach_show_after_appear__time


[es(tag=server, no_order)]
def slot_attach_show_after_appear_update(act : UpdateStageInfoAct;
                                         eid : EntityId;
                                         slot_attach_show_after_appear__showAt : float;
                                         var slot_attach__visible : bool&)
  if act.curTime >= slot_attach_show_after_appear__showAt
    removeSubTemplate(eid, "slot_attach_show_after_appear")
    slot_attach__visible = true