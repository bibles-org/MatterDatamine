require ecs
require AnimV20


[es(tag=render, on_appear)]
def common_magazine_anim_init(evt : Event;
                              var animchar : AnimcharBaseComponent;
                              var magazine_anim__curNumAmmoParamId : int&)
  magazine_anim__curNumAmmoParamId = *animchar.animGraph |> anim_graph_getParamId("cur_num_ammo", int(PT_ScalarParam))


[es(tag=render, REQUIRE_NOT=slot_attach, track=item__currentBoxedItemCount, on_appear, after=common_magazine_anim_init)]
def hide_magzine_ammo(evt : Event;
                      item__currentBoxedItemCount : int;
                      magazine_anim__curNumAmmoParamId : int;
                      var animchar : AnimcharBaseComponent&;
                      var animchar_node_wtm : AnimcharNodesMat44&;
                      var animchar_render__root_pos : vec4f&)
  *animchar.animState |> anim_state_holder_setParam(magazine_anim__curNumAmmoParamId, float(item__currentBoxedItemCount))
  animchar |> animchar_act(0.f, true)
  animchar |> animchar_copy_nodes(animchar_node_wtm, animchar_render__root_pos)


[es(tag=render, REQUIRE=gun__magazineReload, track=gun__ammo)]
def hide_attached_magzine_ammo(evt : Event;
                               gun__ammo : int;
                               gun_mods__curModInSlots : Object)
  let magazineEid = get_Eid(gun_mods__curModInSlots["magazine"]) ?? INVALID_ENTITY_ID
  query(magazineEid) <| $ [es(REQUIRE=slot_attach)] (magazine_anim__curNumAmmoParamId : int;
                                                     var animchar : AnimcharBaseComponent&)
    *animchar.animState |> anim_state_holder_setParam(magazine_anim__curNumAmmoParamId,  float(max(gun__ammo - 1, 0)))
