require app
require ecs
require Grid
require DngNet
require net
require AnimV20
require math.base
require DagorMath
require DagorSystem
require GeomNodeTree
require Dacoll
require game.utils.net_utils
require game.utils.team
require game.events.events_active_matter
require game.es.entity_mods_common
require game.es.trace_common
require game.es.ecs_common


[es(tag=server, on_appear)]
def resources_gatherer_init(evt : Event;
                            eid : EntityId;
                            resources_gatherer__template : string;
                            var resources_gatherer__eid : EntityId&;
                            resources_gatherer_hero__nodeName : string;
                            var resources_gatherer_hero__nodeIdx : int&;
                            animchar : AnimcharBaseComponent)
  resources_gatherer__eid = createEntity(resources_gatherer__template) <| $(var init)
    init |> set("resources_gatherer_device__ownerEid", eid)
  let handNodeIdx = geomtree_findNodeIndex(*animchar.nodeTree, resources_gatherer_hero__nodeName)
  if handNodeIdx == -1
    logerr("<{getEntityTemplateName(eid)}> does not have '{resources_gatherer_hero__nodeName}' animchar node.")
  resources_gatherer_hero__nodeIdx = handNodeIdx


[es(tag=server, on_disappear)]
def resources_gatherer_destroy(evt : Event; resources_gatherer__eid : EntityId)
  destroyEntity(resources_gatherer__eid)


[es(tag=server, on_appear)]
def resources_gatherer_device_init(evt : Event;
                                   resources_gatherer_device__coneAngleDeg : float;
                                   var resources_gatherer_device__coneAngleCos : float&)
  resources_gatherer_device__coneAngleCos = cos(resources_gatherer_device__coneAngleDeg * DEG_TO_RAD)


[es]
def resources_gatherer_toogle(evt : CmdGathererToggle;
                              resources_gatherer_hero__enabled : bool;
                              resources_gatherer__eid : EntityId;
                              entity_mod_values : Object;
                              resources_gatherer_hero_debug : Tag const?)
  if resources_gatherer_hero_debug != null
    print("[RESOURCES GATHERER DEBUG] CmdGathererToggle RECEIVED
resources_gatherer_hero__enabled={resources_gatherer_hero__enabled}
evt.isOn={evt.isOn}")

  if !resources_gatherer_hero__enabled && evt.isOn
    return
  query(resources_gatherer__eid) <| $ [es] (resources_gatherer_device__tickInterval : float;
                                            resources_gatherer_device__affectTemplate : string;
                                            resources_gatherer_device__ownerEid : EntityId;
                                            var resources_gatherer_device__amPiles : EidList;
                                            var resources_gatherer_device__affectEid : EntityId&;
                                            var resources_gatherer_device__tickAt : float&;
                                            var resources_gatherer_device__gatherMultiplier : float&)
    if evt.isOn
      let tickValue = resources_gatherer_device__tickInterval / get_mod_value("activeMatterGatherSpeed", entity_mod_values, 1.0)
      resources_gatherer_device__tickAt = get_sync_time() + tickValue
    else
      resources_gatherer_device__tickAt = 0.f
      resources_gatherer_device__gatherMultiplier = 1.0

    if is_server()
      let affectExists = (resources_gatherer_device__affectEid != INVALID_ENTITY_ID)
      if affectExists && !evt.isOn
        destroyEntity(resources_gatherer_device__affectEid)
        resources_gatherer_device__affectEid = INVALID_ENTITY_ID
      elif !affectExists && evt.isOn
        resources_gatherer_device__affectEid = createEntity(resources_gatherer_device__affectTemplate) <| $ [es] (var init : ComponentsInitializer)
          init |> set("game_effect__attachedTo", resources_gatherer_device__ownerEid)
      clear(resources_gatherer_device__amPiles)


[es(tag=server, on_disappear)]
def resources_gatherer_device_on_disappear(evt : Event;
                                           resources_gatherer_device__affectEid : EntityId)
  destroyEntity(resources_gatherer_device__affectEid)


struct AmSourceData
  eid : EntityId
  am : int
  amFactor : float


[es(tag=server, no_order)]
def resources_gatherer_work(act : ParallelUpdateFrameDelayed;
                            resources_gatherer_device__ownerEid : EntityId;
                            resources_gatherer_device__range : float;
                            resources_gatherer_device__coneAngleCos : float;
                            resources_gatherer_device__pointBlankDist : float;
                            resources_gatherer_device__gatherRatePerTick : float;
                            resources_gatherer_device__tickInterval : float;
                            resources_gatherer_device__gatherMultiplierIncVel : float;
                            var resources_gatherer_device__amPiles : EidList;
                            var resources_gatherer_device__tickAt : float&;
                            var resources_gatherer_device__gatherMultiplier : float&)
  let dryRun = act.curTime < resources_gatherer_device__tickAt
  if resources_gatherer_device__tickAt > 0.f && (!dryRun || length(resources_gatherer_device__amPiles) == 0)
    clear(resources_gatherer_device__amPiles)
    query(resources_gatherer_device__ownerEid) <| $ [es] (possessedByPlr : EntityId;
                                                          animchar : AnimcharBaseComponent;
                                                          resources_gatherer_hero__enabled : bool;
                                                          resources_gatherer_hero__nodeIdx : int;
                                                          human__aimTm : float3x4;
                                                          am_storage__maxValue : int;
                                                          entity_mod_values : Object;
                                                          team aka owner_team : int = TEAM_UNASSIGNED;
                                                          resources_gatherer_hero_debug : Tag const?;
                                                          var am_storage__value : int&)
      if !resources_gatherer_hero__enabled

        if resources_gatherer_hero_debug != null
          print("[RESOURCES GATHERER DEBUG] Resources gatherer disabled for hero {resources_gatherer_device__ownerEid}")

        send_net_event(resources_gatherer_device__ownerEid, CmdGathererToggle(isOn = false))
        return

      if !dryRun
        let tickValue = resources_gatherer_device__tickInterval / get_mod_value("activeMatterGatherSpeed", entity_mod_values, 1.0)
        resources_gatherer_device__tickAt += tickValue

      if am_storage__value >= am_storage__maxValue
        return
      var nodeTm : float3x4
      geomtree_getNodeWtmScalar(*animchar.nodeTree, resources_gatherer_hero__nodeIdx, nodeTm)
      let sphere = BSphere3(nodeTm[3], resources_gatherer_device__range)

      var amSources : array<AmSourceData>
      var totalAvailableForGatherAm = 0.0
      for_each_entity_in_grid(ecs_hash("loot"), sphere, GridEntCheck.POS) <| $ [unused_argument(pos)] (eid : EntityId; pos : float3)
        query(eid) <| $ [es(REQUIRE=item__am)] (transform aka am_transform : float3x4;
                                                active_matter_pile__locked : bool;
                                                item__count : int;
                                                am_pile__visualItemPosOffset : float3 = float3(0, 0, 0))
          if active_matter_pile__locked
            return

          let amTracePos = am_transform[3] + rotate(am_transform, am_pile__visualItemPosOffset)
          let tracePos = nodeTm[3]
          let traceRay = amTracePos - nodeTm[3]
          let traceRayDist = length(traceRay)
          let traceRayDir = traceRay * safeinv(traceRayDist)
          let isRayAngleValid = dot(human__aimTm[0], traceRayDir) > resources_gatherer_device__coneAngleCos
          let isPointBlankDist = traceRayDist < resources_gatherer_device__pointBlankDist

          if (isRayAngleValid || isPointBlankDist) && !traceray_exclude_non_phys_collidable(tracePos, traceRayDir, traceRayDist, ETF_RI)
            if item__count > 0
              amSources |> push(AmSourceData(eid = eid, am = item__count))
              totalAvailableForGatherAm += float(item__count)

      for_each_entity_in_grid(ecs_hash("interactable"), sphere, GridEntCheck.POS) <| $ [unused_argument(pos)] (eid : EntityId; pos : float3)
        query(eid) <| $ [es] (active_matter_pile_provider__amSourceEid : EntityId;
                              ragdoll_phys_obj__attachedTo : EntityId;
                              active_matter_pile_provider__team : int = TEAM_UNASSIGNED)
          var corpseTag = ""
          query(ragdoll_phys_obj__attachedTo) <| $[es] (kill_tracking_tag : string)
            corpseTag := kill_tracking_tag
          if active_matter_pile_provider__team == TEAM_UNASSIGNED || active_matter_pile_provider__team == owner_team \
            || corpseTag == "turned_soldier"
            query(active_matter_pile_provider__amSourceEid) <| $ [es] (am_storage__value : int)
              if am_storage__value > 0
                amSources |> push(AmSourceData(eid = eid, am = am_storage__value))
                totalAvailableForGatherAm += float(am_storage__value)


      if length(amSources) > 0
        for amSource in amSources
          amSource.amFactor = float(amSource.am) / totalAvailableForGatherAm
        sort(amSources) <| $(lhs, rhs : AmSourceData)
          return lhs.am < rhs.am


        let gatherRate = resources_gatherer_device__gatherRatePerTick * resources_gatherer_device__gatherMultiplier
        var gatherLeft = ceili(gatherRate)

        var gatheredCount = 0
        var amStorageCapacityLeft = am_storage__maxValue - am_storage__value
        if !dryRun
          for amSource in amSources
            let wantGather = min(max(ceili(gatherRate * amSource.amFactor), 1), amSource.am)
            let canGather = min(min(wantGather, amStorageCapacityLeft), gatherLeft)
            var gathered = 0
            var success = query(amSource.eid) <| $ [es] (var item__count : int&)
              let maxGather = min(item__count, canGather)
              gathered += maxGather
              item__count -= maxGather
              if item__count == 0
                destroyEntity(amSource.eid)
            query(amSource.eid) <| $ [es] (active_matter_pile_provider__amSourceEid : EntityId)
              success ||= query(active_matter_pile_provider__amSourceEid) <| $ [es] (var am_storage__value : int&)
                let maxGather = min(am_storage__value, canGather)
                gathered += maxGather
                am_storage__value -= maxGather
                if am_storage__value == 0
                  send_net_event(amSource.eid, EventActiveMatterPileProviderExhausted())
            if !success
              logerr("Undefined amSource type: {get_entity_info(amSource.eid)}!")
            gatheredCount += gathered
            gatherLeft -= gathered
            amStorageCapacityLeft -= gathered

        if gatheredCount > 0
          am_storage__value += gatheredCount
          resources_gatherer_device__gatherMultiplier *= resources_gatherer_device__gatherMultiplierIncVel
          sendEvent(possessedByPlr, EventAmLooted(amount = gatheredCount))
          if am_storage__value >= am_storage__maxValue
            send_net_event(resources_gatherer_device__ownerEid, ShowStatusTip(statusTip = "status_tip_full_am"))
        else
          resources_gatherer_device__gatherMultiplier = 1.0
        for amSource in amSources
          resources_gatherer_device__amPiles |> push(amSource.eid)


[es(tag=gameClient, after=am_visual_reset_influence_from_gather, before=am_visual_anim_act)]
def resources_gatherer_work_client(act : ParallelUpdateFrameDelayed;
                                   resources_gatherer_device__ownerEid : EntityId;
                                   resources_gatherer_device__tickAt : float;
                                   resources_gatherer_device__amPiles : EidList;
                                   var resources_gatherer_device__animationEffect : EntityId&)
  if resources_gatherer_device__tickAt > 0.f && length(resources_gatherer_device__amPiles) > 0
    query(resources_gatherer_device__ownerEid) <| $ [es] (animchar : AnimcharBaseComponent;
                                                          resources_gatherer_hero__nodeIdx : int;
                                                          am_storage__maxValue : int;
                                                          am_storage__value : int)
      let canGather = am_storage__maxValue > am_storage__value
      if !canGather
        destroyEntity(resources_gatherer_device__animationEffect)
        resources_gatherer_device__animationEffect = INVALID_ENTITY_ID
        return
      var nodeTm : float3x4
      geomtree_getNodeWtmScalar(*animchar.nodeTree, resources_gatherer_hero__nodeIdx, nodeTm)

      var isAnyAmGathered = false
      for amSource in resources_gatherer_device__amPiles
        query(amSource) <| $ [es] (active_matter_pile__locked : bool = false;
                                   active_matter_pile__visualEid = INVALID_ENTITY_ID)
          if active_matter_pile__locked
            return
          let visEid = active_matter_pile__visualEid != INVALID_ENTITY_ID ? active_matter_pile__visualEid : amSource
          query(visEid) <| $ [es] (var am_pile_visual__influenceFromGatherers : Point3List)
            am_pile_visual__influenceFromGatherers |> push(nodeTm[3])
            isAnyAmGathered = true

      if isAnyAmGathered
        if resources_gatherer_device__animationEffect == INVALID_ENTITY_ID
          resources_gatherer_device__animationEffect = createEntity("gathering_am_anim+gathering_am_sound") <| $(init)
            init |> set("game_effect__attachedTo", resources_gatherer_device__ownerEid)
      elif resources_gatherer_device__animationEffect != INVALID_ENTITY_ID
        destroyEntity(resources_gatherer_device__animationEffect)
        resources_gatherer_device__animationEffect = INVALID_ENTITY_ID
  elif resources_gatherer_device__animationEffect != INVALID_ENTITY_ID
    destroyEntity(resources_gatherer_device__animationEffect)
    resources_gatherer_device__animationEffect = INVALID_ENTITY_ID


[es(tag=gameClient, on_disappear)]
def resources_gatherer_device_on_disappear_client(evt : Event;
                                                  resources_gatherer_device__animationEffect : EntityId)
  destroyEntity(resources_gatherer_device__animationEffect)


[es(tag=server, on_appear, REQUIRE=state__interruptGather)]
def gatherer_deactivating_on_state(evt : Event;
                                   eid : EntityId;
                                   game_effect__attachedTo : EntityId)
  query(game_effect__attachedTo) <| $ [es(REQUIRE=resources_gatherer_hero_debug)] ()
    print("[RESOURCES GATHERER DEBUG] Effect {get_entity_info(eid)} blocked resources gathering for actor {eid}")

  send_net_event(game_effect__attachedTo, CmdGathererToggle(isOn = false))
