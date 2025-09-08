require ecs
require AnimV20
require DagorMath
require GeomNodeTree


[es(tag=render, on_appear)]
def cockpit_camera_init(evt : Event; animchar : AnimcharBaseComponent; human_cam__camNodeName : string; var human_cam__camNodeId : int&)
  human_cam__camNodeId = geomtree_findNodeIndex(*animchar.nodeTree, human_cam__camNodeName)


[es(tag=render, after=camera_set_sync, before=before_camera_sync, REQUIRE=watchedByPlr)]
def human_fpv_cam_pos(info : UpdateStageInfoAct;
                      animchar : AnimcharBaseComponent;
                      human_cam__camNodeId : int;
                      var camera__look_at : DPoint3&)
  if human_cam__camNodeId < 0
    return
  let wposRel = geomtree_getNodeWposRel(*animchar.nodeTree, human_cam__camNodeId)
  let wofs = geomtree_getWtmOfs(*animchar.nodeTree)
  camera__look_at = DPoint3(wposRel) + DPoint3(wofs)
