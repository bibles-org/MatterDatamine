require ecs
require math
require AnimV20
require GeomNodeTree
require danetlibs.renderer.includes.render_events
require danetlibs.collimator_moa.render.sighting_distance_common


[es(tag=render, after=(animchar_before_render_es))]
def collimator_moa_update_current_sighting_distance_offset(info : UpdateStageInfoBeforeRender;
                                                           collimator_moa_render__gun_mod_eid : EntityId)
  if !collimator_moa_render__gun_mod_eid
    return

  query(collimator_moa_render__gun_mod_eid) <| $ [es] (
                                                       slot_attach__attachedTo : EntityId;
                                                       gunmod__camNode : string;
                                                       animchar aka collimator_animchar : AnimcharBaseComponent;
                                                       gunmod__sightingDistance : float;
                                                       gunmod__lensNode : string;
                                                       gunmod__collimator_moa_parallax_plane_dist : float;
                                                       var gunmod__collimator_moa_reticle_offset_y : float&
                                                       )
    gunmod__collimator_moa_reticle_offset_y = 0.0f

    if gunmod__sightingDistance <= 0.0f
      return

    if !slot_attach__attachedTo
      return

    let lensNodeIdx = geomtree_findNodeIndex(*collimator_animchar.nodeTree, gunmod__lensNode)
    if lensNodeIdx < 0
      return

    var moaLensWtm : float3x4
    geomtree_getNodeWtmScalar(*collimator_animchar.nodeTree, lensNodeIdx, moaLensWtm)

    let collimatorCameraNodeId = geomtree_findNodeIndex(*collimator_animchar.nodeTree, gunmod__camNode)
    if collimatorCameraNodeId < 0
      return

    query(slot_attach__attachedTo) <| $[es] (
                                             gun__shootNodeName : string;
                                             animchar aka gun_animchar : AnimcharBaseComponent
                                             )
      let gunShootNodeIdx = geomtree_findNodeIndex(*gun_animchar.nodeTree, gun__shootNodeName)
      if gunShootNodeIdx < 0
        return

      let collimatorCameraNodeWpos = geomtree_getNodeWpos(*collimator_animchar.nodeTree, collimatorCameraNodeId)
      let gunShootWpos = geomtree_getNodeWpos(*gun_animchar.nodeTree, gunShootNodeIdx)

      gunmod__collimator_moa_reticle_offset_y = calc_collimator_moa_reticle_sighting_offset(moaLensWtm, collimatorCameraNodeWpos,
        gunShootWpos, gunmod__collimator_moa_parallax_plane_dist, gunmod__sightingDistance)
