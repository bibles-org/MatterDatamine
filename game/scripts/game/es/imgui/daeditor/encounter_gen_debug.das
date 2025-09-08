options no_aot
require ecs
require DagorRandom
require pathfinder
require math
require math.base
require math.random
require strings
require active_matter.game.es.encounter_gen_common
require game.events.events_active_matter
require DagorConsole
require DagorEditor
require DagorDataBlock
require EcsUtils
require danetlibs.imgui_daeditor.daEditor.daEditor_common
require game.es.level_common
require debug.logerr_once

[console_cmd(name="am.generate_encounters")]
def console_generate_encounters()
  query() <| $ [es(REQUIRE_NOT=manualEncounterGen)] (eid : EntityId; var encounter_gen__pos : Point3List; var encounter_gen__norm : Point3List?)
    clear(encounter_gen__pos)
    if encounter_gen__norm != null
      clear(*encounter_gen__norm)
    console_print("generating encounters for: {getEntityTemplateName(eid)}")
    addSubTemplate(eid, "active_encounter_gen")

def generate_encounter_spawn_pos(eid : EntityId; pos_list : array<float3>; min_distance_sq : float; total_to_generate : int;
                                 var iteration : int&; var result_list : Point3List; validate_pos : block<(pos : float3) : bool>)
  if length(pos_list) == 0
    logerr_once("Position list is empty for {eid}<{getEntityTemplateName(eid)}>")
    return

  set_rnd_seed(total_to_generate)
  var iterationPerFrame = 100
  while iterationPerFrame-- > 0
    iteration++
    let firstIdx = grnd() % length(pos_list)
    let secondIdx = grnd() % length(pos_list)
    if length_sq(pos_list[firstIdx] - pos_list[secondIdx]) < min_distance_sq
      continue

    var spawnPos : float3
    if !get_random_point_on_path(pos_list[firstIdx], pos_list[secondIdx], spawnPos)
      continue

    if !invoke(validate_pos, spawnPos)
      continue

    push(result_list, spawnPos)
    if length(result_list) >= total_to_generate
      removeSubTemplate(eid, "active_encounter_gen")
      addSubTemplate(eid, "finished_encounter_gen")
      return
    if iteration % 500 == 499
      console_print("{eid}<{getEntityTemplateName(eid)}>: progress {length(result_list)} / {total_to_generate}")

[es(no_order, REQUIRE=activeEncounterGen)]
def encounter_gen_pregenerate(info : UpdateStageInfoAct; eid : EntityId;
                              encounter_gen__numToPregenerate : int;
                              encounter_gen__minPoiDistance : float;
                              var encounter_gen__iterations : int&;
                              var encounter_gen__pos : Point3List)
  var posList : array<float3>
  // query objectives and use their pos to spawn on
  query() <| $ [es(REQUIRE=pointOfInterest)] (transform : float3x4)
    push(posList, transform[3])
  generate_encounter_spawn_pos(eid,
                                posList,
                                square(encounter_gen__minPoiDistance),
                                encounter_gen__numToPregenerate,
                                encounter_gen__iterations,
                                encounter_gen__pos) <| $ [unused_argument(_)] (_ : float3)
    return true


[es(no_order, REQUIRE=activeEncounterGen)]
def indoor_encounter_gen_pregenerate(info : UpdateStageInfoAct; eid : EntityId;
                                     indoor_encounter_gen__numToPregenerate : int;
                                     encounter_gen__minPoiDistance : float;
                                     var encounter_gen__iterations : int&;
                                     var encounter_gen__pos : Point3List)
  var posList : array<float3>
  // query objectives and use their pos to spawn on
  query() <| $ [es(REQUIRE=indoorPointOfInterest)] (transform : float3x4)
    push(posList, transform[3])
  generate_encounter_spawn_pos(eid,
                                posList,
                                square(encounter_gen__minPoiDistance),
                                indoor_encounter_gen__numToPregenerate,
                                encounter_gen__iterations,
                                encounter_gen__pos) <| $(pos : float3)
    return is_pos_indoor(pos)


[es(no_order, REQUIRE=activeEncounterGen)]
def grazing_encounter_gen_pregenerate(info : UpdateStageInfoAct; eid : EntityId; transform : float3x4;
                                      grazing_encounter_gen__numToPregenerate : int;
                                      encounter_gen__minPoiDistance : float;
                                      var encounter_gen__pos : Point3List)
  encounter_gen__pos |> clear()
  var pos = transform[3]
  project_to_nearest_navmesh_point(pos, 0.5)
  set_rnd_seed(grazing_encounter_gen__numToPregenerate)
  while length(encounter_gen__pos) < grazing_encounter_gen__numToPregenerate
    var sine, cosine : float
    sincos(gfrnd() * TWOPI, sine, cosine)
    let r = gfrnd() * encounter_gen__minPoiDistance
    var spot = pos + float3(cosine * r, 0f, sine * r)
    if project_to_nearest_navmesh_point(spot, 0.5)
      encounter_gen__pos |> push(spot)

  removeSubTemplate(eid, "active_encounter_gen")
  addSubTemplate(eid, "finished_encounter_gen")


[es(no_order, on_appear, REQUIRE=(activeEncounterGen, vertical_surface_encounter__numToPregenerate))]
def vertical_surface_encounter_gen_pregenerate(evt : Event; eid : EntityId;
                                               vertical_surface_encounter__bounds : float4;
                                               encounter_gen__genTemplate : string;
                                               var encounter_gen__pos : Point3List;
                                               var encounter_gen__norm : Point3List)
  encounter_gen__pos |> clear()
  encounter_gen__norm |> clear()
  createEntity(encounter_gen__genTemplate) <| $(init)
    init |> set("vs_scanner__overallBounds", vertical_surface_encounter__bounds)
    init |> set("vs_scanner__reportTo", eid)


[es(no_order, REQUIRE=activeEncounterGen)]
def vertical_surface_encounter_gen_on_complete(evt : EventGenJobComplete;
                                               eid : EntityId;
                                               vertical_surface_encounter__numToPregenerate : int;
                                               var encounter_gen__pos : Point3List;
                                               var encounter_gen__norm : Point3List)
  query(evt.workerEid) <| $ [es] (vs_scanner__resultNorm, vs_scanner__resultPos : Point3List)
    let count = min(length(vs_scanner__resultPos), vertical_surface_encounter__numToPregenerate)
    let idxes <- (length(vs_scanner__resultPos) > count ?
                    get_shuffled_indexes(vs_scanner__resultPos, count) :
                    [for idx in iter_range(vs_scanner__resultPos); idx])
    for idx in idxes
      encounter_gen__pos |> push(vs_scanner__resultPos[idx])
      encounter_gen__norm |> push(vs_scanner__resultNorm[idx])
  destroyEntity(evt.workerEid)
  removeSubTemplate(eid, "active_encounter_gen")
  addSubTemplate(eid, "finished_encounter_gen")


[es(REQUIRE=finishedEncounterGen, on_appear)]
def on_encounter_gen_finished(evt : Event; eid : EntityId)
  console_print("{eid}<{getEntityTemplateName(eid)}> finished")
  let hasActiveGen = find_query() <| $ [es(REQUIRE=activeEncounterGen)] ()
    return true
  if !hasActiveGen
    using() <| $(var blk : DataBlock)
      query() <| $ [es(REQUIRE=finishedEncounterGen)] (eid : EntityId; encounter_gen__fileName : string; encounter_gen__norm : Point3List const?)
        var tName = getEntityTemplateName(eid)
        tName = remove_sub_template_name(tName, "finished_encounter_gen")

        entity_obj_editor_saveComponent(eid, "encounter_gen__pos")
        if encounter_gen__norm != null
          entity_obj_editor_saveComponent(eid, "encounter_gen__norm")

        editor_save_entity(eid, blk, tName)

        removeSubTemplate(eid, "finished_encounter_gen")
        datablock_save_to_text_file(blk, encounter_gen__fileName)
