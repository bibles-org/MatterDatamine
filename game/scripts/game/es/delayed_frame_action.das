require ecs
require DagorSystem
require game.events.events_active_matter


[es(no_order)]
def process_delayed_frame_action(upd : ParallelUpdateFrameDelayed;
                                 eid : EntityId;
                                 action_on_delayed_frame__frame : int;
                                 action_on_delayed_frame__recipient : EntityId)
  if int(get_dagor_frame_no()) >= action_on_delayed_frame__frame
    sendEventImmediate(action_on_delayed_frame__recipient, EventDelayedFrameAction())
    destroyEntity(eid)
