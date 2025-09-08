require ecs
require AnimV20
require game.es.slot_attach_common
require danetlibs.renderer.includes.render_events
require game.events.events_active_matter


[es(tag=gameClient, after=skeleton_attach_es,
    REQUIRE_NOT=sleeping_animchar_update_toggle,
    REQUIRE=(slot_attach, slot_attach__toSkeletonAttach), parallel_for=16)]
def slot_attach_to_skeleton_attach_update_es(info : ParallelUpdateFrameDelayed;
                                             eid : EntityId;
                                             slot_attach__slotId : int;
                                             slot_attach__attachedTo : EntityId;
                                             var animchar : AnimcharBaseComponent;
                                             disableUpdate : Tag const?;
                                             var animchar_node_wtm : AnimcharNodesMat44?;
                                             var animchar_render__root_pos : vec4f?;
                                             animchar__visible : bool = true;
                                             slot_attach__calcAnim : bool = true;
                                             force_animchar_act : bool = false)
  slot_attach_init_tms_impl(info.dt, eid, slot_attach__slotId, slot_attach__attachedTo, animchar, disableUpdate,
                            animchar_node_wtm, animchar_render__root_pos, animchar__visible, slot_attach__calcAnim, false /*force_update*/, force_animchar_act)
