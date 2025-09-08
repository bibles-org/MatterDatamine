require ecs
require ecs.safe
require math
require DagorMath
require math.base
require DagorSystem
require RendInst
require CollRes
require game.events.events_active_matter
require game.es.client.build_mode_preview_common
require game.es.client.build_mode_power_common


[es(track=transform)]
def controller_update_parts(evt : Event;
                            transform aka controller_transform : float3x4;
                            var construction_controller__parts : EidList)
  for part in construction_controller__parts
    query(part) <| $ [es(REQUIRE_NOT=construction_part_hidden)] (construction_part__localTransform : float3x4;
                                                                 var transform aka part_transform : float3x4&)
      part_transform = controller_transform * construction_part__localTransform


[es(on_appear, REQUIRE=construction_part_hidden)]
def construction_part_hidden_appear(evt : Event;
                                    var transform aka part_transform : float3x4)
  part_transform[3].y = -4096.0


[es(on_disappear, REQUIRE=construction_part_hidden)]
def construction_part_hidden_disappear(evt : Event;
                                       construction_part__controller : EntityId;
                                       construction_part__localTransform : float3x4;
                                       var transform aka part_transform : float3x4)
  query(construction_part__controller) <| $ [es] (transform aka controller_transform : float3x4)
    part_transform = controller_transform * construction_part__localTransform


[es(on_appear, on_event=CmdRecreateBuildingParts, on_event=EventLevelLoaded)]
def init_build_controller(evt : Event;
                          eid : EntityId;
                          transform aka controller_transform : float3x4;
                          construction_controller__blueprint : string;
                          var construction_controller__parts : EidList)
  if !empty(construction_controller__parts)
    return
  let blueprintTemplate = getTemplateByName(construction_controller__blueprint)
  if blueprintTemplate == null
    logerr("cannot initialize building contoller: unknown template {construction_controller__blueprint}")
    return
  let parts = get_ecs_array(getTemplateComponent(*blueprintTemplate, "blueprint_base__parts"))
  if parts == null || length(*parts) == 0
    logerr("cannot initialize building contoller: no parts")
    return

  var isActive = false
  find_query() <| $ [es] (base_build_mode__activePreview : EntityId)
    isActive = base_build_mode__activePreview == eid
    return true

  addSubTemplate(eid, "construction_controller_creating_parts") <| $(var init : ComponentsInitializer)
    init |> set("construction_controller_creating_parts__partsToCreateLeft", length(*parts))

  for part in *parts
    let partObject = get_ecs_object(part)
    let partTemplateName = partObject?.template_name ?? ""
    let previewTemplate = isActive ? "+base_build_mode_preview" : ""
    let newPart = createEntity("{partTemplateName}+construction_part{previewTemplate}") <| $(init)
      let localPosition = partObject?.move ?? float3(0.0)
      let localRotation = partObject?.rotate ?? float3(0.0)
      let localScale = partObject?.scale ?? float3(1.0)
      var localTransform = IDENT_TM
      var q : quat
      euler_to_quat(deg_to_rad(localRotation.x), deg_to_rad(localRotation.y), deg_to_rad(localRotation.z), q)
      make_tm(q, localPosition, localTransform)
      localTransform = localTransform * scale_tm(localScale)
      set(init, "construction_part__controller", eid)
      set(init, "construction_part__localTransform", localTransform)
      set(init, "transform", controller_transform * localTransform)
    push(construction_controller__parts, newPart)


[es(on_appear)]
def construction_part_init(evt : Event;
                           eid aka part_eid : EntityId;
                           construction_part__controller : EntityId)
  sendEvent(construction_part__controller, EventConstructionControllerPartCreated(partEid = part_eid))


[es(tag=server)]
def construction_controller_part_created(evt : EventConstructionControllerPartCreated;
                                         eid : EntityId;
                                         var construction_controller_creating_parts__partsToCreateLeft : int&)
  --construction_controller_creating_parts__partsToCreateLeft
  if construction_controller_creating_parts__partsToCreateLeft == 0
    sendEvent(eid, EventConstructionControllerAllPartsCreated())
    removeSubTemplate(eid, "construction_controller_creating_parts")


[es(on_appear, REQUIRE=powered_part)]
def init_powered_building_part(evt : Event;
                               construction_part__controller : EntityId;
                               var powered_part__isPowered : bool&)
  powered_part__isPowered = false
  query(construction_part__controller) <| $ [es(REQUIRE=powered_controller__attachedTo)] ()
    powered_part__isPowered = true


[es(on_disappear)]
def destroy_build_controller(evt : Event;
                             construction_controller__parts : EidList)
  for part in construction_controller__parts
    destroyEntity(part)


[es(on_appear, on_event=EventRendinstsLoaded)]
def calculate_controller_ri_bbox(evt : Event;
                                 construction_part__controller : EntityId;
                                 construction_part__localTransform : float3x4;
                                 ri_extra : RiExtraComponent)
  query(construction_part__controller) <| $ [es] (var construction_controller__bboxMax : float3&;
                                                  var construction_controller__bboxMin : float3&)
    let bbox = construction_part__localTransform * getRIGenBBox(RendInstDesc(ri_extra.handle))
    for i in range(3)
      construction_controller__bboxMax[i] = max(construction_controller__bboxMax[i], bbox.boxMax[i])
      construction_controller__bboxMin[i] = min(construction_controller__bboxMin[i], bbox.boxMin[i])


[es(on_appear, on_event=EventRendinstsLoaded)]
def calculate_controller_collres_bbox(evt : Event;
                                      construction_part__controller : EntityId;
                                      construction_part__localTransform : float3x4;
                                      collres : CollisionResource)

  query(construction_part__controller) <| $ [es] (var construction_controller__bboxMax : float3&;
                                                  var construction_controller__bboxMin : float3&)
    let bbox = construction_part__localTransform * BBox3(collres.vFullBBox)
    for i in range(3)
      construction_controller__bboxMax[i] = max(construction_controller__bboxMax[i], bbox.boxMax[i])
      construction_controller__bboxMin[i] = min(construction_controller__bboxMin[i], bbox.boxMin[i])


[es(track=(transform, construction_controller__bboxMin, construction_controller__bboxMax), on_appear)]
def update_preview_ui_node_position(evt : Event;
                                    transform : float3x4;
                                    construction_controller__bboxMax : float3;
                                    construction_controller__bboxMin : float3;
                                    var ui__node_pos : float3&)
  ui__node_pos = transform[3] + (construction_controller__bboxMax + construction_controller__bboxMin) / 2.0


[es(on_appear, on_event=EventLevelLoaded, REQUIRE=baked_construction_controller)]
def command_center_init_controller(evt : Event; eid : EntityId)
  query() <| $ [es] (var construction_part__controller : EntityId&)
    if construction_part__controller == INVALID_ENTITY_ID
      construction_part__controller = eid


[es(on_appear, on_event=EventLevelLoaded)]
def command_center_init_construction_parts(evt : Event; var construction_part__controller : EntityId&)
  if construction_part__controller == INVALID_ENTITY_ID
    find_query() <| $ [es(REQUIRE=baked_construction_controller)] (eid : EntityId)
      construction_part__controller = eid
      return true
