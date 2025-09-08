require ecs
require AnimV20
require GeomNodeTree
require DagorSystem
require math.base
require game.events.events_game
require game.events.events_active_matter

[es(tag=render, on_appear)]
def gun_flash_fx_init(evt : Event;
                      eid : EntityId;
                      animchar : AnimcharBaseComponent;
                      @shared_comp gun_flash_fx__nodes : StringList;
                      @shared_comp gun_flash_fx__template : StringList;
                      @shared_comp gun_flash_fx__scale : FloatList;
                      var gun_flash_fx__nodeIds : IntList&)
  let numFx = length(gun_flash_fx__nodes)
  gun_flash_fx__nodeIds |> resize(numFx)
  if length(gun_flash_fx__template) != numFx || length(gun_flash_fx__scale) != numFx
    logerr("[{eid}] {getEntityTemplateName(eid)}: gun_flash_fx has wrong number of elements in lists")
  for id, node in gun_flash_fx__nodeIds, gun_flash_fx__nodes
    id = geomtree_findNodeIndex(*animchar.nodeTree, string(node))
    if id < 0
      logerr("[{eid}] {getEntityTemplateName(eid)}: gun_flash_fx node {node} not found")


[es(tag=render, on_appear)]
def gun_flash_fx_multiple_barrels_init(evt : Event;
                                       eid : EntityId;
                                       animchar : AnimcharBaseComponent;
                                       gun__barrelCount : int;
                                       @shared_comp gun_flash_fx__multipleBarrelsNodes : StringList;
                                       @shared_comp gun_flash_fx__multipleBarrelsTemplate : StringList;
                                       @shared_comp gun_flash_fx__multipleBarrelsScale : FloatList;
                                       var gun_flash_fx__multipleBarrelsNodeIds : IntList&)
  let numFx = length(gun_flash_fx__multipleBarrelsNodes)
  gun_flash_fx__multipleBarrelsNodeIds |> resize(numFx)
  if (numFx % gun__barrelCount) != 0 || length(gun_flash_fx__multipleBarrelsTemplate) != numFx || length(gun_flash_fx__multipleBarrelsScale) != numFx
    logerr("[{eid}] {getEntityTemplateName(eid)}: gun_flash_fx_multiple_barrels has wrong number of elements in multipleBarrels lists")
  for id, node in gun_flash_fx__multipleBarrelsNodeIds, gun_flash_fx__multipleBarrelsNodes
    id = geomtree_findNodeIndex(*animchar.nodeTree, string(node))
    if id < 0
      logerr("[{eid}] {getEntityTemplateName(eid)}: gun_flash_fx_multiple_barrels node {node} not found")


def create_flash_fx(eid : EntityId;
                    animchar : AnimcharBaseComponent;
                    animchar__visible : bool = true;
                    @shared_comp gun_flash_fx__template : StringList;
                    @shared_comp gun_flash_fx__scale : FloatList;
                    gun_flash_fx__nodeIds : IntList;
                    gun_flash_fx__offsets : Point3List const? = null)
  for counter, nodeId, fxTemplate, scale in iter_range(gun_flash_fx__nodeIds), gun_flash_fx__nodeIds, gun_flash_fx__template, gun_flash_fx__scale
    if nodeId < 0
      continue
    var tm : float3x4
    geomtree_getNodeWtmScalar(*animchar.nodeTree, nodeId, tm)
    for i in 0..3
      tm[i] *= scale
    if gun_flash_fx__offsets != null
      tm[3] += (*gun_flash_fx__offsets)[counter]
    createEntity(string(fxTemplate)) <| $(var init : ComponentsInitializer)
      init |> set("transform", tm)
      init |> set("gun_fx__ownerEid", eid)
      init |> set("gun_fx__nodeId", nodeId)


[es(tag=render, on_event=(CmdNetShot, EventShot))]
def gun_flash_fx_on_shot(evt : Event;
                         eid : EntityId;
                         animchar : AnimcharBaseComponent;
                         animchar__visible : bool = true;
                         @shared_comp gun_flash_fx__template : StringList;
                         @shared_comp gun_flash_fx__scale : FloatList;
                         gun_flash_fx__nodeIds : IntList;
                         gun_mods__curModInSlots : Object const?)
  if !animchar__visible
    return
  if gun_mods__curModInSlots != null
    let silencerEid = get_Eid((*gun_mods__curModInSlots)["silencer"]) ?? INVALID_ENTITY_ID
    if silencerEid != INVALID_ENTITY_ID
      query(silencerEid) <| $ [es] (@shared_comp gun_flash_fx__nodes : StringList;
                                    @shared_comp gun_flash_fx__template : StringList;
                                    @shared_comp gun_flash_fx__scale : FloatList;
                                    @shared_comp gun_silencer_fx__offsets : Point3List const?)
        using() <| $(var nodeIds : IntList&)
          let numFx = length(gun_flash_fx__nodes)
          nodeIds |> resize(numFx)
          if length(gun_flash_fx__template) != numFx || length(gun_flash_fx__scale) != numFx
            logerr("[{silencerEid}] {getEntityTemplateName(silencerEid)}: gun_silencer_flash_fx has wrong number of elements in lists")
          for id, node in nodeIds, gun_flash_fx__nodes
            id = geomtree_findNodeIndex(*animchar.nodeTree, string(node))
            if id < 0
              logerr("[{silencerEid}] {getEntityTemplateName(silencerEid)}: gun_silencer_flash_fx node {node} for [{eid}] {getEntityTemplateName(eid)} not found")
          create_flash_fx(eid, animchar, animchar__visible,
                          gun_flash_fx__template, gun_flash_fx__scale, nodeIds,
                          gun_silencer_fx__offsets)
      return
  create_flash_fx(eid, animchar, animchar__visible,
                  gun_flash_fx__template, gun_flash_fx__scale, gun_flash_fx__nodeIds)


[es(tag=render, on_event=(CmdNetShot, EventShot))]
def gun_flash_fx_multiple_barrels_on_shot(evt : Event;
                                          eid : EntityId;
                                          animchar : AnimcharBaseComponent;
                                          gun__barrelCount : int;
                                          gun__barrelIndex : int;
                                          animchar__visible : bool = true;
                                          @shared_comp gun_flash_fx__multipleBarrelsTemplate : StringList;
                                          @shared_comp gun_flash_fx__multipleBarrelsScale : FloatList;
                                          gun_flash_fx__multipleBarrelsNodeIds : IntList)
  if !animchar__visible
    return
  let numFxForboltAction = length(gun_flash_fx__multipleBarrelsNodeIds) / gun__barrelCount
  let begin = numFxForboltAction * (gun__barrelIndex - 1)
  let end = begin + numFxForboltAction
  for i in range(begin, end)
    assume nodeId = gun_flash_fx__multipleBarrelsNodeIds[i]
    assume fxTemplate = gun_flash_fx__multipleBarrelsTemplate[i]
    assume scale = gun_flash_fx__multipleBarrelsScale[i]
    if nodeId < 0
      continue
    var tm : float3x4
    geomtree_getNodeWtmScalar(*animchar.nodeTree, nodeId, tm)
    for j in 0..3
      tm[j] *= scale
    createEntity(string(fxTemplate)) <| $(var init : ComponentsInitializer)
      init |> set("transform", tm)
      init |> set("gun_fx__ownerEid", eid)
      init |> set("gun_fx__nodeId", nodeId)


[es(on_appear, tag=render, REQUIRE=effect__name)]
def gun_flash_fx_init_es(evt : Event;
                         var transform : float3x4&;
                         gun_flash_fx__scaleMultiplier : float)
  transform = transform * scale_tm(gun_flash_fx__scaleMultiplier)


[es(tag=render, no_order, REQUIRE=gun_fx__destroyIfGunDoesNotExist)]
def gun_fx_destroy_if_gun_does_not_exist(info : ParallelUpdateFrameDelayed; eid : EntityId; gun_fx__ownerEid : EntityId)
  if !doesEntityExist(gun_fx__ownerEid)
    destroyEntity(eid)
