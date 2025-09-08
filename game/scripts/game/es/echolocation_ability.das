require ecs
require app

let DASH_ABILITY_NAME = "echolocation"

[es(tag=server, on_appear)]
def process_ability_acholocation(evt : Event; game_effect__attachedTo : EntityId; ability_echolocation__duration : float)
  let key = "{game_effect__attachedTo}"
  query() <| $ [es(REQUIRE_NOT=(player_controlled_monster, deadEntity))] (var hunter_vision_target__keepFxUntil : Object; hunter_vision_target__fxDurationMult : float)
    let existingTime = get_float(hunter_vision_target__keepFxUntil, key) ?? .0
    let newTime = max(existingTime, get_sync_time() + ability_echolocation__duration * hunter_vision_target__fxDurationMult)
    set(hunter_vision_target__keepFxUntil, key, newTime)