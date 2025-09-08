require ecs

[es(on_appear, track=game_effect__attachedTo)]
def ability_flag_enable_es(evt : Event; game_effect__attachedTo : EntityId; game_effect__enableFlag : string)
  setOptional(game_effect__attachedTo, game_effect__enableFlag, ecs_hash(game_effect__enableFlag), true)

[es(on_disappear)]
def ability_flag_disable_es(evt : Event; game_effect__attachedTo : EntityId; game_effect__enableFlag : string)
  setOptional(game_effect__attachedTo, game_effect__enableFlag, ecs_hash(game_effect__enableFlag), false)

[es(on_appear, tag=server, track=game_effect__attachedTo)]
def ability_server_flag_enable_es(evt : Event; game_effect__attachedTo : EntityId; game_effect__enableServerFlag : string)
  setOptional(game_effect__attachedTo, game_effect__enableServerFlag, ecs_hash(game_effect__enableServerFlag), true)

[es(on_disappear, tag=server)]
def ability_server_flag_disable_es(evt : Event; game_effect__attachedTo : EntityId; game_effect__enableServerFlag : string)
  setOptional(game_effect__attachedTo, game_effect__enableServerFlag, ecs_hash(game_effect__enableServerFlag), false)


[es(on_appear, track=game_effect__attachedTo)]
def game_effect_set_int_es(evt : Event;
                           game_effect__attachedTo : EntityId;
                           game_effect__setInt : string;
                           game_effect__intValue : int)
  setOptional(game_effect__attachedTo, game_effect__setInt, ecs_hash(game_effect__setInt), game_effect__intValue)


[es(on_appear)]
def ability_flag_enabler_once_set_es(evt : Event; game_effect__attachedTo : EntityId; game_effect__enableFlagOnce : string)
  setOptional(game_effect__attachedTo, game_effect__enableFlagOnce, ecs_hash(game_effect__enableFlagOnce), true)


[es(on_appear)]
def ability_flags_enabler_set(evt : Event; game_effect__attachedTo : EntityId; game_effect__enableFlags : StringList)
  for flag in game_effect__enableFlags
    let flagStr = string(flag)
    setOptional(game_effect__attachedTo, flagStr, ecs_hash(flagStr), true)


[es(on_event=EventEntityDestroyed)]
def ability_flags_enabler_unset(evt : Event; game_effect__attachedTo : EntityId; game_effect__enableFlags : StringList)
  for flag in game_effect__enableFlags
    let flagStr = string(flag)
    setOptional(game_effect__attachedTo, flagStr, ecs_hash(flagStr), false)
