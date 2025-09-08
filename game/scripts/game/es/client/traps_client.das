require ecs
require ecs.safe
require math
require math.base
require math.random
require level
require fx
require game.events.events_active_matter
require game.es.grav_zones_common
require game.es.tweening_common
require game.es.traps_common
require DagorMath
require DagorSystem
require Dacoll
require PhysMat


[es(tag=gameClient, on_disappear)]
def anomaly_trap_client_disappear(evt : Event;
                                  transform : float3x4;
                                  anomaly_trap__triggerFx : string;
                                  anomaly_trap__triggerFxScale : float;
                                  anomaly_trap__triggerFxOffset : float3)
  if anomaly_trap__triggerFx != "" && are_grav_zones_loaded() && !is_level_unloading()
    let gravDir = get_grav_dir(transform[3])
    let gravTm = build_grav_tm(transform[3], gravDir)
    var fxTm = gravTm * scale_tm(anomaly_trap__triggerFxScale)
    fxTm[3] += rotate(gravTm, anomaly_trap__triggerFxOffset)
    start_effect(get_type_by_name(anomaly_trap__triggerFx),
                fxTm,
                IDENT_TM,
                true)


[es(tag=gameClient, on_appear)]
def anomaly_trap_visual_fx_controller_appear(evt : Event;
                                             transform : float3x4;
                                             anomaly_trap_visual_fx_controller__fxTemplates : StringList;
                                             var anomaly_trap_visual_fx_controller__fxEids : EidList)
  anomaly_trap_visual_fx_controller__fxEids |> resize(length(anomaly_trap_visual_fx_controller__fxTemplates))
  for fxEid, fxTemplate in anomaly_trap_visual_fx_controller__fxEids, anomaly_trap_visual_fx_controller__fxTemplates
    fxEid = createEntity(string(fxTemplate)) <| $ [es] (var init : ComponentsInitializer)
      let tm = are_grav_zones_loaded() ? get_grav_tm(transform[3]) : transform
      init |> set("transform", tm)


[es(tag=gameClient, on_disappear)]
def anomaly_trap_visual_fx_controller_disappear(evt : Event;
                                                anomaly_trap_visual_fx_controller__fxEids : EidList)
  for fxEid in anomaly_trap_visual_fx_controller__fxEids
    destroyEntity(fxEid)


[es(tag=gameClient, on_appear)]
def frog_trap_client_appear(evt : Event;
                            transform aka trap_transform : float3x4;
                            frog_trap__visualTemplate : string = "";
                            var frog_trap__visualEid : EntityId?;
                            @shared_comp frog_trap__debrisFxPerPhysMat : Object;
                            var frog_trap__debrisFxTypePerPhysMatId : Object)
  if frog_trap__visualEid != null && frog_trap__visualTemplate != ""
    *frog_trap__visualEid = createEntity(frog_trap__visualTemplate) <| $ [es] (var init : ComponentsInitializer)
      var tm = IDENT_TM
      tm[3] = trap_transform[3]
      init |> set("transform", tm)

  for data in frog_trap__debrisFxPerPhysMat
    let pmatId = get_material_id(data.key)
    let fxType = get_type_by_name(data.value ?? "")
    frog_trap__debrisFxTypePerPhysMatId |> set("{pmatId}", fxType)


[es(tag=gameClient, on_disappear)]
def frog_trap_client_disappear(evt : Event;
                               transform : float3x4;
                               trigger_trap__affectRadius : float;
                               frog_trap__debrisFxTypePerPhysMatId : Object)
  if !empty(frog_trap__debrisFxTypePerPhysMatId) && are_grav_zones_loaded() && !is_level_unloading()
    let gravDir = get_grav_dir(transform[3])
    let gravTm = build_grav_tm(transform[3], gravDir)
    var t = trigger_trap__affectRadius
    var norm : float3
    var rendInstDesc = RendInstDesc()
    var pmid : int
    if traceray_normalized(transform[3], gravDir, t, pmid, norm, ETF_DEFAULT, rendInstDesc, PHYSMAT_INVALID)
      let debrisFxType = frog_trap__debrisFxTypePerPhysMatId["{pmid}"] ?? frog_trap__debrisFxTypePerPhysMatId["0"] ?? -1
      if debrisFxType >= 0
        start_effect(debrisFxType,
                    gravTm,
                    IDENT_TM,
                    true)

[es(tag=gameClient, track=teleport_trap_affect__state)]
def teleport_trap_affect_track_state_client(evt : Event;
                                            teleport_trap_affect__teleportTm : float3x4;
                                            teleport_trap_affect__state : int;
                                            teleport_trap_affect__teleportFx : string;
                                            teleport_trap_affect__teleportFxScale : float;
                                            teleport_trap_affect__teleportFxOffset : float3)
  if teleport_trap_affect__state == int(TeleportTrapAffectState.TELEPORT)
    if teleport_trap_affect__teleportFx != ""
      var fxTm = teleport_trap_affect__teleportTm * scale_tm(teleport_trap_affect__teleportFxScale)
      fxTm[3] += rotate(teleport_trap_affect__teleportTm, teleport_trap_affect__teleportFxOffset)
      start_effect(get_type_by_name(teleport_trap_affect__teleportFx),
                  fxTm,
                  IDENT_TM,
                  true)