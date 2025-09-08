require ecs
require math
require math.base
require math.easing
require game.events.events_game
require game.events.events_active_matter
require RendInst
require DagorMath
require DagorSystem


[es(tag=server, on_appear, after=riextra_spawn_ri_es)]
def riextra_hp_to_hitpoints_init(evt : Event;
                                 ri_extra : RiExtraComponent;
                                 var riextra_hp_to_hitpoints__prevRiHp : float&)
  riextra_hp_to_hitpoints__prevRiHp = riex_get_hp(ri_extra.handle)


[es(tag=server, no_order)]
def riextra_hp_to_hitpoints_update(act : ParallelUpdateFrameDelayed;
                                   ri_extra : RiExtraComponent;
                                   hitpoints__maxHp : float;
                                   var riextra_hp_to_hitpoints__prevRiHp : float&;
                                   var hitpoints__hp : float&;
                                   var isAlive : bool&)
  let hp = riex_get_hp(ri_extra.handle)
  if hp != riextra_hp_to_hitpoints__prevRiHp
    let delta = hp - riextra_hp_to_hitpoints__prevRiHp
    riextra_hp_to_hitpoints__prevRiHp = hp

    hitpoints__hp = min(hitpoints__hp + delta, hitpoints__maxHp)
    if hitpoints__hp <= 0.0 && isAlive
      isAlive = false


[es(tag=server, track=isAlive, REQUIRE=riextra_destroy_on_death)]
def riextra_destroy_on_death(evt : Event;
                             eid : EntityId;
                             isAlive : bool)
  if !isAlive
    destroyEntity(eid)