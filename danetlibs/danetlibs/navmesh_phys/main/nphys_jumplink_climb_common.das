module nphys_jumplink_climb_common shared
require ecs
require danetlibs.navmesh_phys.main.nphys_events
require DngNet


def should_climb(path_corridor__overJumpLink : bool;
                 path_corridor__jumpLinkStart, path_corridor__jumpLinkEnd : float3;
                 navmesh_phys__climbMinHeight : float)
  return (path_corridor__overJumpLink
          && path_corridor__jumpLinkEnd.y - path_corridor__jumpLinkStart.y >= navmesh_phys__climbMinHeight)


def send_path_corridor_jump_link_start_end_changed_event(eid : EntityId;
                                                         path_corridor__jumpLinkStart : float3;
                                                         path_corridor__jumpLinkEnd : float3)
  send_net_event(eid, PathCorridorJumpLinkStartEndChanged(start = path_corridor__jumpLinkStart,
                                                          end = path_corridor__jumpLinkEnd))