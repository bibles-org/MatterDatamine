require ecs
require strings
require DngNet
require game.events.events_game
require matching
require DngMatching
require game.es.level_common
require game.es.nexus_common
require game.events.player_events
require rapidjson
require game.utils.debug_bots


[es(tag=server, on_event=EventLevelLoaded)]
def level_loaded_events_es(evt : Event)
  on_level_loaded()

[es(tag=server)]
def matching_events_es(evt : EventTeamMemberJoined)
  let eid = evt.eid
  let team = evt.team
  query(eid) <| $ [es] (userid : uint64)
    if userid != INVALID_USER_ID
      on_player_team_changed(userid, team)


[es(tag=server, on_event=EventLevelLoaded)]
def apply_matching_extra_params(evt : Event)
  get_matching_invite_data() |> FindMember("extraParams", JsonType.kObjectType) <| $(extraParams : JsonValue)
    if extraParams.IsNull
      print("[Level extra params] No extra params...")
      return
    query() <| $ [es] (var level__raidName : das_string&)
      level__raidName := json_get_or(extraParams, "raidName", "")
      print("[Level extra params] Level raid name is <{level__raidName}>")


[es(tag=server, on_event=EventLevelLoaded)]
def parse_squad_infofrom_invite_data(evt : Event)
  if !is_raid_mode()
    return

  var squads : table<uint; array<uint64>>
  get_matching_invite_data() |> FindMember("members", JsonType.kArrayType) <| $(members : JsonValue)
    members |> GetArray() <| $(membersArray : JsonConstArray)
      for member in membersArray
        let userId = json_get_or(member, "userId", INVALID_USER_ID)
        if userId == INVALID_USER_ID
          print("[SQUAD INFO] Invalid user id")
          continue

        FindMember(member, "public", JsonType.kObjectType) <| $(publicInfo : JsonValue)
          let squadId = json_get_or(publicInfo, "squadId", INVALID_SQUAD_ID)
          if squadId == INVALID_SQUAD_ID
            print("[SQUAD INFO] Invalid squad id for user {userId}")
            return

          print("[SQUAD INFO] User {userId} is in squad {squadId}")

          var found = false
          get(squads, squadId) <| $(var squadMembers : array<uint64>)
            squadMembers |> push(userId)
            found = true

          if !found
            squads[squadId] <- array<uint64>(userId)

  print("[SQUAD INFO] Parsed info of {length(squads)} squads from matching")
  for squadId, squadMembers in keys(squads), values(squads)
    print("[SQUAD INFO] Squad {squadId} has {length(squadMembers)} members")
    using() <| $(var squadMembersList : UInt64List)
      for userId in squadMembers
        squadMembersList |> push(userId)
      createEntity("squad") <| $(init)
        set(init, "squad__squadId", squadId)
        set(init, "squad__memberUserIds", squadMembersList)
