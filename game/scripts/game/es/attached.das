require ecs
require game.events.events_active_matter


[es(no_order)]
def attached_pos_update(act : ParallelUpdateFrameDelayed;
                        attached__entity : EntityId;
                        attached__localPos : float3;
                        var transform aka attached_transform : float3x4)
  query(attached__entity) <| $ [es] (transform aka parent_transform : float3x4)
    attached_transform[3] = parent_transform[3] + attached__localPos

