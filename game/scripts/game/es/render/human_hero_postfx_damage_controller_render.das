require ecs
require ecs.safe
require math.base
require math.random
require game.es.render.lut_switcher_common
require DagorMath


[es(tag=render, track=(human_damage_model__sumHpAllBodyParts, human_damage_model__sumMaxHpAllBodyParts,
  human_damage_model__parts), on_appear, REQUIRE=watchedByPlr)]
def human_hero_postfx_damage_controller_track_health_factor(evt : Event;
                                                            eid : EntityId;
                                                            isAlive : bool = true;
                                                            human_damage_model__sumHpAllBodyParts : float;
                                                            human_damage_model__sumMaxHpAllBodyParts : float;
                                                            human_damage_model__parts : Object;
                                                            human_hero_postfx_damage_controller__healthFactorToApplyDamageAffect : float;
                                                            human_hero_postfx_damage_controller__damageAffectTemplate : string;
                                                            var human_hero_postfx_damage_controller__healthFactor : float&;
                                                            var human_hero_postfx_damage_controller__damageAffectEid : EntityId&)
  if isAlive
    let allBodyPartsProgress = safediv(human_damage_model__sumHpAllBodyParts, human_damage_model__sumMaxHpAllBodyParts)
    let allBodyPartsProgressSq = allBodyPartsProgress * allBodyPartsProgress
    var headProgress = 1.0
    let head = human_damage_model__parts.head ?as Object
    if head != null
      headProgress = safediv(head?.hp ?? 0.0, head?.maxHp ?? 0.0)

    var bodyProgress = 1.0
    let body = human_damage_model__parts.body ?as Object
    if body != null
      bodyProgress = safediv(body?.hp ?? 0.0, body?.maxHp ?? 0.0)

    var penaltyMult = 1.0
    for partComp in human_damage_model__parts
      let part = partComp.value as Object

      if part?.hp ?? 0.0 <= 0.0
        penaltyMult *= 0.75

    human_hero_postfx_damage_controller__healthFactor = min(allBodyPartsProgressSq, headProgress, bodyProgress) * penaltyMult
  else
    human_hero_postfx_damage_controller__healthFactor = 0.0

  let damageAffectRequired = human_hero_postfx_damage_controller__healthFactor <= human_hero_postfx_damage_controller__healthFactorToApplyDamageAffect
  let damageAffectExists = human_hero_postfx_damage_controller__damageAffectEid != INVALID_ENTITY_ID

  if damageAffectRequired
    let damageAffectFactor = cvt(human_hero_postfx_damage_controller__healthFactor, 0.0, human_hero_postfx_damage_controller__healthFactorToApplyDamageAffect, 1.0, 0.0)
    if !damageAffectExists
      human_hero_postfx_damage_controller__damageAffectEid = createEntity(human_hero_postfx_damage_controller__damageAffectTemplate) <| $ [es] (var init : ComponentsInitializer)
        init |> set("game_effect__attachedTo", eid)
        init |> set("human_hero_postfx_damage_affect__factor", damageAffectFactor)
    else
      query(human_hero_postfx_damage_controller__damageAffectEid) <| $ [es] (var human_hero_postfx_damage_affect__factor : float&)
        human_hero_postfx_damage_affect__factor = damageAffectFactor
  elif damageAffectExists
    destroyEntity(human_hero_postfx_damage_controller__damageAffectEid)
    human_hero_postfx_damage_controller__damageAffectEid = INVALID_ENTITY_ID


[es(tag=render, on_appear, track=human_hero_postfx_damage_affect__factor)]
def human_hero_postfx_damage_affect_track(evt : Event;
                                          human_hero_postfx_damage_affect__factor : float;
                                          human_hero_postfx_damage_affect__colorGain : float4;
                                          human_hero_postfx_damage_affect__colorGamma : float4;
                                          human_hero_postfx_damage_affect__colorContrast : float4;
                                          human_hero_postfx_damage_affect__colorSaturation : float4;
                                          var game_effect__colorGrading : Object)
  assume factor = human_hero_postfx_damage_affect__factor
  game_effect__colorGrading |> set("colorGain", lerp(float4(1.0), human_hero_postfx_damage_affect__colorGain, factor))
  game_effect__colorGrading |> set("colorGamma", lerp(float4(1.0), human_hero_postfx_damage_affect__colorGamma, factor))
  game_effect__colorGrading |> set("colorContrast", lerp(float4(1.0), human_hero_postfx_damage_affect__colorContrast, factor))
  game_effect__colorGrading |> set("colorSaturation", lerp(float4(1.0), human_hero_postfx_damage_affect__colorSaturation, factor))

  ecs::query() <| $ [es] (var color_grading_items : ecs::Array)
    update_grading(ecs_hash("game_effect"), color_grading_items, game_effect__colorGrading)


[es(tag=render, no_order, REQUIRE=watchedByPlr)]
def human_hero_postfx_damage_controller_update(info : UpdateStageInfoAct;
                                               isAlive : bool = true;
                                               human_hero_postfx_damage_controller__healthFactor : float;
                                               human_hero_postfx_damage_controller__healthFactorToShowVignette : float;
                                               human_hero_postfx_damage_controller__vignetteFactorMinMax : float2;
                                               human_hero_postfx_damage_controller__vignetteFactorAmplitude : float;
                                               human_hero_postfx_damage_controller__vignetteAlphaAmpiltude : float;
                                               human_hero_postfx_damage_controller__vignetteAnimFreq : float;
                                               human_hero_postfx_damage_controller__vignetteColor : float4)
  assume healthFactor = human_hero_postfx_damage_controller__healthFactor
  assume vignetteFactorMinMax = human_hero_postfx_damage_controller__vignetteFactorMinMax
  assume vignetteFactorAmplitude = human_hero_postfx_damage_controller__vignetteFactorAmplitude
  assume vignetteAlphaAmpiltude = human_hero_postfx_damage_controller__vignetteAlphaAmpiltude
  assume vignetteAnimFreq = human_hero_postfx_damage_controller__vignetteAnimFreq

  find_query() <| $ [es] (var postfx_vignette_controller__secondVignetteFactor : float&;
                          var postfx_vignette_controller__secondVignetteColor : float4&)
    if healthFactor >= human_hero_postfx_damage_controller__healthFactorToShowVignette
      postfx_vignette_controller__secondVignetteFactor = 0.0
      return true

    let vignettePower = 1.0 - cvt(healthFactor, 0.0, human_hero_postfx_damage_controller__healthFactorToShowVignette, 0.0, 1.0)

    let animK = isAlive ? sin(info.curTime * vignetteAnimFreq) : 1.0

    var vignetteColor = human_hero_postfx_damage_controller__vignetteColor
    let vignetteAlphaBase = vignettePower * human_hero_postfx_damage_controller__vignetteColor.w - vignetteAlphaAmpiltude
    let vignetteAlphaAnim = vignetteAlphaAmpiltude * animK
    vignetteColor.w = saturate(vignetteAlphaBase + vignetteAlphaAnim)

    let vignetteFactorBase = lerp(vignetteFactorMinMax.x, vignetteFactorMinMax.y, vignettePower)
    let vignetteFactorAnim = vignetteFactorAmplitude * animK

    postfx_vignette_controller__secondVignetteFactor = saturate(vignetteFactorBase + vignetteFactorAnim)
    postfx_vignette_controller__secondVignetteColor = vignetteColor
    return true


[es(tag=render, on_disappear, REQUIRE=(human_hero_postfx_damage_controller, watchedByPlr))]
def human_hero_postfx_damage_controller_on_disappear(evt : Event;
                                                     human_hero_postfx_damage_controller__damageAffectEid : EntityId)
  destroyEntity(human_hero_postfx_damage_controller__damageAffectEid)

  find_query() <| $ [es] (var postfx_vignette_controller__secondVignetteFactor : float&)
    postfx_vignette_controller__secondVignetteFactor = 0.0
    return true