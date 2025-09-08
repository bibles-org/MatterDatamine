require ecs
require ecs.common
require math.base
require DagorMath
require DagorRandom
require DagorSystem
require DagorConsole
require DagorDebug3DSolid
require DagorDebug3D
require Dacoll
require PhysMat
require game.events.events_active_matter

let up = float3(0, 1, 0)

def traceFromTop(coords : float2; base_height, trace_height : float)
  let pos = float3(coords.x, base_height + trace_height, coords.y)
  var t : float = trace_height
  tracedown_normalized(pos, t, ETF_DEFAULT)
  return pos.y - t

def center_xy(x, y : int; size, height : float; start_from : float3)
  return float3((float(x) + 0.5) * size + start_from.x, height, (float(y) + 0.5) * size + start_from.z)

/*i.e. for count == 4
    x_x_x_x
    _x_x_x_
    x_x_x_x
    _x_x_x_
    x_x_x_x
    _x_x_x_
    x_x_x_x
  */
def create_ckeckers_pattern(size : float2; count : int)
  var result : array<float2>
  var seed = 12345
  let randomVariation = 0.1
  let vStep = count > 1 ? size.y / float(count - 1) * 0.5 : .0
  let hStep = count > 1 ? size.x / float(count - 1) : .0
  for i in range(2 * count - 1)
    let subCount = i % 2 == 0 ? count : count - 1
    let offStepH = i % 2 == 0 ? -size.x * 0.5 : 0.5 * hStep - size.x * 0.5
    let offStepV = -size.y * 0.5
    for k in range(subCount)
      //skew pattern a little to avoid streight lines which coincide with vertical map features (like window frames)
      let rndOffset = float2(_rnd_float(seed, -1.0, 1.0) * hStep, _rnd_float(seed, -1.0, 1.0) * vStep) * randomVariation
      result |> push(float2(float(k) * hStep + offStepH, float(i) * vStep + offStepV) + rndOffset)
  return <- result

def get_object_test_tm(contact_point, norm : float3; offset : float; size : float3)
  var tm : float3x4
  tm[0] = norm
  tm[2] = cross(up, norm)
  tm[1] = cross(norm, tm[2])
  tm[0] *= size.x
  tm[1] *= size.y
  tm[2] *= size.z
  tm[3] = contact_point + norm * size.x * 0.5 - norm * offset
  return <- tm

[es(on_appear, tag=dev, REQUIRE_NOT=completeVerticalSurfaceScanner)]
def vertical_surface_scanner_init(evt : Event;
                                  eid : EntityId;
                                  vs_scanner__invalidMats : StringList;
                                  var vs_scanner__invalidMatIds : IntList)
  for mat in vs_scanner__invalidMats
    let matId = get_material_id(string(mat))
    if matId != -1
      vs_scanner__invalidMatIds |> push(matId)
    else
      logerr("{getEntityTemplateName(eid)} has invalid material '{mat}'}")

[es(no_order, tag=dev, REQUIRE_NOT=completeVerticalSurfaceScanner)]
def vertical_surface_scanner_update(act : UpdateStageInfoAct;
                                    eid : EntityId;
                                    var vs_scanner__macroCellIdx : int&;
                                    var vs_scanner__resultPos : Point3List;
                                    var vs_scanner__resultNorm : Point3List;
                                    vs_scanner__invalidMatIds : IntList;
                                    vs_scanner__reportTo : EntityId;
                                    vs_scanner__overallBounds : float4;
                                    vs_scanner__macroCellSize : int = 50;
                                    vs_scanner__objectSize : float3 = float3(5, 7, 7);
                                    vs_scanner__flatSpaceSize : float2 = float2(6, 6);
                                    vs_scanner__flatCkecks : int = 6;
                                    vs_scanner__flatDstTolerance : float = 0.25;
                                    vs_scanner__dotMinAligment : float = 0.9;
                                    vs_scanner__minHeight : float = 11f;
                                    vs_scanner__significantHeight : float = 4f;
                                    vs_scanner__traceDownHeight : float = 50f;
                                    vs_scanner__vtracePerCell : int = 2;
                                    vs_scanner__cellSize : float = 2.0)
  // 1) calc current macro cell and handle termination
  if vs_scanner__significantHeight < 0.5
    logerr("vs_scanner__significantHeight too low")
    removeSubTemplate(eid, "active_vertical_surface_scanner")
    return
  let overallSize = float2(vs_scanner__overallBounds.z - vs_scanner__overallBounds.x,
                           vs_scanner__overallBounds.w - vs_scanner__overallBounds.y)
  let overallCellCount = int2(int(ceil(overallSize.x / vs_scanner__cellSize)),
                              int(ceil(overallSize.y / vs_scanner__cellSize)))
  let marcroCellsCount = int2(ceil(float(overallCellCount.x) / float(vs_scanner__macroCellSize)),
                              ceil(float(overallCellCount.y) / float(vs_scanner__macroCellSize)))


  if vs_scanner__macroCellIdx >= marcroCellsCount.x * marcroCellsCount.y
    sendEvent(vs_scanner__reportTo, EventGenJobComplete(workerEid = eid))
    addSubTemplate(eid, "complete_vertical_surface_scanner") // we're done
    //for r, n in vs_scanner__resultPos, vs_scanner__resultNorm
    //  let tm = get_object_test_tm(r, n, 0.f, vs_scanner__objectSize)
    //  draw_debug_tm_buffered(tm, E3DCOLOR(0x55ffff00), 500)
    console_print("vss scan complete, successes: {length(vs_scanner__resultPos)}")
    return

  let macroX = vs_scanner__macroCellIdx % marcroCellsCount.x
  let macroY = vs_scanner__macroCellIdx / marcroCellsCount.x
  vs_scanner__macroCellIdx++

  // 2) handle one macro cell per frame
  assume cellSize = vs_scanner__cellSize
  //each macroCell will have 1 cell of padding to avoid seams between cells
  let startFrom = vs_scanner__overallBounds.xy + float2(float(macroX * (vs_scanner__macroCellSize - 1)) * cellSize,
                                                        float(macroY * (vs_scanner__macroCellSize - 1)) * cellSize)
  let startFromX0Y = float3(startFrom.x, .0, startFrom.y)

  // 2.1) create height map
  let traceStep = vs_scanner__cellSize / float(vs_scanner__vtracePerCell + 1)
  let totalCellCount = square(vs_scanner__macroCellSize + 2)
  let cellRowNum = vs_scanner__macroCellSize + 2
  var cellHeigh : array<float>
  resize(cellHeigh, totalCellCount)
  var groundHeigh : array<float>
  resize(groundHeigh, totalCellCount)
  for it in range(totalCellCount)
    let x = it % cellRowNum
    let y = it / cellRowNum
    for i in range(vs_scanner__vtracePerCell)
      for j in range(vs_scanner__vtracePerCell)
        let traceCoords = startFrom + float2(float(x) * cellSize + traceStep * float(i + 1),
                                              float(y) * cellSize + traceStep * float(j + 1))
        groundHeigh[it] = max(groundHeigh[it], traceht_lmesh(traceCoords))
        cellHeigh[it] = max(cellHeigh[it], traceFromTop(traceCoords, groundHeigh[it], vs_scanner__traceDownHeight))

  // 2.2) find vertical flat surfaces (excluding padding - padding cells are to be scanned in another macroCell)
  let dirs = fixed_array<float3>(float3(0, 0, -1), float3(-1, 0, 0), float3(0, 0, 1), float3(1, 0, 0))

  let checks : array<float2> <- create_ckeckers_pattern(vs_scanner__flatSpaceSize, vs_scanner__flatCkecks)
  let step = vs_scanner__significantHeight * 0.25

  let collTestBox = BBox3(float3(), length(vs_scanner__objectSize))
  var riDesc = RendInstDesc()
  dacoll_use_box_collision() <| $(var coll : CollisionObject)
    for it in range(totalCellCount)
      let x = it % cellRowNum
      let y = it / cellRowNum
      if x == 0 || y == 0 || x == cellRowNum - 1 || y == cellRowNum - 1
        continue //this is padding
      let northCell = it - cellRowNum
      let westCell = x > 0 ? y * cellRowNum + x - 1 : -1
      let southCell = it + cellRowNum < totalCellCount ? it + cellRowNum : -1
      let eastCell = x + 1 < cellRowNum ? y * cellRowNum + x + 1 : -1
      let neighbours = fixed_array<int>(northCell, westCell, southCell, eastCell)
      for neighbour, dir in neighbours, dirs
        if (neighbour >= 0 &&
            cellHeigh[it] < cellHeigh[neighbour] - vs_scanner__significantHeight &&
            cellHeigh[neighbour] - groundHeigh[neighbour] > vs_scanner__minHeight)
          var offset = -vs_scanner__significantHeight
          while (offset < cellHeigh[neighbour] - cellHeigh[it] - vs_scanner__minHeight &&
                cellHeigh[neighbour] - offset - vs_scanner__minHeight > groundHeigh[neighbour])
            var norm : float3
            var t = cellSize * 2.0
            let traceFrom = center_xy(x, y, cellSize, cellHeigh[neighbour] - offset, startFromX0Y)
            traceray_normalized(traceFrom, dir, t, norm)
            var success = false
            let contactPoint = traceFrom + dir * t
            if t < cellSize * 2.0 && abs(dot(norm, up)) < 1f - vs_scanner__dotMinAligment
              success = true
              let sideDir = cross(up, norm)
              for check in checks
                let subTraceFrom = contactPoint + norm * vs_scanner__objectSize.x + sideDir * check.x + up * check.y
                var subT = vs_scanner__objectSize.x + vs_scanner__flatDstTolerance + 0.2
                var subNorm : float3
                var pmid : int
                let normDir = -norm
                traceray_normalized(subTraceFrom, normDir, subT, pmid, subNorm, ETF_DEFAULT, riDesc, -1)
                if (abs(subT - vs_scanner__objectSize.x) > vs_scanner__flatDstTolerance ||
                    has_value(vs_scanner__invalidMatIds, pmid))
                  success = false
                  break
              if success
                let testTm = get_object_test_tm(contactPoint, norm, vs_scanner__flatDstTolerance, vs_scanner__objectSize)
                dacoll_set_collision_object_tm(coll, testTm)
                success = !test_collision_ri(coll, collTestBox)
            offset += step
            if success
              vs_scanner__resultPos |> push(contactPoint)
              vs_scanner__resultNorm |> push(norm)
