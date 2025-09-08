require ecs
require app
require game.events.events_active_matter
require active_matter.game.utils.poly_area
require net
require game.es.action_common
require game.utils.sound_utils
require game.es.riextra_common
require level
require pathfinder
require RendInst
require RiDestr
require DagorSystem
require HumanPhys
require DngHuman
require danetlibs.pathfinder.main.pathfinder_common


def find_cuttable_fence_jl(fence_pos : float3; radius_sq : float) : dtPolyRef
  var res = INVALID_POLY_REF
  iterate_over_polys_recursively(fence_pos, 5, float3(0.5, 1.0, 0.5)) <| $(thisPoly : dtPolyRef)
    var polyFlags = uint16(0)
    var area = uint8(0)
    get_poly_area(thisPoly, area)
    get_poly_flags(thisPoly, polyFlags)
    if int(polyFlags) == 0 && area == uint8(int(PolyFlag.POLYFLAG_OBSTACLE))
      var triangle : NavMeshTriangle
      get_triangle_by_poly(thisPoly, triangle)
      if distance_sq((triangle.p0.xz + triangle.p1.xz) * 0.5, fence_pos.xz) < radius_sq
        res = thisPoly
        return true
    return false
  return res


[es(tag=server, REQUIRE=cuttable_fence_cut_action)]
def cuttable_fence_cut_action(evt : CmdExecInteractionAction;
                              interactable_invoice__hero : EntityId;
                              interactable_invoice__parentInteractableEid : EntityId)
  query(interactable_invoice__hero) <| $ [es] (human_weap__currentGunSlot : int)
    let isMelee = (human_weap__currentGunSlot == int(HUWeaponSlots.EWS_MELEE))
    if !isMelee
      return
    query(interactable_invoice__parentInteractableEid) <| $ [es] (ri_preload__name : string;
                                                                  transform : float3x4;
                                                                  cuttable_fence__isValid : bool;
                                                                  cuttable_fence__soundPathCutted : string;
                                                                  cuttable_fence__enableJLinksRadiusSq : float = 0.25;
                                                                  var use_object__enabled : bool&)
      if !cuttable_fence__isValid
        return
      broadcast_net_sound(interactable_invoice__parentInteractableEid, cuttable_fence__soundPathCutted, transform[3])
      send_net_event(
        interactable_invoice__parentInteractableEid,
          CmdReplaceRiExtraRes(
            riExtra := ri_preload__name,
            destroyPrevRi = true,
            addPrevRiToRestorables = true,
            createPrevRiDestr = false))

      use_object__enabled = false
      let polyRef = find_cuttable_fence_jl(transform[3], cuttable_fence__enableJLinksRadiusSq)
      if polyRef != INVALID_POLY_REF
        set_poly_flags(polyRef, uint16(int(PolyFlag.POLYFLAG_JUMP))) //is able to pass
        set_poly_area(polyRef, uint8(int(AMPolyArea.POLYAREA_JUMP))) //is trying to pass
      else
        logerr("Failed to enable jumplinks for cuttable fence {transform[3].x}, {transform[3].y}, {transform[3].z}")



[es(tag=server, on_appear, on_event=EventLevelLoaded, REQUIRE=cuttableFence)]
def cuttable_fence_validate(evt : Event;
                            transform : float3x4;
                            cuttable_fence__enableJLinksRadiusSq : float = 0.25;
                            var cuttable_fence__isValid : bool&)
  if !is_level_loaded()
    return

  let polyRef = find_cuttable_fence_jl(transform[3], cuttable_fence__enableJLinksRadiusSq)
  if polyRef == INVALID_POLY_REF
    cuttable_fence__isValid = false
