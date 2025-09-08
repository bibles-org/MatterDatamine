require ecs
require game.events.events


[es(tag=server, on_appear)]
def perk_from_ability_init(evt : Event; game_effect__attachedTo : EntityId;
                           game_effect__perkName : string)
  sendEvent(game_effect__attachedTo, CmdChangePlayerPerk(perkName = game_effect__perkName, active = true))


[es(tag=server, on_disappear)]
def perk_from_ability_deinit(evt : Event; game_effect__attachedTo : EntityId;
                             game_effect__perkName : string)
  sendEvent(game_effect__attachedTo, CmdChangePlayerPerk(perkName = game_effect__perkName, active = false))