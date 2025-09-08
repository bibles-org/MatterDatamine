require ecs
require DngNet
require strings
require ecs.safe
require rapidjson
require JsonUtils
require game.es.app_common
require game.es.data_common
require game.es.item_equip_common
require game.es.objectives_enums_common
require game.events.events_active_matter
require game.es.equipment_generator_common
require game.es.objectives.objective_common


def private check_string_in_array(string_to_check, arrayName : string; json_value : JsonValue)
  var result = false
  let arrayFounded = json_value |> FindMember(arrayName, JsonType.kArrayType) <| $(arrayJsonValue : JsonValue)
    arrayJsonValue |> GetArray() <| $(arrayJson : JsonConstArray)
      var totalIterations = 0
      for memberJson in arrayJson
        ++totalIterations
        let stringValue = json_value_or(memberJson, "")
        result = stringValue == string_to_check
        if result
          break
      result = totalIterations == 0 || result
  return !arrayFounded || result


[es(tag=server, REQUIRE_NOT=nexus_player)]
def server_parse_signed_token(evt : CmdSendPlayerProfile;
                              userid : uint64;
                              connid : int;
                              eid aka player_eid : EntityId;
                              var player__isRentedEquipment : bool&;
                              var initialHeroItems : Array&;
                              var player__loadoutRecieved : bool&;
                              var clientNetFlags : int&;
                              var player_ribbons__curColors : int2&;
                              var player__unlocks : StringList&;
                              var player__dailyStatsReward : Object&;
                              var player__dailyStatsRewardInfo : Object&)
  if player__loadoutRecieved
    return
  player__loadoutRecieved = true

  // Load unsigned data
  using() <| $(var jwtDecodedDocument : JsonDocument)
    jwtDecodedDocument |> Parse(evt.unsignedToken)
    if jwtDecodedDocument.HasParseError
      print("[Apply Initial Items] Parsing unsigned token error: <{jwtDecodedDocument.GetParseError}>")
      return

    // Load other
    jwtDecodedDocument |> FindMember("teamInfo", JsonType.kObjectType) <| $(teamInfo : JsonValue)
      var ribbonColorsArray : array<int>
      teamInfo |> FindMember("team_color_idxs", JsonType.kArrayType) <| $(team_color_idxs : JsonValue)
        team_color_idxs |> GetArray() <| $(teamColorIdxsArray : JsonConstArray)
          for teamColor in teamColorIdxsArray
            ribbonColorsArray |> push(teamColor |> json_value_or(-1))
      if length(ribbonColorsArray) > 1
        player_ribbons__curColors = int2(ribbonColorsArray[0], ribbonColorsArray[1])

    if !is_true_net_server()
      jwtDecodedDocument |> FindMember("raidInfo", JsonType.kObjectType) <| $(raidInfo : JsonValue)
        raidInfo |> FindMember("extraParams", JsonType.kObjectType) <| $(extra_params : JsonValue)
          query() <| $ [es] (var level__raidName : das_string&)
            level__raidName := extra_params |> json_get_or("raidName", "")
            print("[Offline Raid] Level raid name is <{level__raidName}>")

  print("[Apply Initial Items] Loading unsigned data for <{userid}> successed.")

  // Load signed data
  var successLoading = false

  using() <| $(var jwtDecodedDocument : JsonDocument)
    let jwtDecoded = decode_jwt(evt.signedToken, PROFILE_LOADOUT_PUBLIC_KEY, jwtDecodedDocument)
    if jwtDecoded != DecodeJwtResult.OK
      if is_dev_circuit() // may be we used raw info instead token
        print("[Apply Initial Items] [DEV] Failed decoding JWT for <{userid}>. Trying fallback to raw data...")
        jwtDecodedDocument |> Parse(evt.signedToken)
        if jwtDecodedDocument.HasParseError
          print("[Apply Initial Items] Parsing signed token error: <{jwtDecodedDocument.GetParseError}>")
          return
      else
        print("[Apply Initial Items] Failed decoding JWT for <{userid}>: <{evt.signedToken}>")
        return

    // Check session and userid
    let userId = jwtDecodedDocument |> json_get_or("userId", 0ul)
    if !is_dev_circuit() && userId != userid
      error("[Apply Initial Items] Fail load items for <{userid}>, expected <{userId}>")
      return
    let sessionIdStr = jwtDecodedDocument |> json_get_or("sessionId", "0")
    let sessionId = to_uint64(sessionIdStr)
    if !is_dev_circuit() && is_true_net_server() && sessionId != get_session_id()
      print("[Apply Initial Items] Fail load items for <{userid}>, sessionId: <{sessionIdStr}>, expected <{get_session_id()}>")
      return

    // Load contracts
    let raidName = jwtDecodedDocument |> json_get_or("raidName", "")
    find_query() <| $ [es] (level__raidName : string)
      if !is_dev_circuit() && (empty(raidName) || level__raidName != raidName)
        print("[Raid Profile] Contracts require raidName <{raidName}>, but have level raidName <{level__raidName}>")
        return true
      jwtDecodedDocument |> FindMember("contracts", JsonType.kArrayType) <| $(contracts : JsonValue)
        contracts |> GetArray() <| $(contractsArray : JsonConstArray)
          var blockingExtraction = false
          for contract in contractsArray
            make_objective_entity(contract, player_eid)
            blockingExtraction ||= contract |> json_get_or("blockExtractionWhenIncomplete", false)
          make_extraction_objective_entity(player_eid, !blockingExtraction)
      return true

    // Load items
    let rentedEquipmentSeedStr = jwtDecodedDocument |> json_get_or("rentedEquipmentSeed", "")
    player__isRentedEquipment ||= !empty(rentedEquipmentSeedStr)
    if player__isRentedEquipment
      let rentedEquipmentSeed = to_uint64(rentedEquipmentSeedStr)
      var seed = int(rentedEquipmentSeed) + int(ecs_hash(raidName))
      let initialHeroItemsBlk = $ <| (equipment : Array)
        initialHeroItems := equipment
        print("[Apply Initial Items] [RentedEquipment] userid <{userid}> prepare for loading <{length(initialHeroItems)}> items with seed <{seed}>")
      let generatorName = "ordinary_equipment_generator"
      print("[Apply Initial Items] [RentedEquipment] userid <{userid}> generate_loadout from {generatorName} with seed <{seed}>")
      generate_loadout(
        generatorName,
        1.0 /*corrupt_chance*/,
        DEFAULT_BASE_VOLUME,
        true /*is_fill_inventories*/,
        seed,
        initialHeroItemsBlk)
    else
      jwtDecodedDocument |> FindMember("loadoutItems", JsonType.kArrayType) <| $(loadoutItems : JsonValue)
        loadoutItems |> GetArray() <| $(loadoutItemsArray : JsonConstArray)
          for loadoutItem in loadoutItemsArray
            if !parse_item_from_jwt(loadoutItem, initialHeroItems)
              return
      if length(initialHeroItems) > 0
        print("[Apply Initial Items] userid <{userid}> prepare for loading <{length(initialHeroItems)}> items.")
      else
        print("[Apply Initial Items] userid <{userid}> passed 0 items.")
        return
      if !ensure_items_has_suit(initialHeroItems)
        print("[Apply Initial Items] There is no suit in <{userid}> items! Can't create hero!")
        return

    // Load unlocks
    jwtDecodedDocument |> FindMember("unlocks", JsonType.kArrayType) <| $(unlocksJson : JsonValue)
      unlocksJson |> GetArray() <| $(unlocksJsonArray : JsonConstArray)
        for unlock in unlocksJsonArray
          let unlockName = unlock |> json_value_or("")
          if !empty(unlockName)
            player__unlocks |> push(unlockName)

    // Load daily rewards
    jwtDecodedDocument |> FindMember("dailyStatsReward", JsonType.kArrayType) <| $(dailyStatsRewardJson : JsonValue)
      dailyStatsRewardJson |> GetArray() <| $(dailyStatsRewardJsonArray : JsonConstArray)
        for entity in dailyStatsRewardJsonArray
          let statName = entity |> json_get_or("name", "")
          if !empty(statName)
            let statValue = entity |> json_get_or("value", 0.0)
            player__dailyStatsReward |> set(statName, statValue)
    jwtDecodedDocument |> FindMember("dailyStatsRewardInfo", JsonType.kArrayType) <| $(dailyStatsRewardInfoJson : JsonValue)
      dailyStatsRewardInfoJson |> GetArray() <| $(dailyStatsRewardInfoJsonArray : JsonConstArray)
        for entity in dailyStatsRewardInfoJsonArray
          let count = entity |> json_get_or("count", "")
          if !empty(count)
            let reward = entity |> json_get_or("reward", 0)
            player__dailyStatsRewardInfo |> set(count, reward)

    successLoading = true

  if !successLoading
    print("[Apply Initial Items] Loading signed loadout for <{userid}> failed, disconnecting.")
    var conn = get_client_connection(connid)
    if conn != null
      clientNetFlags |= int(ClientNetFlags.CNF_RECONNECT_FORBIDDEN)
      net_disconnect(*conn, DisconnectionCause.DC_KICK_ANTICHEAT)
      return
  print("[Apply Initial Items] Loading signed data for <{userid}> successed.")
