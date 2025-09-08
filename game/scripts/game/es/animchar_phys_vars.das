require ecs
require math.base
require PhysVars
require DagorSystem
require DagorMath
require DngNet


[es(on_appear)]
def animchar_walk_dir_init(evt : Event;
                           animchar_phys_var__walkDir : string;
                           var animchar_phys_var__walkDirId : int&;
                           var phys_vars : PhysVars)
  animchar_phys_var__walkDirId = phys_vars |> registerVar(animchar_phys_var__walkDir, 0.0)


def calc_walk_dir_angle(prev_pos : float3;
                        current_pos : float3;
                        look_dir : float3)
  let moveDirDelta = current_pos.xz - prev_pos.xz
  let moveDirLenSq = length_sq(moveDirDelta)
  if moveDirLenSq < square(0.001)
    return 0.0
  let moveDirLen = sqrt(moveDirLenSq)
  let moveDir = moveDirDelta / moveDirLen

  let lookDir = normalize(look_dir.xz)
  let dot = dot(moveDir, lookDir)
  let det = moveDir.x * lookDir.y - moveDir.y * lookDir.x
  var angle = -atan2(det, dot)
  if angle > PI
    angle -= PI
  elif angle < -PI
    angle += PI

  return rad_to_deg(angle)


[es(after=navmesh_rotate_offline_anim, REQUIRE_NOT=(loc_snapshots__snapshotData, animchar__actOnDemand, deadEntity, animchar__lockAnimStateChange))]
def animchar_walk_dir_update_offline(evt : UpdateStageInfoAct;
                                     animchar__updatable : bool;
                                     animchar_phys_var__walkDirId : int;
                                     navmesh_phys__prevPos : float3;
                                     navmesh_phys__currentPos : float3;
                                     navmesh_phys__currentLookDir : float3;
                                     var phys_vars : PhysVars)
  if !animchar__updatable
    return

  let angle = calc_walk_dir_angle(navmesh_phys__prevPos,
                                  navmesh_phys__currentPos,
                                  navmesh_phys__currentLookDir)
  phys_vars |> setVar(animchar_phys_var__walkDirId, angle)


[es(after=update_navmesh_phys, REQUIRE_NOT=(animchar__actOnDemand, deadEntity))]
def animchar_walk_dir_update(evt : UpdateStageInfoAct;
                             animchar__updatable : bool;
                             animchar_phys_var__walkDirId : int;
                             loc_snapshots__snapshotData : LocSnapshotsList;
                             var phys_vars : PhysVars)
  if !animchar__updatable
    return

  let n = length(loc_snapshots__snapshotData)
  if n >= 2
    let begin = loc_snapshots__snapshotData[0].pos
    let end = loc_snapshots__snapshotData[n - 1].pos
    let rot = loc_snapshots__snapshotData[n - 1].quat

    let angle = calc_walk_dir_angle(begin,
                                    end,
                                    rot |> quat_get_forward())
    phys_vars |> setVar(animchar_phys_var__walkDirId, angle)