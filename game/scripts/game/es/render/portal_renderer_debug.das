options no_aot
require ecs
require ecs.common
require math.base
require DagorConsole
require DngCamera
require DagorFiles
require DagorDataBlock
require game.es.camera_common
require PortalRenderer
require game.es.render.portal_renderer_common


[console_cmd(name="portal.create_near_camera")]
def create_portal_near_camera(portal_range : float = 200.0; use_dense_fog : bool = false; fog_start_dist : float = 10.0)
  let cameraTm = get_cam_itm()
  create_portal_at_tm(cameraTm, cameraTm, portal_range, use_dense_fog, fog_start_dist)

[console_cmd(name="portal.create_on_saved_tm")]
def create_portal_on_saved_tm(slot : string; portal_range : float = 200.0; use_dense_fog : bool = false; fog_start_dist : float = 10.0)
  let cameraTm = get_cam_itm()
  var targetTm = cameraTm
  let filename = "cameraPositions.blk"
  using() <| $(var cameraPositions : DataBlock)
    var fileStat : DagorStat
    if df_stat(filename, fileStat) >= 0
      datablock_load(cameraPositions, filename)
      datablock_get_block(cameraPositions, slot) <| $(cameraSlot)
        if datablock_param_exists(cameraSlot, "tm", -1)
          targetTm = datablock_getTm(cameraSlot, "tm", IDENT_TM)
  create_portal_at_tm(cameraTm, targetTm, portal_range, use_dense_fog, fog_start_dist)

[console_cmd(name="portal.update_all_portals")]
def update_all_portals()
  query() <| $ [es] (dynamic_portal__index : int;
                     transform aka source_transform  : float3x4;
                     target_transform  : float3x4;
                     portal_range : float;
                     use_dense_fog : bool;
                     fog_start_dist : float)
    let params = make_portal_params(portal_range, use_dense_fog, fog_start_dist)
    update_portal(dynamic_portal__index, source_transform, target_transform, params)

[console_cmd(name="portal.reset_all_portals")]
def reset_all_portals()
  query() <| $ [es] (var dynamic_portal__index : int&;
                     transform aka source_transform  : float3x4;
                     target_transform  : float3x4;
                     portal_range : float;
                     use_dense_fog : bool;
                     fog_start_dist : float)
    free_portal(dynamic_portal__index)
    dynamic_portal__index = allocate_portal()
    let params = make_portal_params(portal_range, use_dense_fog, fog_start_dist)
    update_portal(dynamic_portal__index, source_transform, target_transform, params)
