options no_aot
require ecs
require ecs.common
require player
require DagorConsole
require DagorSystem
require game.utils.hero
require game.events.events_game
require math.base
require DngCamera
require DagorFiles
require DagorDataBlock


[console_cmd(name="player.enable_tps_camera")]
def player_enable_tps_camera()
  find_query() <| $ [es(REQUIRE=hero)] (var camNames : Array; human_anim__vehicleSelected : EntityId)
    if !has_value(camNames, "dev_tps_cam")
      push(camNames, "dev_tps_cam")
    query(human_anim__vehicleSelected) <| $ [es] (var camNames : Array)
      if !has_value(camNames, "dev_tps_tankcam")
        push(camNames, "dev_tps_tankcam")
    return true

  sendEvent(get_local_player_eid(), CmdSwitchCamera())


[console_cmd(name="camera.blk_tm")]
def copy_camera_itm_cmd()
  find_query() <| $ [es] (eid : EntityId; camera__active : bool; transform : float3x4)
    if camera__active
      let s = "[[{transform[0]}] [{transform[1]}] [{transform[2]}] [{transform[3]}]]"
      console_print("{getEntityTemplateName(eid)} tm: {s}")
      set_clipboard_ansi_text(s)
      return true
    return false


[console_cmd(name="camera.toggle_gravity")]
def console_camera_toggle_gravity()
  let success = find_query() <| $ [es] (camera__active : bool; var free_cam__checkGravity : bool&)
    if camera__active
      free_cam__checkGravity = !free_cam__checkGravity
      return true
    return false
  if !success
    visual_log("Current camera doesn't support gravity")


[console_cmd(name="camera.save")]
def console_camera_save(slot = "slot0")
  var cameraTm = IDENT_TM
  let cameraFound = find_query() <| $ [es] (camera__active : bool; transform : float3x4)
    if camera__active
      cameraTm = transform
      return true
    return false
  if !cameraFound
    console_print("No active cameras found.")
    return

  let filename = "cameraPositions.blk"
  using() <| $(var cameraPositions : DataBlock)
    var fileStat : DagorStat
    if df_stat(filename, fileStat) >= 0
      datablock_load(cameraPositions, filename)
    cameraPositions |> datablock_remove_block(slot)
    datablock_add_block(cameraPositions, slot) <| $(cameraSlot)
      cameraSlot |> add("tm", cameraTm)
    datablock_save_to_text_file(cameraPositions, filename)


[console_cmd(name="camera.restore")]
def console_camera_restore(slot = "slot0")
  var cameraTm = IDENT_TM
  let filename = "cameraPositions.blk"
  using() <| $(var cameraPositions : DataBlock)
    var fileStat : DagorStat
    if df_stat(filename, fileStat) >= 0
      datablock_load(cameraPositions, filename)
      datablock_get_block(cameraPositions, slot) <| $(cameraSlot)
        if datablock_param_exists(cameraSlot, "tm", -1)
          cameraTm = datablock_getTm(cameraSlot, "tm", IDENT_TM)
          set_cam_itm(cameraTm)


[console_cmd(name="camera.fov")]
def console_camera_fov(new_fov = -1.0)
  let cameraFound = find_query() <| $ [es] (camera__active : bool; var fov aka camera_fov : float&)
    if camera__active
      if new_fov > 0.0
        camera_fov = new_fov
        console_print("Camera FOV changed to {camera_fov}.")
      else
        console_print("Camera FOV is {camera_fov}.")
      return true
    return false

  if !cameraFound
    console_print("No active cameras with FOV found.")


[console_cmd(name="camera.dir")]
def console_camera_dir(dir_1 = 2.0; dir_2 = 2.0; dir_3 = 2.0)
  var cameraTm = IDENT_TM
  let cameraFound = find_query() <| $ [es] (camera__active : bool; transform : float3x4)
    if camera__active
      cameraTm = transform
      return true
    return false
  if !cameraFound
    console_print("No active cameras found.")
    return

  var cameraDir = cameraTm[2]
  if dir_1 > 1.0 && dir_2 > 1.0 && dir_3 > 1.0
    console_print("Camera dir {cameraDir.x} {cameraDir.y} {cameraDir.z}")
    set_clipboard_ansi_text("{cameraDir.x}, {cameraDir.y}, {cameraDir.z}")
    return
  elif dir_2 > 1.0 && dir_3 > 1.0
    cameraDir.y = dir_1
  elif dir_3 > 1.0
    cameraDir.x = dir_1
    cameraDir.z = dir_2
  else
    cameraDir.x = dir_1
    cameraDir.y = dir_2
    cameraDir.z = dir_3

  cameraTm[2] = cameraDir
  cameraTm[0] = cross(float3(0.0, 1.0, 0.0), cameraTm[2])
  cameraTm[1] = cross(cameraTm[2], cameraTm[0])
  cameraTm |> orthonormalize()
  set_cam_itm(cameraTm)


[console_cmd(name="camera.set_offset")]
def console_camera_set_offset(offset_x, offset_y, offset_z : float)
  let cameraFound = find_query() <| $ [es] (camera__active : bool; var shooter_cam__offset : float3&)
    if camera__active
      shooter_cam__offset = float3(offset_x, offset_y, offset_z)
      return true
    return false
  if !cameraFound
    console_print("No active cameras with shooter_cam__offset found.")
    return


[console_cmd(name="camera.tm")]
def console_camera_tm()
  let cameraFound = find_query() <| $ [es] (camera__active : bool; transform : float3x4)
    if camera__active
      console_print("Camera tm {transform}")
      set_clipboard_ansi_text("{transform}")
      return true
    return false
  if !cameraFound
    console_print("No active cameras found.")
    return


[console_cmd(name="camera.speed")]
def console_camera_speed(speed = -1.0)
  let cameraFound = find_query() <| $ [es] (camera__active : bool;
                                            free_camera__moveSpeedDefault : float;
                                            var free_camera__moveSpeed : float&;
                                            free_camera__turboSpeedScale = 20.0)
    if camera__active
      if speed < 0.0
        console_print("Default speed: {free_camera__moveSpeedDefault}\nCurrent speed: {free_camera__moveSpeed}\nTurbo scale: {free_camera__turboSpeedScale}")
      else
        free_camera__moveSpeed = speed
      return true
    return false

  if !cameraFound
    console_print("No active free cameras found.")
