options no_aot
require ecs
require app
require math.base
require net
require DngNet
require strings
require daslib/strings_boost
require game.es.grav_zones_common
require DagorConsole
require DagorMath
require DagorDebug3D
require DagorSystem
require Dacoll
require game.events.events_active_matter
require game.es.net_console_macro
require game.es.spawn_common
require danetlibs.console_commands.main.console_common


def get_ground_point(pos : float3)
  let down = get_grav_dir(pos)
  var riDesc = RendInstDesc()
  let traceOrigin = pos - down * 10.0
  var traceT = 20.0
  var pmid : int
  var norm : float3
  if !traceray_normalized(traceOrigin, down, traceT, pmid, norm, ETF_DEFAULT, riDesc, -1)
    return pos
  let end = traceOrigin + down * traceT
  return end - down * 2.0


def spawn_bot(eid : EntityId;
              template_name : string;
              dist : float)
  var tm : float3x4
  var tmIsSet = false

  if eid == INVALID_ENTITY_ID
    find_query() <| $ [es] (camera__active : bool; transform : float3x4)
      if camera__active
        tmIsSet = true
        tm = transform
        tm[3] = get_ground_point(tm[3] + tm |> rotate <| float3(0f, 0f, dist))
      return camera__active

  if !tmIsSet
    query(eid) <| $ [es] (transform : float3x4)
      tmIsSet = true
      tm = transform
      tm[3] = get_ground_point(tm[3] + tm[0] * dist + tm[1])

  if !tmIsSet
    tm |> identity()

  createEntity(template_name) <| $(var init : ComponentsInitializer)
    set(init, "transform", tm)


// Spawn sequence
[console_cmd(name="spawn_sequence.test_aura")]
def console_spawn_sequence_test_aura(time : float = 10.0;
                                     fps : bool = true)
  find_query() <| $ [es(REQUIRE=watchedByPlr)] (eid : EntityId)
    createEntity(fps ? "human_extraction_aura_affect_fps" : "human_extraction_aura_affect_tps") <| $(var init : ComponentsInitializer)
      init |> set("game_effect__attachedTo", eid)
      init |> set("game_effect__clientDestroyAt", get_sync_time() + time)
    return true


[console_processor]
def console_spawn_sequence_test_animation(args : array<string>;
                                          collect : bool;
                                          var hints : ConsoleProcessorHints)
  let cmd = "spawn_sequence.test_scale_animation"
  if collect
    let inputs <- args[0] |> split(" ")
    add_hints(fixed_array(CommandArgDesc(name = "eid", hintType = CommandArgHintType.EntityId),
                       CommandArgDesc(name = "time", hintType = CommandArgHintType.Default, defaultValue = "0.0")),
              cmd, inputs, /*hints_count*/ 20, /*threshold_cam_distance_sq*/ square(50.0), hints)
  elif args[0] == cmd
    let argc = args |> length()
    let eid = EntityId(argc >= 2 ? to_uint(args[1]) : 0u)
    let time = argc >= 3 ? to_float(args[2]) : 0.0

    remote_add_sub_template(eid, "militant_spawn_sequence_scale_animation") <| $ [es] (var init : ComponentsInitializer)
      if time > 0.0
        init |> set("militant_spawn_sequence_scale_animation__time", time)

    return true

  return false


[net_console_cmd(name="spawn_sequence.test_bot")]
def console_spawn_sequence_test_bot(dist : float = 10.0;
                                    @net_hero eid : EntityId)
  spawn_bot(eid, "am_militant_with_attachable_suit+spawn_sequence_controller+equipped_bot", dist)


[net_console_cmd(name="spawn_sequence.test_bot_active")]
def console_spawn_sequence_test_bot_active(dist : float = 10.0;
                                           @net_hero eid : EntityId)
  spawn_bot(eid, "am_militant_bot+spawn_sequence_controller+equipped_bot", dist)


[net_console_cmd(name="spawn_sequence.test_hero")]
def console_spawn_sequence_test_hero(@net_hero eid : EntityId)
  let hasController = query(eid) <| $ [es] (var spawn_sequence_controller__state : int&;
                                            var spawn_sequence_controller__sequenceAffect : das_string&)
    if spawn_sequence_controller__state == int(SpawnSequenceControllerState.DONE)
      spawn_sequence_controller__state = int(SpawnSequenceControllerState.INIT)
      spawn_sequence_controller__sequenceAffect := "spawn_sequence_affect" // Hack to replace simple spawn controller

  if !hasController
    addSubTemplate(eid, "spawn_sequence_controller")


[net_console_cmd(name="spawn_sequence.test_fov_animation")]
def console_spawn_sequence_test_fov_animation(@net_hero eid : EntityId)
  createEntity("militant_spawn_sequence_fov_affect") <| $ [es] (var init : ComponentsInitializer)
    init |> set("game_effect__attachedTo", eid)



// Extraction sequence
[net_console_cmd(name="extraction_sequence.test_bot")]
def console_extraction_sequence_test_bot(dist : float = 10.0;
                                         @net_hero eid : EntityId)
  spawn_bot(eid, "am_militant+extraction_sequence_start_on_appear+equipped_bot", dist)

[net_console_cmd(name="extraction_sequence.test_hero")]
def console_extraction_sequence_test_hero(@net_hero eid : EntityId;
                                          test_mode : bool = true)
  createEntity("extraction_sequence_affect") <| $ [es] (var init : ComponentsInitializer)
    init |> set("game_effect__attachedTo", eid)
    init |> set("extraction_sequence_affect__testMode", test_mode)


[net_console_cmd(name="extraction_sequence.test_fov_animation")]
def console_extraction_sequence_test_fov_animation(@net_hero eid : EntityId)
  createEntity("militant_extraction_sequence_fov_affect") <| $ [es] (var init : ComponentsInitializer)
    init |> set("game_effect__attachedTo", eid)