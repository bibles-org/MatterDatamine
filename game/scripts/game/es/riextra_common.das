module riextra_common shared
require ecs
require ecs.safe
require level
require RendInst
require DagorSystem
require DngDm


def ensure_riextra_res_idx(riextra_name : string)
  var resIndex = get_rigen_extra_res_idx(riextra_name)
  if resIndex < 0
    if !is_level_loaded()
      logerr("rendinst_addRIGenExtraResIdx({riextra_name}): It's forbidden to add custom ri until the level is fully loaded - high risk of static ri type ids and handles net desync!")
    resIndex = rendinst_addRIGenExtraResIdx(riextra_name)
    if resIndex < 0
      logerr("Failed to add evt.riExtra=<{riextra_name}>({resIndex})!")
    else
      rendinst_addRiGenExtraDebris(uint(resIndex), 0)
  return resIndex


def preload_riextra_res_lod(riextra_name : string;
                            lod : uint = 0u)
  let resIdx = ensure_riextra_res_idx(riextra_name)
  if resIdx >= 0
    rendinst_updateRiExtraReqLod(uint(resIdx), lod)


def normalize_rendinst_rotation_angle(angle : float)
  var newAngle = angle
  while newAngle > 180.0
    newAngle -= 360.0
  while newAngle < -180.0
    newAngle += 360.0
  return newAngle


def riex_should_damage(eid : EntityId; team : int; riex_handle : riex_handle_t)
  let heid = find_ri_extra_eid(riex_handle)
  return should_shell_damage(heid, eid, team)


def riex_set_offender(riex_handle : riex_handle_t; offenderEid : EntityId)
  let riexEid = find_ri_extra_eid(riex_handle)
  var riOffender = getRW_Eid(riexEid, "riOffender")
  if riOffender != null
    *riOffender = offenderEid