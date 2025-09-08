module system_common shared
require ecs
require DagorSystem


def is_index_frame(idx : int;
                   frames_range : int)
  let frameIdx = int(get_dagor_frame_no()) % frames_range
  return idx == frameIdx


def is_entity_frame(eid : EntityId;
                    frames_range : int)
  let idx = int(uint(eid)) % frames_range
  return is_index_frame(idx, frames_range)


def get_30_fps_dt()
  return 0.0333333


def min_30_fps_dt(dt : float)
  return min(dt, get_30_fps_dt())