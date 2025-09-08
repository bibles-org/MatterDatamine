require ecs
require ecs.safe
require game.utils.hero
require game.es.render.lut_switcher_common
require game.events.events
require game.es.game_effect_macro
require game.events.events_game
require math
require math.base
require DagorMath
require game.es.render.screen_effects_common


def disable_color_grading()
  query() <| $ [es] (var color_grading_items : Array; color_grading__death : Object)
    switch_color_grading(ecs_hash("death"), color_grading_items, color_grading__death, false)
  query() <| $ [es] (var color_grading_items : Array; color_grading__downed : Object)
    switch_color_grading(ecs_hash("downed"), color_grading_items, color_grading__downed, false)
  query() <| $ [es] (var color_grading_items : Array; color_grading__is_no_vision : Object)
    switch_color_grading(ecs_hash("no_vision"), color_grading_items, color_grading__is_no_vision, false)
  query() <| $ [es] (var color_grading_items : Array; color_grading__burning : Object)
    switch_color_grading(ecs_hash("burning"), color_grading_items, color_grading__burning, false)
  query() <| $ [es] (var color_grading_items : Array; color_grading__concussion : Object)
    switch_color_grading(ecs_hash("concussion"), color_grading_items, color_grading__concussion, false)
  query() <| $ [es] (var color_grading_items : Array; color_grading__pain : Object)
    switch_color_grading(ecs_hash("pain"), color_grading_items, color_grading__pain, false)

[es(track=isAlive, on_appear, REQUIRE=watchedByPlr, after=tonemapper_switcher_spectator)]
def tonemapper_switcher_death(evt : Event; isAlive : bool)
  if !is_camera_allow_effect()
    return
  query() <| $ [es] (var color_grading_items : Array; color_grading__death : Object)
    switch_color_grading(ecs_hash("death"), color_grading_items, color_grading__death, !isAlive)

[es(track=isDowned, on_appear, REQUIRE=watchedByPlr, after=tonemapper_switcher_spectator)]
def tonemapper_switcher_downed(evt : Event; isDowned : bool)
  if !is_camera_allow_effect()
    return
  query() <| $ [es] (var color_grading_items : Array; color_grading__downed : Object)
    switch_color_grading(ecs_hash("downed"), color_grading_items, color_grading__downed, isDowned)

[es(track=(isBlinded, isAlive), on_appear, REQUIRE=watchedByPlr, after=tonemapper_switcher_spectator)]
def tonemapper_switcher_no_vision(evt : Event; isBlinded : bool; isAlive : bool)
  if !is_camera_allow_effect()
    return
  query() <| $ [es] (var color_grading_items : Array; color_grading__is_no_vision : Object)
    switch_color_grading(ecs_hash("no_vision"), color_grading_items, color_grading__is_no_vision, isBlinded && isAlive)

[es(track=burning__isBurning, on_appear, REQUIRE=watchedByPlr, after=tonemapper_switcher_spectator)]
def tonemapper_switcher_burning(evt : Event; burning__isBurning : bool)
  if !is_camera_allow_effect()
    return
  query() <| $ [es] (var color_grading_items : Array; color_grading__burning : Object)
    switch_color_grading(ecs_hash("burning"), color_grading_items, color_grading__burning, burning__isBurning)

[es(track=hasConcussedVision, on_appear, REQUIRE=watchedByPlr, after=tonemapper_switcher_spectator)]
def tonemapper_switcher_concussion(evt : Event; hasConcussedVision : bool)
  if !is_camera_allow_effect()
    return
  query() <| $ [es] (var color_grading_items : Array; color_grading__concussion : Object)
    switch_color_grading(ecs_hash("concussion"), color_grading_items, color_grading__concussion, hasConcussedVision)

[es(track=pain__active, on_appear, REQUIRE=watchedByPlr, after=tonemapper_switcher_spectator)]
def tonemapper_switcher_pain(evt : Event; pain__active : bool)
  if !is_camera_allow_effect()
    return
  query() <| $ [es] (var color_grading_items : Array; color_grading__pain : Object)
    switch_color_grading(ecs_hash("pain"), color_grading_items, color_grading__pain, pain__active)

[es(on_appear, REQUIRE=watchedByPlr, REQUIRE_NOT=hero)]
def tonemapper_switcher_spectator(evt : Event)
  query() <| $ [es] (var color_grading_items : Array; color_grading__alive : Object)
    clear(color_grading_items)
    add_grading(ecs_hash("alive"), color_grading_items, color_grading__alive)

[es(track=input__enabled, on_appear, REQUIRE=hero)]
def tonemapper_switcher_input(evt : Event; input__enabled : bool)
  if !input__enabled
    query() <| $ [es] (var color_grading_items : Array; color_grading__alive : Object)
      clear(color_grading_items)
      add_grading(ecs_hash("alive"), color_grading_items, color_grading__alive)

[es(on_disappear, REQUIRE=watchedByPlr)]
def disable_color_grading_on_destroy_es(evt : Event)
  disable_color_grading()

[es(on_appear, REQUIRE=disableScreenEffects)]
def disable_color_grading_on_disabling_screen_effects(evt : Event;
                                                      camera__active : bool)
  if camera__active
    disable_color_grading()

[es(before=post_fx_es)]
def combined_color_grading_init_es(
                                   info : ecs::UpdateStageInfoAct;
                                   tonemap_save : Object;
                                   var color_grading_items : Array;
                                   var color_grading : Object)
  update_object_existing_fields_from(color_grading, tonemap_save)

  var idx = length(color_grading_items)
  while --idx >= 0
    var itemObj = getRW_ecs_object(color_grading_items[idx])
    var lifeTime = (*itemObj).life_time ?? 0.
    let timings = (*itemObj).timings ?? float3(0, 10000, 0)

    lifeTime += info.dt
    if lifeTime > timings.x + timings.y + timings.z
      erase(color_grading_items, idx)
      continue

    *itemObj |> set("life_time", lifeTime)

  for grading_item in color_grading_items
    let itemObj = getRW_ecs_object(grading_item)
    let lifeTime = (*itemObj).life_time ?? 0.
    let timings = (*itemObj).timings ?? float3(0, 10000, 0)
    let gradingFactor = (*itemObj).gradingFactor ?? 1.0

    var state = 0.0
    if lifeTime < timings.x
      state = safediv(lifeTime, timings.x)
    elif lifeTime < timings.x + timings.y
      state = 1.0
    else
      state = saturate(1.0 - safediv((lifeTime - timings.x - timings.y), timings.z))

    // Apply easing function here
    state = state * state * (3.0 - 2.0 * state)

    for field in *itemObj
      let baseValueF4 = color_grading[field.key] ?as float4
      if baseValueF4 != null
        let newValue = *(field.value as float4)
        set(color_grading, field.key, lerp(*baseValueF4, newValue, float4(state) * gradingFactor))
        continue
      let baseValueF = color_grading[field.key] ?as float
      if baseValueF != null
        let newValue = get_float(field.value) ?? 0.0
        set(color_grading, field.key, lerp(*baseValueF, newValue, state * gradingFactor))

[es(after=combined_color_grading_init_es)]//we can also require for some special tag/bool
def edit_color_grading_es(info : ecs::UpdateStageInfoAct; edit_color_grading : Object; edit_white_balance : Object; edit_tonemap : Object)
  query() <| $ [es] (var color_grading : Object)
    amend_object_from(color_grading, edit_color_grading)
  query() <| $ [es] (var tonemap : Object)
    amend_object_from(tonemap, edit_tonemap)
  query() <| $ [es] (var white_balance : Object)
    amend_object_from(white_balance, edit_white_balance)

[es(on_appear)]
def edit_color_grading_appear(evt : Event; var edit_color_grading : Object; var edit_white_balance : Object; var edit_tonemap : Object)
  query() <| $ [es] (color_grading : Object)
    update_object_existing_fields_from(edit_color_grading, color_grading)
  query() <| $ [es] (tonemap : Object)
    update_object_existing_fields_from(edit_tonemap, tonemap)
  query() <| $ [es] (white_balance : Object)
    update_object_existing_fields_from(edit_white_balance, white_balance)


[es(tag=render, no_order, REQUIRE=darknessAnomalyEffect)]
def darkness_anomaly_lut_update(act : UpdateStageInfoAct; game_effect__attachedTo : EntityId)
  if has(game_effect__attachedTo, "watchedByPlr")
    query() <| $ [es] (var color_grading_items : Array; color_grading__darknessAnomaly : Object)
      if !has_color_grading(color_grading_items, ecs_hash("darknessAnomaly"))
        switch_color_grading(ecs_hash("darknessAnomaly"), color_grading_items, color_grading__darknessAnomaly, true)
  else
    query() <| $ [es(REQUIRE=color_grading__darknessAnomaly)] (var color_grading_items : Array)
      if has_color_grading(color_grading_items, ecs_hash("darknessAnomaly"))
        remove_grading(ecs_hash("darknessAnomaly"), color_grading_items)


[es(on_disappear, REQUIRE=darknessAnomalyEffect)]
def darkness_anomaly_lut_destroy(evt : Event; game_effect__attachedTo : EntityId)
  if has(game_effect__attachedTo, "watchedByPlr")
    query() <| $ [es(REQUIRE=color_grading__darknessAnomaly)] (var color_grading_items : Array)
      if has_color_grading(color_grading_items, ecs_hash("darknessAnomaly"))
        remove_grading(ecs_hash("darknessAnomaly"), color_grading_items)
