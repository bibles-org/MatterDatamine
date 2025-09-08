require ecs

[es(on_appear)]
def ability_flags_disabler_set_es(evt : Event; game_effect__attachedTo : EntityId; game_effect__disableFlags : StringList)
  for flag in game_effect__disableFlags
    let flagStr = string(flag)
    setOptional(game_effect__attachedTo, flagStr, ecs_hash(flagStr), false)

[es(on_event=EventEntityDestroyed)]
def ability_flags_disabler_unset_es(evt : Event; game_effect__attachedTo : EntityId; game_effect__disableFlags : StringList)
  for flag in game_effect__disableFlags
    let flagStr = string(flag)
    setOptional(game_effect__attachedTo, flagStr, ecs_hash(flagStr), true)


[es(on_appear)]
def ability_flag_disabler_set_es(evt : Event; game_effect__attachedTo : EntityId; game_effect__disableFlag : string)
  setOptional(game_effect__attachedTo, game_effect__disableFlag, ecs_hash(game_effect__disableFlag), false)

[es(on_event=EventEntityDestroyed)]
def ability_flag_disabler_unset_es(evt : Event; game_effect__attachedTo : EntityId; game_effect__disableFlag : string)
  setOptional(game_effect__attachedTo, game_effect__disableFlag, ecs_hash(game_effect__disableFlag), true)


[es(on_appear)]
def ability_flag_disabler_once_set_es(evt : Event; game_effect__attachedTo : EntityId; game_effect__disableFlagOnce : string)
  setOptional(game_effect__attachedTo, game_effect__disableFlagOnce, ecs_hash(game_effect__disableFlagOnce), false)
