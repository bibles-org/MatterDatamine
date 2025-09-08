require ecs
require app
require game.events.events_game
require game.events.sound_net_events
require DngDm
require DngNet
require game.utils.net_utils


[es(tag=server)]
def human_hit_net_sound(evt : EventOnEntityHit;
                        eid : EntityId;
                        human_hit_net_sound__range : float;
                        var human_hit_net_sound__nextSoundAt : float&;
                        human_hit_net_sound__cooldown : float)

  if evt.victim == eid && evt.damageType != int(DamageType.DM_PROJECTILE) && get_sync_time() > human_hit_net_sound__nextSoundAt

    human_hit_net_sound__nextSoundAt = get_sync_time() + human_hit_net_sound__cooldown

    send_net_event(eid, CmdHumanHitNetSound(offender = evt.offender,
                                            damageType = evt.damageType,
                                            actionPropsId = evt.actionPropsId,
                                            collNodeId = evt.collNodeId,
                                            shatterCount = evt.shatterCount,
                                            time = get_sync_time()),
                   enum_connections_near_pos(evt.hitPos, human_hit_net_sound__range))
