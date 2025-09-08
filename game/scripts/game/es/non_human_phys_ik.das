require ecs
require PhysMat
require AnimV20
require game.events.events_active_matter


[es(tag=gameClient, on_appear)]
def init_conditional_ik_var_id(evt : Event;
                               non_human_phys_ik__varName : string;
                               var non_human_phys_ik__varId : int&;
                               var animchar : AnimcharBaseComponent&)
  non_human_phys_ik__varId = *animchar.animGraph |> anim_graph_getParamId(non_human_phys_ik__varName, int(PT_ScalarParam))

  let walkRayMatId = get_material_id("walkRay")
  animchar |> animchar_setTraceContext(int64((walkRayMatId << 1) | 1)) // Enable LegsIK


[es(tag=gameClient, no_order)]
def toggle_ik_around_origin(act : ParallelUpdateFrameDelayed;
                            transform aka o_transform : float3x4;
                            non_human_phys_ik_origin__radiusSq : float;
                            non_human_phys_ik_origin__interval : float;
                            var non_human_phys_ik_origin__updateAt : float&)
  if act.curTime > non_human_phys_ik_origin__updateAt
    non_human_phys_ik_origin__updateAt = act.curTime + non_human_phys_ik_origin__interval
    query() <| $ [es(REQUIRE_NOT=nphys__disabled)] (non_human_phys_ik__varId : int;
                                                    transform aka t_transform : float3x4;
                                                    var animchar : AnimcharBaseComponent&)
      if non_human_phys_ik__varId >= 0
        let val = distance_sq(o_transform[3], t_transform[3]) > non_human_phys_ik_origin__radiusSq ? .0 : 1.0
        *animchar.animState |> anim_state_holder_setParam(non_human_phys_ik__varId, val)