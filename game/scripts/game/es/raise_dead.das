require ecs
require app
require DngNet
require game.events.events_active_matter


[es(tag=server, on_appear, REQUIRE_NOT=deadEntity)]
def init_atomizing_appear_effect_server(evt : Event; var atomizing_appear_anim__enabledBehTreeAt : float&)
  atomizing_appear_anim__enabledBehTreeAt += get_sync_time()


[es(tag=server, no_order, REQUIRE_NOT=deadEntity)]
def atomizing_appear_effect_server(info : ParallelUpdateFrameDelayed;
                                   eid : EntityId;
                                   atomizing_appear_anim__template : string;
                                   atomizing_appear_anim__enabledBehTreeAt : float;
                                   var game_effect__attachedTo : EntityId&;
                                   var beh_tree__enabled : bool&)
  if info.curTime >= atomizing_appear_anim__enabledBehTreeAt
    game_effect__attachedTo = INVALID_ENTITY_ID
    beh_tree__enabled = true
    remote_remove_sub_template(eid, atomizing_appear_anim__template)
