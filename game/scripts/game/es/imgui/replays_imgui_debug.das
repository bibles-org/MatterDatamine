options persistent_heap
options no_aot
require ecs
require ecs.safe
require app
require imgui
require replay
require strings
require DagorImgui
require DagorConsole
require daslib/safe_addr
require daslib/static_let
require game.events.events_game


[imgui_window(name="AM Replay control", group="Replay")]
def am_replay_control()
  if IsWindowCollapsed()
    return

  static_let <|
    var replayFile = ""
    var isUpdated = false
    var labels : array<tuple<name : string; time : float>>
    var humans : array<tuple<name : string; humanEid : EntityId>>
    var totalTime : float
    var startAt : float
    var playersListOpened = false
    var isUpdatedPlayersList = false
    var shakerOn = false
    var useLocalGravity = true
    var cameraMoveSpd = 1.f
    var cameraFov = 90.f
    var tauForInputMouse = 1.f
    var tauForInputKeybord = 1.f

  find_query() <| $ [es] (replay__timeLabels : Array;
                          replay__totalTime, replay__startAt : float;
                          replay__players : Object;
                          var replay__isUpdatedPlayersList : bool&)
    isUpdatedPlayersList = replay__isUpdatedPlayersList
    if !isUpdatedPlayersList
      replay__isUpdatedPlayersList = true
      humans |> clear()
      for obj in replay__players
        let objVal = obj.value as Object
        if objVal != null
          let heroEid = (*objVal).humanEid ?? INVALID_ENTITY_ID
          let heroName = (*objVal).humanName ?? ""
          if heroEid != INVALID_ENTITY_ID && heroName != ""
            humans |> push((heroName, heroEid))
    if !isUpdated
      isUpdated = true
      find_query() <| $ [es] (replay_input__cameraMoveSpd : float)
        cameraMoveSpd = replay_input__cameraMoveSpd
        return true
      replayFile = replay_get_play_file()
      totalTime = replay__totalTime
      startAt = replay__startAt - replay_get_play_start_time()
      labels |> clear()
      for timeLabelMember in replay__timeLabels
        let timeLabelObj = timeLabelMember as Object
        if timeLabelObj != null
          let labelName = get_string(timeLabelObj, "name", "")
          let labelTime = get_float(timeLabelObj, "time")
          if labelName != "" && labelTime != null
            labels |> emplace((labelName, *labelTime))
    return true

  find_query() <| $ [es] (fovSettings : float;
                          replay__dirTau : float;
                          replay__offsetTau : float;
                          camera__active : bool)
    if camera__active
      cameraFov = fovSettings
      tauForInputMouse = replay__dirTau
      tauForInputKeybord = replay__offsetTau
      return true
    return false

  let size = imgui::GetWindowSize()
  if size.x <= 200f || size.y <= 200f
    imgui::SetWindowSize(float2(200))

  if replay_get_play_file() |> empty()
    imgui::Text("Open replay")
    return
  imgui::Text("Replay: {replayFile}")

  BeginGroup()
  if totalTime > 0.0
    let text = build_string() <| $(var str)
      str |> write("Timeline: ")
      str |> write(fmt(":.2f", get_sync_time() - startAt))
      str |> write(" / ")
      str |> write(fmt(":.2f", totalTime))
    imgui::Text(text)

  query() <| $ [es] (var replay__speed : float&)
    if imgui::Button("x0.25")
      replay__speed = 0.25
    imgui::SameLine()
    if imgui::Button("x0.5")
      replay__speed = 0.5
    imgui::SameLine()
    if imgui::Button("||")
      replay__speed = 0.0
    imgui::SameLine()
    if imgui::Button(">")
      replay__speed = 1.0
    imgui::SameLine()
    if imgui::Button("x2")
      replay__speed = 2.0
    imgui::SameLine()
    if imgui::Button("x4")
      replay__speed = 4.0
    imgui::SameLine()
    if imgui::Button("x8")
      replay__speed = 8.0
    imgui::SameLine()
    if imgui::Button("x16")
      replay__speed = 16.0
  EndGroup()

  imgui::NewLine()
  imgui::Separator()
  imgui::Text("Camera section:")

  BeginGroup()
  var index = -1
  if imgui::Button("First-Person")
    index = 0
  imgui::SameLine()
  if imgui::Button("Third-Person")
    index = 1
  imgui::SameLine()
  if imgui::Button("Free Third-Person")
    index = 2
  imgui::SameLine()
  if imgui::Button("Free with offset")
    index = 3
  imgui::SameLine()
  if imgui::Button("Vertigo")
    index = 4

  if index != -1
    query() <| $ [es(REQUIRE=replayIsPlaying)] (replay_cameras_eids : EidList)
      if length(replay_cameras_eids) == 0
        return
      query() <| $ [es(REQUIRE=replayCamera)] (eid : EntityId;
                                               camera__active : bool)
        if camera__active
          sendEvent(eid, ChangeReplayCamera(newCameraEid = replay_cameras_eids[index]))

  if imgui::Button("Toggle Camera Shake")
    query() <| $ [es(REQUIRE=replayIsPlaying)] (replay_cameras_eids : EidList)
      for cameraEid in replay_cameras_eids
        if shakerOn
          removeSubTemplate(cameraEid, "camera_shaker_realistic")
        else
          addSubTemplate(cameraEid, "camera_shaker_realistic")
    shakerOn = !shakerOn
  imgui::SameLine()
  imgui::Text("Current: " + (shakerOn ? "ON" : "OFF"))

  if imgui::Button("Toggle Gravity Affect")
    useLocalGravity = !useLocalGravity
    query() <| $ [es(REQUIRE=replayIsPlaying)] (replay_cameras_eids : EidList)
      for cameraEid in replay_cameras_eids
        query(cameraEid) <| $ [es] (var shooter_camera__forceStabilized : bool&)
          shooter_camera__forceStabilized = !useLocalGravity
  imgui::SameLine()
  imgui::Text("Current: " + (useLocalGravity ? "ON" : "OFF"))

  if imgui::Button("Reset free camera position")
    query() <| $ [es(REQUIRE=replayCamera)] (camera__active : bool;
                                             var shooter_cam__wishAdditionalOffset : float3&;
                                             var replay__ang : float2&;
                                             var fovSettings : float&;
                                             var replay__dirTau : float&;
                                             var replay__offsetTau : float&)
      if camera__active
        shooter_cam__wishAdditionalOffset = float3()
        replay__ang = float2()
        fovSettings = 90.f
        replay__dirTau = 0.8f
        replay__offsetTau = 1f

  var step = 0.1
  var fastStep = 0.5
  if imgui::InputScalar("Offset camera move speed##moveSpd", ImGuiDataType.Float, safe_addr(cameraMoveSpd), safe_addr(step), safe_addr(fastStep), "%.2f", ImGuiInputTextFlags.None)
    find_query() <| $ [es] (var replay_input__cameraMoveSpd : float&)
      replay_input__cameraMoveSpd = cameraMoveSpd
      return true

  step = 2.5f
  fastStep = 10.f
  if imgui::InputScalar("Camera field view##targetFov", ImGuiDataType.Float, safe_addr(cameraFov), safe_addr(step), safe_addr(fastStep), "%.2f", ImGuiInputTextFlags.None)
    cameraFov = clamp(cameraFov, 10.f, 170.f)
    find_query() <| $ [es] (var fovSettings : float&;
                            camera__active : bool)
      if camera__active
        fovSettings = cameraFov
        return true
      return false

  step = 0.01f
  fastStep = 0.05f
  if imgui::InputScalar("Camera mouse tau##targetFov", ImGuiDataType.Float, safe_addr(tauForInputMouse), safe_addr(step), safe_addr(fastStep), "%.2f", ImGuiInputTextFlags.None)
    tauForInputMouse = clamp(tauForInputMouse, 0., 50.)
    find_query() <| $ [es] (var replay__dirTau : float&;
                            camera__active : bool)
      if camera__active
        replay__dirTau = tauForInputMouse
        return true
      return false

  step = 0.01f
  fastStep = 0.05f
  if imgui::InputScalar("Camera movement tau##targetFov", ImGuiDataType.Float, safe_addr(tauForInputKeybord), safe_addr(step), safe_addr(fastStep), "%.2f", ImGuiInputTextFlags.None)
    tauForInputKeybord = clamp(tauForInputKeybord, 0., 50.)
    find_query() <| $ [es] (var replay__offsetTau : float&;
                            camera__active : bool)
      if camera__active
        replay__offsetTau = tauForInputKeybord
        return true
      return false

  EndGroup()

  imgui::NewLine()
  imgui::Separator()
  imgui::Text("Watched player section:")

  BeginGroup()
  var direction = 0
  if imgui::Button("Previous player")
    direction = -1
  imgui::SameLine()
  if imgui::Button("Next player")
    direction = 1
  if direction != 0
    query() <| $ [es(REQUIRE=replayCamera)] (eid : EntityId;
                                             camera__active : bool)
      if camera__active
        sendEvent(eid, FindNextReplayTarget(direction = direction))
  EndGroup()

  if humans |> length() > 0
    playersListOpened = imgui::CollapsingHeader("List of players: {humans |> length()}",
      playersListOpened ? ImGuiTreeNodeFlags.DefaultOpen : ImGuiTreeNodeFlags.None)
    if playersListOpened
      if imgui::BeginTable("List of players", 3, ImGuiTableFlags.Resizable | ImGuiTableFlags.BordersOuter | ImGuiTableFlags.RowBg)
        for person in humans
          imgui::PushID(person.name)
          imgui::TableNextRow()
          imgui::TableSetColumnIndex(0)
          imgui::Text(person.name)
          imgui::TableSetColumnIndex(1)
          imgui::Text("{person.humanEid}")
          imgui::TableSetColumnIndex(2)
          if imgui::Button("Select")
            query() <| $ [es(REQUIRE=replayCamera)] (eid aka cam_eid : EntityId;
                                                     camera__active : bool;
                                                     camera__target : EntityId)
              if camera__active && camera__target != person.humanEid
                sendEvent(cam_eid, SetNextReplayTarget(newTarget = person.humanEid))
          imgui::PopID()
        EndTable()

  imgui::NewLine()
  imgui::Separator()
  imgui::Text("Time Labels section:")

  if labels |> length() > 0
    if imgui::CollapsingHeader("Time Labels: {labels |> length()}")
      if imgui::BeginTable("Time Labels", 3, ImGuiTableFlags.Resizable | ImGuiTableFlags.BordersOuter | ImGuiTableFlags.RowBg)
        for timeLabel in labels
          imgui::PushID(timeLabel.name)
          imgui::TableNextRow()
          imgui::TableSetColumnIndex(0)
          imgui::Text(timeLabel.name)
          imgui::TableSetColumnIndex(1)
          imgui::Text(fmt(":.2f", timeLabel.time))
          imgui::TableSetColumnIndex(2)
          if imgui::Button("Select")
            isUpdated = false
            console_command("replay.play {replayFile} {timeLabel.time}")
          imgui::PopID()
        EndTable()
