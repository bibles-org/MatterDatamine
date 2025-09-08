require app
require ecs
require DngNet
require strings
require rapidjson
require DagorSystem
require DagorDataBlock


[es(on_event=EventOnGameAppStarted)]
def on_gameapp_started_es(evt : Event)
  let isDisableMenu = dgs_get_settings() |> datablock_getBool("disableMenu", false)
  let settingScene = dgs_get_settings() |> datablock_getStr("scene", "")

  if !is_dedicated()
    var connects : array<string>
    dgs_get_argv_all("connect") <| $(connect)
      connects |> push(connect)
      return false
    if !empty(connects)
      connect_to_session(connects)
      return

  if is_dedicated() || isDisableMenu || !empty(dgs_get_argv("devMode"))
    get_matching_invite_data() |> json_stringify() <| $(str)
      print("[GAME LOAD] inviteData: {str}")
    var sceneName = dgs_get_argv("scene")
    if empty(sceneName)
      sceneName = settingScene
    var importScenes : array<string>
    get_matching_invite_data() |> FindMember("mode_info", JsonType.kObjectType) <| $(mode_info : JsonValue)
      mode_info |> FindMember("imports", JsonType.kArrayType) <| $(imports : JsonValue)
        imports |> GetArray() <| $(importsArray : JsonConstArray)
          for import in importsArray
            let importName = import |> json_value_or("")
            if !empty(importName)
              importScenes |> push(importName)
    if empty(importScenes)
      dgs_get_argv_all("importScene") <| $(importScene)
        importScenes |> push(importScene)
        return false

    print("[GAME LOAD] starting with scene = {sceneName}, importScenes = {importScenes}")
    switch_scene(sceneName, importScenes)
  else
    print("[GAME LOAD] starting with scene = gamedata/scenes/login.blk")
    switch_scene("gamedata/scenes/login.blk") // launch from enlist
