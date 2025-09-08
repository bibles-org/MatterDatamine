require ecs
require ecs.safe
require app
require game.events.events_active_matter
require game.es.monster_common


def calculate_monster_aura_enabled(monster_eid : EntityId)
  var isSleeping = false
  var isAlive = false

  query(monster_eid) <| $ [es] (sleep_mode__isSleeping : bool const?;
                                sleeping_monster : Tag const?;
                                isAlive aka monster_isAlive : bool = true)
    isAlive = monster_isAlive
    isSleeping = is_monster_sleeping(sleep_mode__isSleeping, sleeping_monster)

  if !isAlive
    let hasAm = find_query() <| $ [es(REQUIRE=am_pile_attached_to_corpse__corpseEid)] (item__lastContainerOwnerEid : EntityId)
      return monster_eid == item__lastContainerOwnerEid
    if !hasAm
      return false
  else
    if isSleeping
      return false

  return true


[es(tag=gameClient, REQUIRE=monster_aura__enabled, on_event=EventEntityDied)]
def monster_aura_on_death(evt : Event;
                          eid : EntityId)
  addSubTemplate(eid, "monster_aura_update_at") <| $(var init : ComponentsInitializer)
    init |> set("monster_aura__updateAt", get_sync_time() + 1.0)


[es(tag=gameClient, track=monster_aura__enabled, on_appear)]
def monster_aura_attachments(evt : Event;
                             eid : EntityId;
                             watchedByPlr : EntityId const?;
                             monster_aura__enabled : bool;
                             monster_aura__watchedAttachments : StringList const?;
                             monster_aura__enabledAliveAttachments : StringList;
                             monster_aura__enabledDeadAttachments : StringList;
                             monster_aura__disabledAliveAttachments : StringList;
                             monster_aura__disabledDeadAttachments : StringList;
                             isAlive : bool = true;
                             var monster_aura__attachmentsEids : EidList)
  for effectEid in monster_aura__attachmentsEids
    destroyEntity(effectEid)
  monster_aura__attachmentsEids |> clear()

  assume aliveAttachments = monster_aura__enabled ? monster_aura__enabledAliveAttachments : monster_aura__disabledAliveAttachments
  assume deadAttachments = monster_aura__enabled ? monster_aura__enabledDeadAttachments : monster_aura__disabledDeadAttachments

  assume attachments = (watchedByPlr != null && monster_aura__watchedAttachments != null
    ? *monster_aura__watchedAttachments
    : isAlive ? aliveAttachments : deadAttachments)

  for it in attachments
    let effectEid = createEntity(string(it)) <| $(init)
      init |> set("game_effect__attachedTo", eid)
    monster_aura__attachmentsEids |> push(effectEid)


[es(tag=gameClient, no_order)]
def monster_aura_update_at(act : ParallelUpdateFrameDelayed;
                           eid : EntityId;
                           monster_aura__updateAt : float;
                           var monster_aura__enabled : bool&)
  if act.curTime >= monster_aura__updateAt
    removeSubTemplate(eid, "monster_aura_update_at")
    monster_aura__enabled = calculate_monster_aura_enabled(eid)


[es(tag=gameClient, on_event=(EventAmAttachedToCorpse, EventAmDrainedFromCorpse, EventMonsterAuraDirty), on_appear)]
def monster_aura_recalculate_by_event(evt : Event;
                                      eid : EntityId;
                                      var monster_aura__enabled : bool&)
  monster_aura__enabled = calculate_monster_aura_enabled(eid)


[es(tag=gameClient, on_appear, on_disappear, REQUIRE=(sleeping_monster, monster_aura__enabled))]
def monster_aura_sleeping_monster_client(evt : Event;
                                         eid : EntityId)
  sendEvent(eid, EventMonsterAuraDirty())


[es(tag=gameClient, track=sleep_mode__isSleeping, REQUIRE=sleep_mode__isSleeping)]
def monster_aura_track_sleep_mode(evt : Event;
                                  eid : EntityId;
                                  var monster_aura__enabled : bool&)
  monster_aura__enabled = calculate_monster_aura_enabled(eid)


[es(tag=gameClient, on_appear, REQUIRE=am_pile_attached_to_corpse__corpseEid)]
def enable_aura_on_attached_pile_appear(evt : Event; item__lastContainerOwnerEid : EntityId)
  query(item__lastContainerOwnerEid) <| $ [es] (var monster_aura__enabled : bool&)
    monster_aura__enabled = calculate_monster_aura_enabled(item__lastContainerOwnerEid)