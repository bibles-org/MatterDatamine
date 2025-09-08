module loc_snapshots_common shared
require ecs
require BitStream
require DngNet
require DagorSystem
require debug.logerr_once


struct SnapshotEntityData
  eid : EntityId
  pos : float3
  orientation : float4
  blink : bool
  rangeIdx : uint

def serialize_snapshots(cur_time : float; snapshots : array<SnapshotEntityData>; send_event_block : block<(var bs : BitStream)>)
  let batchSize = 32
  let batchCount = (length(snapshots) + batchSize - 1) / batchSize
  for i in range(batchCount)
    using() <| $(var bs : BitStream)
      var j = i * batchSize
      let to = min((i + 1) * batchSize, length(snapshots))
      bs |> ResetWritePointer()
      bs |> Write(cur_time)
      bs |> Write(uint8(to - j))
      while j < to
        bs |> Write(snapshots[j].eid)
        quantize_and_write_to_bitstream(snapshots[j].pos, snapshots[j].orientation, true, bs)
        if snapshots[j].rangeIdx >= 128u
          logerr("<{snapshots[j].eid}>({getEntityTemplateName(snapshots[j].eid)}) snapshot has invalid rangeIdx: {snapshots[j].rangeIdx}")
          return
        let codedinterval = uint8(snapshots[j].rangeIdx + (snapshots[j].blink ? 128u : 0u))
        bs |> Write(codedinterval)
        j++
      send_event_block |> invoke(bs)


def read_and_add_snapshots(bs : BitStream; interval_base : float; intervals_by_distance : IntList const? = null)
  var affectedEntities : array<EntityId>
  var isOk = true
  var atTime : float
  var num : uint8
  isOk &&= bs |> Read(atTime)
  isOk &&= bs |> Read(num)
  if !isOk
    logerr_once("Failed to read snapshot time and num: {atTime} {num}")
    return <- affectedEntities

  for _ in range(int(num))
    using() <| $(var snap : LocSnapshot#)
      var eid : EntityId
      isOk &&= bs |> Read(eid)
      snap.atTime = atTime
      var inMotion : bool
      deserialize_snapshot_quantized_info(snap.pos, snap.quat, inMotion, bs)
      var codedInterval8 : uint8
      isOk &&= bs |> Read(codedInterval8)
      let codedInterval = int(codedInterval8)
      snap.blink = codedInterval >= 128
      let intervalCount = int(codedInterval >= 128 ? codedInterval - 128 : codedInterval)
      if !isOk
        logerr_once("<{eid}>({getEntityTemplateName(eid)}) snapshot stream reading completed with errors. Pos: {snap.pos} Quat: {snap.quat} inMotion: {inMotion} atTime: {atTime}")
        return
      query(eid) <| $ [es] (var loc_snapshots__snapshotData : LocSnapshotsList; loc_snapshots__addPeriod : int = 0)
        if length(loc_snapshots__snapshotData) > 0 && loc_snapshots__snapshotData[length(loc_snapshots__snapshotData) - 1].atTime > snap.atTime
          return // we have a newer snapshot already, this one arrived out-of order
        if intervals_by_distance != null
          let rateIdx = min(intervalCount, length(*intervals_by_distance) - 1)
          snap.interval = float((*intervals_by_distance)[rateIdx] + loc_snapshots__addPeriod) * interval_base
        loc_snapshots__snapshotData |> push(clone_to_move(snap))
        affectedEntities |> push(eid)
  return <- affectedEntities