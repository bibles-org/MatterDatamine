require ecs
require strings
require rapidjson
require JsonUtils
require game.events.events_active_matter


let
  PERMISSIONS_PUBLIC_KEY = "MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDq1fQVfvjjJaxYIGzYZ/SI89kY+7wTCbMROLlRUHMwWDq/358LzKaFZI+8yOikE2c3Bn/qcvVUHtDGYSLc3GqDRwNlZrWrbasCa6rnb+Qki2o6XLaHylMEPYlOOpY8dvI9DZNtGs4en7B++9usmI7nSkBVmvmpcecs1xe0mKtwlQIDAQAB"


[es(tag=server, REQUIRE=player)]
def dedicated_get_permissions_for_player(evt : CmdSendUserDedicatedPermissions; userid : uint64; var userPermissions : StringList&)
  if userid == 0ul
    return

  using() <| $(var jwtDecodedDocument : JsonDocument)
    let jwtDecoded = decode_jwt(evt.jwt, PERMISSIONS_PUBLIC_KEY, jwtDecodedDocument)
    if jwtDecoded != DecodeJwtResult.OK
      return

    let useridJwt = jwtDecodedDocument |> json_get_or("userid", 0ul)
    if useridJwt == 0ul || userid != useridJwt
      error("[Dedicated Permission] Wrong users: useridJwt <{useridJwt}> userid <{userid}>")
      return

    userPermissions |> clear()
    jwtDecodedDocument |> FindMember("perm", JsonType.kArrayType) <| $(permissions : JsonValue)
      permissions |> GetArray() <| $(permissionsArray : JsonConstArray)
        for permission in permissionsArray
          let permissionName = json_value_or(permission, "")
          if !empty(permissionName)
            userPermissions |> push(permissionName)
