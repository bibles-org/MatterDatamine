require ecs
require ecs.safe
require app
require net
require math.base
require game.events.events
require game.events.events_game
require game.events.events_active_matter
require game.es.action_common
require DngNet
require DngCamera
require DngPhysObj
require DngHuman
require DagorMath
require Grid


[es(tag=gameClient, no_order)]
def mothman_diving_grab_ability_update_client(evt : UpdateStageInfoAct;
                                              eid aka mothman_eid : EntityId;
                                              transform : float3x4;
                                              hero_ability__abilitiesNextUseTime : Object;
                                              mothman_diving_grab_ability__potentialTargetSphereOffset : float3;
                                              mothman_diving_grab_ability__potentialTargetSphereRadius : float;
                                              mothman_diving_grab_ability__potentialTargetUpdateInterval : float;
                                              mothman_diving_grab_ability__targetEid : EntityId;
                                              var mothman_diving_grab_ability__potentialTargetUpdateAt : float&;
                                              var mothman_diving_grab_ability__potentialTargetEid : EntityId&)
  if get_sync_time() >= mothman_diving_grab_ability__potentialTargetUpdateAt
    mothman_diving_grab_ability__potentialTargetUpdateAt = get_sync_time() + mothman_diving_grab_ability__potentialTargetUpdateInterval

    if mothman_diving_grab_ability__targetEid != INVALID_ENTITY_ID
      mothman_diving_grab_ability__potentialTargetEid = mothman_diving_grab_ability__targetEid
      return

    mothman_diving_grab_ability__potentialTargetEid = INVALID_ENTITY_ID

    let abilityNextUseTime = hero_ability__abilitiesNextUseTime["mothman_grab_enemy"] ?? 0.0
    if abilityNextUseTime > evt.curTime
      return

    var potentialTargetDot = -1.0;

    let mothmanDir = transform[0]

    let offsetWS = rotate(transform, mothman_diving_grab_ability__potentialTargetSphereOffset)
    let spherePos = transform[3] + offsetWS

    let sphere = BSphere3(spherePos, mothman_diving_grab_ability__potentialTargetSphereRadius)
    for_each_entity_in_grid(ecs_hash("humans"), sphere, GridEntCheck.BOUNDING) <| $(target_eid : EntityId; pos : float3)
      if mothman_eid == target_eid
        return

      query(target_eid) <| $ [es(REQUIRE_NOT=deadEntity, REQUIRE=human_net_phys)] ()
        let toTarget = pos - transform[3]
        let toTargetDistSq = length_sq(toTarget)
        if toTargetDistSq < VERY_SMALL_NUMBER
          return
        let toTargetDist = sqrt(toTargetDistSq)
        let toTargetDir = toTarget / toTargetDist

        let dot = dot(mothmanDir, toTargetDir)
        if dot > potentialTargetDot
          potentialTargetDot = dot
          mothman_diving_grab_ability__potentialTargetEid = target_eid
