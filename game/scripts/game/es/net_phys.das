require ecs
require app
require net
require DagorSystem
require game.events.events_active_matter

[es(before=send_transform_snapshots_es, after=(after_net_phys_sync, human_phys_es))]
def update_net_phys_scale(act : ParallelUpdateFrameDelayed;
                          scaled_net_phys__scale : float;
                          var transform : float3x4&)
  if scaled_net_phys__scale != 1.0
    transform[0] = normalize(transform[0]) * scaled_net_phys__scale
    transform[1] = normalize(transform[1]) * scaled_net_phys__scale
    transform[2] = normalize(transform[2]) * scaled_net_phys__scale