require ecs
require Grid
require math.base
require DagorMath
require game.events.events_active_matter


[es(no_order)]
def toggle_deformation_bbox(update : ParallelUpdateFrameDelayed;
                            transform aka enabler_transform : float3x4;
                            deformation_bbox_enabler__addDistance : float;
                            deformation_bbox_enabler__removeDistance : float;
                            deformation_bbox_enabler__checkPeriod : float;
                            var deformation_bbox_enabler__checkAt : float&)
  if update.curTime < deformation_bbox_enabler__checkAt
    return

  deformation_bbox_enabler__checkAt = update.curTime + deformation_bbox_enabler__checkPeriod

  let removeDistanceSq = square(deformation_bbox_enabler__removeDistance)

  // Disable bboxes of entities that are too far
  query() <| $ [es(REQUIRE=(deform_bbox__bmin, deform_bbox__bmax))] (eid aka receiver_eid : EntityId;
                                                                     transform aka receiver_transform : float3x4;
                                                                     deformation_bbox_receiver__bboxSubTemplateName : string;
                                                                     deformation_bbox_receiver__enabled : bool = true;
                                                                     var deformation_bbox_receiver__bboxEnabled : bool&)
    if !deformation_bbox_receiver__bboxEnabled || !deformation_bbox_receiver__enabled
      return
    let distanceSq = distance_sq(enabler_transform[3], receiver_transform[3])
    if distanceSq > removeDistanceSq
      removeSubTemplate(receiver_eid, deformation_bbox_receiver__bboxSubTemplateName)
      deformation_bbox_receiver__bboxEnabled = false

  // Enable bboxes of entities that are close enough
  assume searchRadius = deformation_bbox_enabler__addDistance
  let enableQuery = $ <| (receiver_eid : EntityId)
    query(receiver_eid) <| $ [es] (deformation_bbox_receiver__bboxSubTemplateName : string;
                                   deformation_bbox_receiver__enabled : bool = true;
                                   var deformation_bbox_receiver__bboxEnabled : bool&)
      if deformation_bbox_receiver__bboxEnabled || !deformation_bbox_receiver__enabled
        return
      addSubTemplate(receiver_eid, deformation_bbox_receiver__bboxSubTemplateName)
      deformation_bbox_receiver__bboxEnabled = true
  for_each_entity_in_grid(fixed_array(ecs_hash("humans"), ecs_hash("interactable")), BSphere3(enabler_transform[3], searchRadius), GridEntCheck.BOUNDING, enableQuery)
  for_each_entity_in_grid(ecs_hash("loot"), BSphere3(enabler_transform[3], searchRadius * 0.5), GridEntCheck.BOUNDING, enableQuery)

[es(on_disappear, REQUIRE=deformation_bbox_enabler__addDistance)]
def disable_deformation_bbox(evt : Event)
  query() <| $ [es] (eid : EntityId;
                     deformation_bbox_receiver__bboxSubTemplateName : string;
                     var deformation_bbox_receiver__bboxEnabled : bool&)
    if !deformation_bbox_receiver__bboxEnabled
      return

    removeSubTemplate(eid, deformation_bbox_receiver__bboxSubTemplateName)
    deformation_bbox_receiver__bboxEnabled = false


[es(on_appear, REQUIRE=deadEntity)]
def deformation_bbox_receiver_on_death(evt : Event;
                                       eid : EntityId;
                                       deformation_bbox_receiver__disableOnDeath : bool;
                                       deformation_bbox_receiver__bboxSubTemplateName : string;
                                       var deformation_bbox_receiver__bboxEnabled : bool&;
                                       var deformation_bbox_receiver__enabled : bool&)
  if deformation_bbox_receiver__disableOnDeath
    if deformation_bbox_receiver__bboxEnabled
      removeSubTemplate(eid, deformation_bbox_receiver__bboxSubTemplateName)
      deformation_bbox_receiver__bboxEnabled = false

    deformation_bbox_receiver__enabled = false