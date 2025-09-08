require app
require ecs
require strings
require DngNet
require ecs.safe
require rapidjson
require JsonUtils
require game.es.app_common
require game.es.data_common
require game.events.events_game
require game.es.item_equip_common
require game.es.nexus_common
require game.es.nexus_loadout_common
require game.es.message_queue_common
require game.es.equipment_generator_common
require game.events.events_active_matter
require game.es.objectives.objective_common


def find_available_loadout_index(loadouts : Array)
  for index in iter_range(loadouts)
    var loadoutPtr = loadouts[index] as Object
    if loadoutPtr == null
      continue

    assume loadout = *loadoutPtr
    if !(loadout.locked ?? false)
      return index
  return -1


def parse_loadout_items(var loadoutObject : Object; loadoutInfo; name)
  using() <| $(var itemsArray : Array)
    loadoutInfo |> FindMember("items", JsonType.kArrayType) <| $(loadoutItems : JsonValue)
      loadoutItems |> GetArray() <| $(loadoutItemsArray : JsonConstArray)
        for loadoutItem in loadoutItemsArray
          if !parse_item_from_jwt(loadoutItem, itemsArray)
            continue

    if !ensure_items_has_suit(itemsArray)
      nexus_log("LOADOUT", "There is no suit in loadout \"{name}\". Skipping it")
      return
    nexus_log("LOADOUT", "Parsed loadout <{name}> with {length(itemsArray)} items")

    set(loadoutObject, "items", itemsArray)


def add_default_loadout(var loadouts : Array)
  using() <| $(var loadoutObject : Object)
    set(loadoutObject, "name", "Unknown")
    using() <| $(var itemsArray : Array)
      using() <| $(var itemObject : Object)
        itemObject |> set("itemId", "1")
        itemObject |> set("templateName", "suit_militant_light_b_item")
        itemObject |> set("parentItemId", "0")
        itemObject |> set("slotName", "equipment_chronogene_primary_1")
        itemsArray |> push(itemObject)
      set(loadoutObject, "items", itemsArray)
    loadouts |> push(loadoutObject)


[es(tag=server, REQUIRE=nexus_player)]
def nexus_init_player_loadouts(evt : CmdSendPlayerProfile;
                               eid aka player_eid : EntityId;
                               userid : uint64)
  let alreadyHasLoadouts = find_query() <| $ [es] (nexus_loadouts__owner : EntityId)
    return nexus_loadouts__owner == player_eid
  if alreadyHasLoadouts
    return

  using() <| $(var loadouts : Array)
    using() <| $(var jwtDecodedDocument : JsonDocument)
      let jwtDecoded = decode_jwt(evt.signedToken, PROFILE_LOADOUT_PUBLIC_KEY, jwtDecodedDocument)
      if jwtDecoded != DecodeJwtResult.OK
        if is_dev_circuit() // may be we used raw info instead token
          nexus_log("LOADOUT", "Failed decoding JWT for <{userid}>. Trying fallback to raw data...")
          jwtDecodedDocument |> Parse(evt.signedToken)
          if jwtDecodedDocument.HasParseError
            nexus_log("LOADOUT", "Parsing signed token error: <{jwtDecodedDocument.GetParseError}>")
            add_default_loadout(loadouts)
        else
          nexus_log("LOADOUT", "Failed decoding JWT for <{userid}>: <{evt.signedToken}>")
          return

      // Check session and userid
      let userId = jwtDecodedDocument |> json_get_or("userId", 0ul)
      if !is_dev_circuit() && userId != userid
        nexus_logerr("LOADOUT", "Fail load items for <{userid}>, expected <{userId}>")
        return
      let sessionIdStr = jwtDecodedDocument |> json_get_or("sessionId", "0")
      let sessionId = to_uint64(sessionIdStr)
      if !is_dev_circuit() && sessionId != get_session_id()
        nexus_log("LOADOUT", "Fail load items for <{userid}>, sessionId: <{sessionId}>, expected <{get_session_id()}>")
        return

      // Load contracts
      find_query() <| $ [es] (level__raidName : string)
        let raidName = jwtDecodedDocument |> json_get_or("raidName", "")
        if !is_dev_circuit() && (empty(raidName) || level__raidName != raidName)
          print("[Raid Profile] Contracts require raidName <{raidName}>, but have level raidName <{level__raidName}>")
          return true
        jwtDecodedDocument |> FindMember("contracts", JsonType.kArrayType) <| $(contracts : JsonValue)
          contracts |> GetArray() <| $(contractsArray : JsonConstArray)
            for contract in contractsArray
              make_objective_entity(contract, player_eid)
        return true

      jwtDecodedDocument |> FindMember("mints", JsonType.kArrayType) <| $(loadoutsInfo : JsonValue)
        loadoutsInfo |> GetArray() <| $(loadoutsArray : JsonConstArray)
          for loadoutInfo in loadoutsArray
            using() <| $(var loadoutObject : Object)
              let name = loadoutInfo |> json_get_or("name", "Loadout")
              set(loadoutObject, "name", name)
              parse_loadout_items(loadoutObject, loadoutInfo, name)
              loadouts |> push(loadoutObject)

      jwtDecodedDocument |> FindMember("loadouts_agency", JsonType.kObjectType) <| $(loadoutsAgencyInfo : JsonValue)
        let seed = loadoutsAgencyInfo |> json_get_or("seed", 0)
        let count = loadoutsAgencyInfo |> json_get_or("count", 0)
        find_query() <| $ [es] (nexus_agency_loadouts__generators : StringList;
                                nexus_agency_loadouts__names : StringList)
          let generatorIndexes = get_generator_indexes(seed, length(nexus_agency_loadouts__generators), count)
          for i in range(0, count)
            let generatorIndex = generatorIndexes[i]
            let generatorName := string(nexus_agency_loadouts__generators[generatorIndex])
            let loadoutName := string(nexus_agency_loadouts__names[generatorIndex])
            var loadoutSeed = seed + i
            using() <| $(var loadoutObject : Object)
              set(loadoutObject, "name", loadoutName)
              set(loadoutObject, "is_agency_loadout", true)
              generate_loadout(generatorName, 0.0, DEFAULT_BASE_VOLUME, true /*is_fill_inventories*/, loadoutSeed) <| $(itemsArray : Array)
                set(loadoutObject, "items", itemsArray)
              loadouts |> push(loadoutObject)
          return true
      if length(loadouts) == 0
        nexus_log("LOADOUT", "No avaliable loadouts")
        add_default_loadout(loadouts)
      createEntity("nexus_loadouts") <| $(var init)
        set(init, "nexus_loadouts__owner", player_eid)
        set(init, "nexus_loadouts__allLoadouts", loadouts)


[es(tag=server, REQUIRE=nexus_loadouts__allLoadouts, on_appear)]
def nexus_init_round_mode_loadouts(evt : Event;
                                   eid : EntityId)
  if !is_round_mode()
    return
  remote_add_sub_template(eid, "nexus_round_mode_loadouts")


[es(tag=server, on_appear)]
def nexus_battle_create_bot_loadouts_on_appear(evt : Event;
                                               eid aka player_eid : EntityId;
                                               init_nexus_bot_loadouts__file : string)
  using() <| $(var loadouts : Array)
    load_json_from_file(init_nexus_bot_loadouts__file) <| $(jsonDocument)
      jsonDocument |> GetArray() <| $(jsonLoadouts)
        for loadoutInfo in jsonLoadouts
          using() <| $(var loadoutObject : Object)
            let name = loadoutInfo |> json_get_or("name", "Loadout")
            set(loadoutObject, "name", name)
            parse_loadout_items(loadoutObject, loadoutInfo, name)
            loadouts |> push(loadoutObject)
    // create sync, so bot can choose a loadout right away
    // happens once per match for each bot
    createEntitySync("nexus_loadouts") <| $(var init)
      set(init, "nexus_loadouts__owner", player_eid)
      set(init, "nexus_loadouts__allLoadouts", loadouts)


[es(tag=server)]
def nexus_battle_user_select_loadout(evt : CmdNexusBattleSelectLoadout;
                                     eid aka player_eid : EntityId;
                                     var nexus_player_loadout__chosenIndex : int&)
  find_query() <| $ [es] (nexus_loadouts__owner : EntityId;
                          nexus_loadouts__allLoadouts : Array)
    if nexus_loadouts__owner != player_eid
      return false

    var index = evt.loadoutIndex
    nexus_log("LOADOUT", "Player<{player_eid}> selects loadout<{index}> (current={nexus_player_loadout__chosenIndex})")
    if index < 0 || length(nexus_loadouts__allLoadouts) <= index
      nexus_log("LOADOUT", "Invalid loadout<{index}> was passsed for loadout select")
      if evt.selectAnyIfUnavailable
        index = find_available_loadout_index(nexus_loadouts__allLoadouts)
        if index == -1
          nexus_log("LOADOUT", "Could not find available loadout for player<{player_eid}>")
          return true
        nexus_log("LOADOUT", "Found available loadout<{index}> for player<{player_eid}>")
      else
        nexus_log("LOADOUT", "Abort loadout selection")
        return true

    var loadoutPtr = nexus_loadouts__allLoadouts[index] as Object
    assume loadout = *loadoutPtr
    if loadout.locked ?? false
      nexus_log("LOADOUT", "Loadout<{index}> is locked for player<{player_eid}>")
      if evt.selectAnyIfUnavailable
        index = find_available_loadout_index(nexus_loadouts__allLoadouts)
        if index == -1
          nexus_log("LOADOUT", "Could not find available loadout for player<{player_eid}>")
          return true
        nexus_log("LOADOUT", "Found available loadout<{index}> for player<{player_eid}>")
        loadoutPtr = nexus_loadouts__allLoadouts[index] as Object
      else
        nexus_log("LOADOUT", "Abort loadout selection")
        return true

    if loadoutPtr == null
      nexus_log("LOADOUT", "Loadout is null")
      return true
    nexus_player_loadout__chosenIndex = index
    return true


[es(tag=server, REQUIRE=(nexus_militant, nexus_round_mode))]
def nexus_round_mode_lock_loadout_on_death(evt : EventEntityDied;
                                           possessedByPlr : EntityId)
  if !is_game_started()
    return
  query(possessedByPlr) <| $ [es] (nexus_player_loadout__takenIndex : int)
    assume index = nexus_player_loadout__takenIndex
    if index < 0
      return
    find_query() <| $ [es] (nexus_loadouts__owner : EntityId;
                            nexus_loadouts__roundsToCooldown : int;
                            var nexus_loadouts__allLoadouts : Array)
      if nexus_loadouts__owner != possessedByPlr
        return false
      if index >= length(nexus_loadouts__allLoadouts)
        return true
      var loadoutPtr = nexus_loadouts__allLoadouts[index] as Object
      if loadoutPtr == null
        return true

      assume loadout = *loadoutPtr
      set(loadout, "locked", true)
      set(loadout, "lockRoundsLeft", nexus_loadouts__roundsToCooldown)
      nexus_log("LOADOUT", "Loadout<{index}> is locked for {nexus_loadouts__roundsToCooldown} rounds for player<{possessedByPlr}>")
      return true


[es(tag=server)]
def nexus_round_mode_loadout_reset_lock(evt : EventNexusRoundModeRoundChange;
                                        nexus_loadouts__owner : EntityId;
                                        var nexus_loadouts__allLoadouts : Array)
  for i in iter_range(nexus_loadouts__allLoadouts)
    var loadoutPtr = nexus_loadouts__allLoadouts[i] as Object
    if loadoutPtr == null
      continue

    assume loadout = *loadoutPtr
    if !(loadout.locked ?? false)
      continue

    let prevLockRoundsLeft = loadout.lockRoundsLeft ?? 0
    let newLockRoundsLeft = max(0, prevLockRoundsLeft - 1)
    set(loadout, "lockRoundsLeft", newLockRoundsLeft)
    if newLockRoundsLeft <= 0
      nexus_log("LOADOUT", "Loadout<{i}> is unlocked for player<{nexus_loadouts__owner}>")
      set(loadout, "locked", false)
