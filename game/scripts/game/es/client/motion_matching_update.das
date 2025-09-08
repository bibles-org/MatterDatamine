require ecs
require danetlibs.renderer.includes.pufd_events
require danetlibs.motion_matching.es.mm_events

[es(tag=render, before=before_net_phys_sync)]
def motion_matching_start_search_job(info : ParallelUpdateFrameDelayed)
  broadcastEventImmediate(MotionMatchingStartSearchJob(dt = info.dt))
