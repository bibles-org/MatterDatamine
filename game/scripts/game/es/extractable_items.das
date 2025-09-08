require ecs
require app
require game.events.events
require DagorSystem
require Grid
require game.utils.hero
require inventory
require DagorMath
require CollRes
require DagorRandom
require Dacoll
require DagorMathUtils
require math.base
require math.color
require game.es.inventory_drop_common


[es(tag=gameClient, REQUIRE=hero, before=human_use_action_es, after=hero_human_pre_use_object_es)]
def selecting_extraction_artifact(info : UpdateStageInfoAct;
                                  transform aka human_transform : float3x4;
                                  camera__lookDir : float3;
                                  human_use_object__useMinMaxDist : float2;
                                  var human_use_object__selectedObject : EntityId&)
  let sphere = BSphere3(human_transform[3], human_use_object__useMinMaxDist.x)
  for_each_entity_in_grid(ecs_hash("loot"), sphere, GridEntCheck.POS) <| $(item_eid : EntityId)
    query(item_eid) <| $ [es(REQUIRE=artifact__extractable)] (eid : EntityId;
                                                              transform aka extraction_artifact_transform : float3x4;
                                                              var outline__enabled : bool&)
      let extratingItemPos = extraction_artifact_transform[3]
      let humanPos = human_transform[3]
      outline__enabled = false
      let headOffset = float3(0., 1.5, 0.)
      let humanHeadPos = humanPos + headOffset
      let dir = normalize(extratingItemPos - humanHeadPos)
      let minIntersectionDor = 0.85f
      if dot(camera__lookDir, dir) >= minIntersectionDor
        human_use_object__selectedObject = eid
        outline__enabled = true


def create_and_drop_new_item(transform : float3x4;
                             collres : CollisionResource;
                             item_template : string;
                             item__count : int;
                             gen_item_radius = 0.4;
                             gen_item_spot_rise = 1.0)
  let box = collres.vFullBBox
  let boxCenter = (box.bmax + box.bmin) * 0.5f
  let boxCenterScalar = float3(boxCenter.x, boxCenter.y, boxCenter.z)
  let startPos = transform * boxCenterScalar

  var to = float3()
  var right = float3(-transform[0].x, 0.f, -transform[0].z)
  if length(right) == 0.f
    right = float3(0.f, 0.f, -1.f)
  right = normalize(right)
  let pivot = gfrnd() * TWOPI
  sincos(pivot - floor(pivot * 2.f / PI) * (PI / 2.f) + PI / 4.f, to.z, to.x)
  to = quat_get_forward(dir_to_quat(right) * dir_to_quat(to))

  var from = startPos + to
  var norm : float3
  var genItemSpotRise = gen_item_spot_rise
  traceray_normalized(from, float3(0.f, 1.f, 0.f), genItemSpotRise, norm)
  from.y += genItemSpotRise
  var dirToFrom = from - startPos
  var dirToFromLen = length(dirToFrom)
  var predictCollisionLen = gen_item_radius
  dirToFrom *= safeinv(dirToFromLen)
  let hasCollision = traceray_normalized(startPos, dirToFrom, dirToFromLen, norm)
  var predictNorm = norm
  if hasCollision || traceray_normalized(from, to, predictCollisionLen, predictNorm)
    if !hasCollision
      norm = predictNorm
    let wallOffset = 0.01f
    from = startPos + dirToFrom * dirToFromLen + norm * wallOffset
    var offset = norm * gen_item_radius
    offset.y = 0.f
    var offsetLen = length(offset)
    if !is_equal_float(offsetLen, 0.f)
      offset *= safeinv(offsetLen)
      traceray_normalized(from, offset, offsetLen, norm)
      from += offset * offsetLen

  var itemDropTm = transform
  itemDropTm[3] = from

  drop_item_on_ground(itemDropTm)
  createEntity("{item_template}+item_in_world") <| $(var init : ComponentsInitializer)
    init |> set("transform", itemDropTm)
    init |> set("item__count", item__count)


[es(tag=server, no_order)]
def update_extraction_progress(info : UpdateStageInfoAct;
                               eid : EntityId;
                               artifact__extractionTime : float;
                               artifact__extractionTimeAt : float;
                               transform : float3x4;
                               collres : CollisionResource;
                               artifact__attractPointEid : EntityId;
                               artifact__reloadTime : float;
                               artifact__extractionPrize : string;
                               artifact__extractionPrizeLimits : int2;
                               artifact__extractionPrizeCoinCount : int2;
                               var artifact__isReloading : bool&;
                               var artifact__reloadAt : float&;
                               var artifact__isExtracting : bool&)
  artifact__isReloading = false
  if artifact__reloadAt > info.curTime
    artifact__isReloading = true
  elif artifact__isExtracting
    let extractionProgress = clamp((info.curTime - artifact__extractionTimeAt + artifact__extractionTime) / artifact__extractionTime, 0., 1.f)
    query(artifact__attractPointEid) <| $ [es] (var attract_point__magnitude : float&;
                                                attract_point__magnitudeLimits : float2)
      attract_point__magnitude = cvt(extractionProgress, 0., 1., attract_point__magnitudeLimits.x, attract_point__magnitudeLimits.y)
    if artifact__extractionTimeAt < info.curTime
      destroyEntity(artifact__attractPointEid)
      artifact__isExtracting = false
      artifact__reloadAt = info.curTime + artifact__reloadTime
      let value = rnd_int(artifact__extractionPrizeLimits.x, artifact__extractionPrizeLimits.y)
      for _ in range(value)
        let count = rnd_int(artifact__extractionPrizeCoinCount.x, artifact__extractionPrizeCoinCount.y)
        create_and_drop_new_item(transform, collres, artifact__extractionPrize, count)
      destroyEntity(eid)


[es(tag=gameClient, no_order)]
def update_scale_extractable_item(info : UpdateStageInfoAct;
                                  artifact__extractionTime : float;
                                  artifact__scalesLimits : float2;
                                  artifact__isExtracting : bool;
                                  var artifact__curScale : float&;
                                  var transform : float3x4&)
  if artifact__isExtracting
    let sinusoida = sin(info.curTime + PI / 3.) * info.dt * 0.4f
    let scalingSpeed = (artifact__scalesLimits.y - artifact__scalesLimits.x) / artifact__extractionTime
    artifact__curScale = max(move_to_scalar(artifact__curScale, artifact__scalesLimits.y, info.dt, abs(scalingSpeed)) + sinusoida, min(artifact__scalesLimits.y, artifact__scalesLimits.x))
  var tm = scale_tm(artifact__curScale)
  tm[3] = transform[3]
  transform = tm


[es(tag=gameClient, no_order, REQUIRE=artifact__extractable)]
def extractable_color(info : UpdateStageInfoAct;
                      artifact__isExtracting : bool;
                      artifact__scalesLimits : float2;
                      artifact__curScale : float;
                      var light__max_radius : float&;
                      var light__color : E3DCOLOR&)
  if artifact__isExtracting
    light__max_radius = 10f
    let progress = cvt(artifact__curScale, artifact__scalesLimits.x, artifact__scalesLimits.y, 0., 1.)
    light__color = lerp_color(E3DCOLOR(0xFFEBC20F), E3DCOLOR(0xFFEB0E19), progress)


[es(tag=server, REQUIRE_NOT=itemExtracting)]
def start_extraction(evt : CmdUse;
                     eid : EntityId;
                     transform : float3x4;
                     artifact__subTemplateInWorking : string;
                     artifact__attractPointTemplateName : string;
                     artifact__extractionTime : float;
                     artifact__isReloading : bool;
                     var artifact__attractPointEid : EntityId&;
                     var artifact__extractionTimeAt : float&;
                     var artifact__isExtracting : bool&)
  if !artifact__isExtracting && !artifact__isReloading
    artifact__extractionTimeAt = get_sync_time() + artifact__extractionTime
    artifact__isExtracting = true
    artifact__attractPointEid = createEntity(artifact__attractPointTemplateName) <| $(init)
      set(init, "transform", transform)
      set(init, "game_effect__timeToDestroy", artifact__extractionTime)
      set(init, "attract_point__ownerEid", eid)
    addSubTemplate(eid, artifact__subTemplateInWorking)


[es(tag=gameClient, on_appear, REQUIRE=artifact__extractable)]
def init_extractable_item(evt : Event;
                          artifact__offset : float3;
                          var transform : float3x4&;
                          var artifact__moveTo : float3&)
  transform[3].y += artifact__offset.y / 2.f
  artifact__moveTo = transform[3] + artifact__offset
  var standTm = transform
  drop_item_on_ground(standTm)
  createEntity("artifact_stand") <| $(init)
    init |> set("transform", standTm)


[es(tag=gameClient, no_order, REQUIRE=artifact__extractable)]
def extractable_item_phys(info : UpdateStageInfoAct;
                          var transform : float3x4&;
                          var artifact__moveTo : float3&)
  let sinusoid = sin(info.curTime) * info.dt * 0.5f
  artifact__moveTo.y += sinusoid
  transform[3] = lerp(transform[3], artifact__moveTo, float3(info.dt))
