require ecs
require PhysVars
require game.events.inventory_events
require game.events.events_active_matter
require game.es.loading_ammo_common
require DagorMath
require AnimV20


[es(on_appear)]
def human_anim_phys_vars_init(evt : Event;
                              var human_anim__loadingAmmoProgressVarId : int&;
                              var human_anim__loadingAmmoTypeVarId : int&;
                              var phys_vars : PhysVars)
  human_anim__loadingAmmoProgressVarId = registerVar(phys_vars, "loading_ammo_progress", 0.0)
  human_anim__loadingAmmoTypeVarId = registerVar(phys_vars, "loading_ammo_type", 0.0)


[es(tag=server)]
def loading_ammo_controller_on_loading_start(evt : NotifyItemHolderLoadingStart;
                                             human_inventory__itemHolderLoadingMult : float = 1.0;
                                             var loading_ammo_controller__state : int&;
                                             var loading_ammo_controller__loadingProcessEid : EntityId&)
  // Skip instant reloads
  if human_inventory__itemHolderLoadingMult >= 1e3
    return

  if has(evt.holderEid, "ammo_holder__loadingAmmoType")
    loading_ammo_controller__state = int(LoadingAmmoState.USING)
    loading_ammo_controller__loadingProcessEid = evt.processEid


[es(tag=server)]
def loading_ammo_controller_on_loading_end(evt : NotifyItemHolderLoadingEnd;
                                           var loading_ammo_controller__state : int&;
                                           var loading_ammo_controller__loadingProcessEid : EntityId&)
  if loading_ammo_controller__loadingProcessEid == evt.processEid
    loading_ammo_controller__state = int(LoadingAmmoState.NONE)
    loading_ammo_controller__loadingProcessEid = INVALID_ENTITY_ID


[es(tag=gameClient, on_appear, REQUIRE=loading_ammo_affect)]
def loading_ammo_affect_init_client(evt : Event;
                                    game_effect__attachedTo : EntityId;
                                    loading_ammo_affect__holderEid : EntityId;
                                    loading_ammo_affect__wishToLoad : bool)
  query(game_effect__attachedTo) <| $ [es] (human_anim__loadingAmmoProgressVarId : int;
                                            human_anim__loadingAmmoTypeVarId : int;
                                            loading_ammo_controller__loadingAnimationStateStart : float;
                                            loading_ammo_controller__unloadingAnimationStateStart : float;
                                            var phys_vars : PhysVars)
    query(loading_ammo_affect__holderEid) <| $ [es] (@shared_comp ammo_holder__loadingAmmoType : das_string)
      let progress = loading_ammo_affect__wishToLoad ? loading_ammo_controller__loadingAnimationStateStart : loading_ammo_controller__unloadingAnimationStateStart
      setVar(phys_vars, human_anim__loadingAmmoProgressVarId, progress)
      let loadingAmmoType = animV20_get_enum_value_by_name(string(ammo_holder__loadingAmmoType))
      setVar(phys_vars, human_anim__loadingAmmoTypeVarId, float(loadingAmmoType))


[es(tag=server, track=loading_ammo_controller__state)]
def loading_ammo_controller_track_state(evt : Event;
                                        eid aka actor_eid : EntityId;
                                        loading_ammo_controller__state : int;
                                        loading_ammo_controller__loadingProcessEid : EntityId;
                                        var loading_ammo_controller__loadingAffectEid : EntityId&)
  let loadingAffectRequired = (loading_ammo_controller__state != int(LoadingAmmoState.NONE))
  let loadingAffectExists = (loading_ammo_controller__loadingAffectEid != INVALID_ENTITY_ID)

  if loadingAffectRequired && !loadingAffectExists
    query(loading_ammo_controller__loadingProcessEid) <| $ [es] (item_loading__holderEid : EntityId;
                                                                 item_loading__totalItemCountToLoad : int;
                                                                 item_loading__wishToLoad : bool)
      query(item_loading__holderEid) <| $ [es] (animchar__res : string;
                                                animchar__objTexReplace : Object const?;
                                                requires_distortion_render : Tag const?)
        var loadingAffectTemplate = "magazine_loading_ammo_affect"
        if requires_distortion_render != null
          loadingAffectTemplate = add_sub_template_name(loadingAffectTemplate, "requires_distortion_render")
        loading_ammo_controller__loadingAffectEid = createEntity(loadingAffectTemplate) <| $(var init : ComponentsInitializer)
          init |> set("game_effect__attachedTo", actor_eid)
          init |> set("animchar__res", animchar__res)
          if animchar__objTexReplace != null
            init |> set("animchar__objTexReplace", *animchar__objTexReplace)
          init |> set("loading_ammo_affect__holderEid", item_loading__holderEid)
          init |> set("loading_ammo_affect__totalAmmoToLoad", item_loading__totalItemCountToLoad)
          init |> set("loading_ammo_affect__wishToLoad", item_loading__wishToLoad)

  elif !loadingAffectRequired && loadingAffectExists
    destroyEntity(loading_ammo_controller__loadingAffectEid)
    loading_ammo_controller__loadingAffectEid = INVALID_ENTITY_ID


[es(no_order, tag=gameClient)]
def loading_ammo_controller_update(info : ParallelUpdateFrameDelayed;
                                   loading_ammo_controller__state : int;
                                   human_inventory__entityToUse : EntityId;
                                   human_inventory__entityUseStart : float;
                                   human_inventory__entityUseEnd : float;
                                   human_inventory__itemHolderLoadingMult : float = 1.0;
                                   human_anim__loadingAmmoProgressVarId : int;
                                   loading_ammo_controller__loadingAnimationStateStart : float;
                                   loading_ammo_controller__loadingAnimationStateLoopStart : float;
                                   loading_ammo_controller__loadingAnimationStateLoopEnd : float;
                                   loading_ammo_controller__unloadingAnimationStateStart : float;
                                   loading_ammo_controller__unloadingAnimationStateLoopStart : float;
                                   loading_ammo_controller__unloadingAnimationStateLoopEnd : float;
                                   loading_ammo_controller__loadingAffectEid : EntityId;
                                   var phys_vars : PhysVars)
  if loading_ammo_controller__state == int(LoadingAmmoState.NONE)
    return

  if human_inventory__entityToUse == INVALID_ENTITY_ID
    return

  let invAmmoLoadingMult = safeinv(human_inventory__itemHolderLoadingMult)

  query(loading_ammo_controller__loadingAffectEid) <| $ [es] (loading_ammo_affect__totalAmmoToLoad : int;
                                                              loading_ammo_affect__holderEid : EntityId;
                                                              loading_ammo_affect__wishToLoad : bool;
                                                              magazine_anim__curNumAmmoParamId : int = -1;
                                                              var animchar : AnimcharBaseComponent?)
    assume animationStateStart = (loading_ammo_affect__wishToLoad ? loading_ammo_controller__loadingAnimationStateStart
                                                                  : loading_ammo_controller__unloadingAnimationStateStart)
    assume animationStateLoopStart = (loading_ammo_affect__wishToLoad ? loading_ammo_controller__loadingAnimationStateLoopStart
                                                                      : loading_ammo_controller__unloadingAnimationStateLoopStart)
    assume animationStateLoopEnd = (loading_ammo_affect__wishToLoad ? loading_ammo_controller__loadingAnimationStateLoopEnd
                                                                    : loading_ammo_controller__unloadingAnimationStateLoopEnd)

    query(loading_ammo_affect__holderEid) <| $ [es] (item_holder__loadInOutTime : float2;
                                                     item_holder__unloadInOutTime : float2;
                                                     item__currentBoxedItemCount : int = -1)
      if animchar != null && item__currentBoxedItemCount != -1 && magazine_anim__curNumAmmoParamId != -1
        *animchar.animState |> anim_state_holder_setParam(magazine_anim__curNumAmmoParamId, float(item__currentBoxedItemCount))

      let inOutTime = loading_ammo_affect__wishToLoad ? item_holder__loadInOutTime : item_holder__unloadInOutTime

      let passedTime = info.curTime - human_inventory__entityUseStart
      assume inTime = inOutTime.x * invAmmoLoadingMult
      assume outTime = inOutTime.y * invAmmoLoadingMult

      let useTime = human_inventory__entityUseEnd - human_inventory__entityUseStart
      let loadingTime = useTime - (inTime + outTime)


      // In delay
      if passedTime < inTime
        setVar(phys_vars, human_anim__loadingAmmoProgressVarId, animationStateStart + safediv(passedTime, inTime))
        return
      // Out delay
      elif passedTime > useTime - outTime
        setVar(phys_vars, human_anim__loadingAmmoProgressVarId, animationStateLoopEnd + saturate(1.0 - safediv(useTime - passedTime, outTime)))
        return
      // Loading
      else
        let loadingPassedTime = passedTime - inTime

        let timePerBullet = loadingTime / float(loading_ammo_affect__totalAmmoToLoad)
        let loadingBulletProgress = fract(safediv(loadingPassedTime, timePerBullet))
        setVar(phys_vars, human_anim__loadingAmmoProgressVarId, animationStateLoopStart + loadingBulletProgress)

