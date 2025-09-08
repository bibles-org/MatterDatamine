require ecs
require app
require strings
require ecs.safe
require DagorMath
require DngCamera
require DagorTime
require DagorFiles
require DagorSystem


[es(tag=gameClient, on_event=EventLevelLoaded)]
def benchmark_prepare(evt : Event;
                      benchmark__cameraTracks : Array;
                      benchmark__currentTrack : int;
                      var benchmark__runsCount : int&;
                      var benchmark__name : das_string;
                      var benchmark__trackTimeLeft : float&)
  // override by console args
  let bName = dgs_get_argv("benchmark_name")
  if !empty(bName)
    benchmark__name := bName
  try
    let bRuns = dgs_get_argv("benchmark_passes")
    if !empty(bRuns)
      benchmark__runsCount = int(bRuns)
  recover
    logerr("Failed to parse benchmark_passes argument")
    exit_game("Benchmark completed")

  if benchmark__runsCount == 0 || length(benchmark__cameraTracks) == 0
    exit_game("Benchmark completed")

  benchmark__trackTimeLeft = (benchmark__cameraTracks[benchmark__currentTrack] as Object)?.duration ?? 10.0
  createEntity("benchmark_camera")


[es(tag=gameClient, on_appear, REQUIRE=benchmark__overrideExistCamera)]
def benchmark_prepare_camera(evt : Event; eid : EntityId)
  set_scene_camera_entity(eid)

  query() <| $ [es] (var benchmark__active : bool&; var benchmark__firstMsec : int&)
    benchmark__active = true
    benchmark__firstMsec = get_time_msec()


//wont correctly work with fixed timestamp, but it is strange to benchmark it
[es(tag=gameClient, no_order)]
def benchmark_update(act : UpdateStageInfoAct;
                     benchmark__active : bool;
                     var benchmark__averageDt : float&;
                     var benchmark__prevMsec : int&;
                     var benchmark__frames, benchmark__slowFrames, benchmark__verySlowFrames : int&;
                     var benchmark__maxMemoryUsedKb, benchmark__maxDeviceVRamUsedKb, benchmark__maxSharedVRamUsedKb : int&;
                     var benchmark__allMemoryUsedKb, benchmark__allDeviceVRamUsedKb, benchmark__allSharedVRamUsedKb : int64&)
  if !benchmark__active
    return

  let msec = get_time_msec()
  let dt = float(msec - benchmark__prevMsec) * 0.001
  benchmark__frames = benchmark__frames + 1
  benchmark__averageDt = benchmark__averageDt == 0.0 ? dt : dt * 0.1 + benchmark__averageDt * 0.9

  if dt > benchmark__averageDt * 2.5 && benchmark__frames > 50
    benchmark__slowFrames = benchmark__slowFrames + 1
  if dt > benchmark__averageDt * 5.0
    benchmark__verySlowFrames = benchmark__verySlowFrames + 1
  benchmark__prevMsec = msec

  // allocated system ram
  let memoryUsedKb = get_memory_allocated_kb(true)
  if benchmark__maxMemoryUsedKb < memoryUsedKb
    benchmark__maxMemoryUsedKb = memoryUsedKb
  benchmark__allMemoryUsedKb = benchmark__allMemoryUsedKb + int64(memoryUsedKb)

  // device local/dedicated vram
  let deviceVramUsedKb = get_device_vram_used_kb()
  if benchmark__maxDeviceVRamUsedKb < deviceVramUsedKb
    benchmark__maxDeviceVRamUsedKb = deviceVramUsedKb
  benchmark__allDeviceVRamUsedKb = benchmark__allDeviceVRamUsedKb + int64(deviceVramUsedKb)

  // shared vram
  let sharedVramUsedKb = get_shared_vram_used_kb()
  if benchmark__maxSharedVRamUsedKb < sharedVramUsedKb
    benchmark__maxSharedVRamUsedKb = sharedVramUsedKb
  benchmark__allSharedVRamUsedKb = benchmark__allSharedVRamUsedKb + int64(sharedVramUsedKb)


[es(tag=gameClient, before=benchmark_iteration, REQUIRE=benchmark__overrideExistCamera)]
def benchmark_camera_update(act : UpdateStageInfoAct; var transform : float3x4&)
  query() <| $ [es] (benchmark__cameraTracks : Array;
                     benchmark__active : bool;
                     benchmark__currentTrack : int;
                     benchmark__trackTimeLeft : float)
    if !benchmark__active
      return

    let fullTrackTime = (benchmark__cameraTracks[benchmark__currentTrack] as Object)?.duration ?? 10.0
    let a = 1.0 - max(0.0, benchmark__trackTimeLeft) / fullTrackTime

    let fromDir = (benchmark__cameraTracks[benchmark__currentTrack] as Object)?.from_dir ?? float3(1.0, 0.0, 0.0)
    let toDir = (benchmark__cameraTracks[benchmark__currentTrack] as Object)?.to_dir ?? float3(1.0, 0.0, 0.0)
    let fromQ = dir_to_quat(fromDir)
    let toQ = dir_to_quat(toDir)
    let q = slerp(fromQ, toQ, a)

    let fromPos = (benchmark__cameraTracks[benchmark__currentTrack] as Object)?.from_pos ?? float3(0)
    let toPos = (benchmark__cameraTracks[benchmark__currentTrack] as Object)?.to_pos ?? float3(0)
    let pos = lerp(fromPos, toPos, a)

    make_tm(q, pos, transform)
    // camera forward is not x axis as for all other transforms
    swap(transform[2], transform[0])
    transform[0] *= -1.0


def add_string_to_log(output_file; data : string)
  output_file |> df_puts(data)
  output_file |> df_puts("\n")
  print(data)


// this result file writing works only on win32/64 !
[es(tag=gameClient, no_order)]
def benchmark_iteration(act : UpdateStageInfoAct;
                        benchmark__runsCount : int;
                        benchmark__name : string;
                        benchmark__cameraTracks : Array;
                        benchmark__active : bool;
                        var benchmark__averageDt : float&;
                        var benchmark__prevMsec : int&;
                        var benchmark__firstMsec : int&;
                        var benchmark__frames : int&;
                        var benchmark__slowFrames : int&;
                        var benchmark__verySlowFrames : int&;
                        var benchmark__maxMemoryUsedKb : int&;
                        var benchmark__allMemoryUsedKb : int64&;
                        var benchmark__maxDeviceVRamUsedKb : int&;
                        var benchmark__allDeviceVRamUsedKb : int64&;
                        var benchmark__maxSharedVRamUsedKb : int&;
                        var benchmark__allSharedVRamUsedKb : int64&;
                        var benchmark__currentTrack : int&;
                        var benchmark__trackTimeLeft : float&;
                        var benchmark__currentRun : int&)
  if !benchmark__active
    return

  benchmark__trackTimeLeft -= act.dt
  if benchmark__trackTimeLeft > 0.0
    return

  if ++benchmark__currentTrack < length(benchmark__cameraTracks)
    benchmark__trackTimeLeft = (benchmark__cameraTracks[benchmark__currentTrack] as Object)?.duration ?? 10.0
    return

  print("Benchmark stats:")
  df_open("benchmark.{benchmark__name}.{benchmark__currentRun + 1}.txt", DF_WRITE) <| $(outputFile)
    let totalFrames = max(benchmark__frames, 1)
    let avgMemoryUsedKb = benchmark__allMemoryUsedKb / int64(totalFrames)
    let avgDeviceVRamUsedKb = benchmark__allDeviceVRamUsedKb / int64(totalFrames)
    let avgSharedVRamUsedKb = benchmark__allSharedVRamUsedKb / int64(totalFrames)
    let msecSpent = max(benchmark__prevMsec - benchmark__firstMsec, 1)

    outputFile |> add_string_to_log("avg_fps={1000.0 * float(totalFrames) / float(msecSpent)}")
    outputFile |> add_string_to_log("score={totalFrames}")
    outputFile |> add_string_to_log("slow_frames_pct={100.0 * float(benchmark__slowFrames) / float(totalFrames)}")
    outputFile |> add_string_to_log("very_slow_frames_pct={100.0 * float(benchmark__verySlowFrames) / float(totalFrames)}")
    outputFile |> add_string_to_log("max_memory_used_in_kb={benchmark__maxMemoryUsedKb}")
    outputFile |> add_string_to_log("avg_memory_used_in_kb={avgMemoryUsedKb}")
    outputFile |> add_string_to_log("max_device_vram_used_in_kb={benchmark__maxDeviceVRamUsedKb}")
    outputFile |> add_string_to_log("avg_device_vram_in_kb={avgDeviceVRamUsedKb}")
    outputFile |> add_string_to_log("max_shared_vram_used_in_kb={benchmark__maxSharedVRamUsedKb}")
    outputFile |> add_string_to_log("avg_shared_vram_in_kb={avgSharedVRamUsedKb}")
    outputFile |> add_string_to_log("RawStats: frames={benchmark__frames}, slowFrames={benchmark__slowFrames}, verySlowFrames={benchmark__verySlowFrames}, timeTakenMs={msecSpent}, timeStartedMs={benchmark__firstMsec}, timeEndMs={benchmark__prevMsec}")

  if ++benchmark__currentRun >= benchmark__runsCount
    exit_game("Benchmark completed")
  else
    benchmark__currentTrack = 0
    benchmark__trackTimeLeft = (benchmark__cameraTracks[benchmark__currentTrack] as Object)?.duration ?? 10.0
    benchmark__averageDt = 0.0
    benchmark__prevMsec = 0
    benchmark__firstMsec = get_time_msec()
    benchmark__frames = 0
    benchmark__slowFrames = 0
    benchmark__verySlowFrames = 0
    benchmark__maxMemoryUsedKb = 0
    benchmark__allMemoryUsedKb = int64(0)
    benchmark__maxDeviceVRamUsedKb = 0
    benchmark__allDeviceVRamUsedKb = int64(0)
    benchmark__maxSharedVRamUsedKb = 0
    benchmark__allSharedVRamUsedKb = int64(0)
