require ecs
require ecs.safe
require EffectorData
require GeomNodeTree
require game.events.events_game
require game.events.events_active_matter


[es(tag=gameClient, track=(human_net_phys__isClimbing, isAlive, isDowned, isInVehicle))]
def forse_reset_ik_for_climbing_over(evt : Event;
                                     human_net_phys__isClimbing : bool;
                                     isAlive : bool;
                                     isDowned : bool;
                                     isInVehicle : bool;
                                     human_anim__climbOverIKEffectName : string;
                                     var animchar_effectors__effectorsState : Object;
                                     var human_anim__climbOverIKEffectActive : bool&)
  if !human_net_phys__isClimbing || !isAlive || isDowned || isInVehicle
    var leftHandEffector = getNullableRW_EffectorData(animchar_effectors__effectorsState, human_anim__climbOverIKEffectName)
    if leftHandEffector != null
      leftHandEffector.weight = 0f
    human_anim__climbOverIKEffectActive = false


[es(tag=gameClient)]
def climbing_over_hand_ik_irq(evt : EventAnimIrq;
                              human_anim__climbOverAttachHandIrqName : string;
                              human_anim__climbOverDetachHandIrqName : string;
                              human_anim__climbOverIKEffectName : string;
                              anim_irq__eventNames : Object;
                              var animchar_effectors__effectorsState : Object;
                              var human_anim__climbOverIKEffectActive : bool&)

  for event in anim_irq__eventNames
    let eventObj = get_ecs_object(event.value)

    if evt.irqType != eventObj?.irqId ?? -1
      continue

    if event.key == human_anim__climbOverAttachHandIrqName
      human_anim__climbOverIKEffectActive = true
      return

    elif event.key == human_anim__climbOverDetachHandIrqName
      var leftHandEffector = getNullableRW_EffectorData(animchar_effectors__effectorsState, human_anim__climbOverIKEffectName)
      if leftHandEffector != null
        leftHandEffector.weight = 0f
      human_anim__climbOverIKEffectActive = false
      return


[es(tag=gameClient, before=before_animchar_update_sync, after=(after_net_phys_sync, human_anim_es))]
def climbing_over_hand_update(info : ParallelUpdateFrameDelayed;
                              transform : float3x4;
                              human_net_phys__climbToPos : float3;
                              human_anim__climbOverIKEffectActive : bool;
                              human_anim__climbOverIKEffectName : string;
                              var animchar_effectors__effectorsState : Object)
  if !human_anim__climbOverIKEffectActive
    return

  var leftHandEffector = getNullableRW_EffectorData(animchar_effectors__effectorsState, human_anim__climbOverIKEffectName)
  if leftHandEffector == null
    return

  var wtm = transform
  wtm[1] = -wtm[1]
  leftHandEffector.position = human_net_phys__climbToPos - geomtree_calc_optimal_wofs(transform[3])
  leftHandEffector.wtm = wtm
  leftHandEffector.wtm[3] = leftHandEffector.position
  leftHandEffector.weight = 1f
