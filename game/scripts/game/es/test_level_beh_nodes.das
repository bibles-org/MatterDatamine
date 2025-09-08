options always_export_initializer = true

require ecs
require BehNodes
require DagorDataBlock
require math.random
require pathfinder


[beh_node(name="choosePositionAroundEntityRespectingRotation")]
class ChoosePositionAroundEntityRespectingRotation : BehNodeAdapter
  toParam : int = -1
  fromParam : int = -1
  radiusMinMax : float2

  def override loadFromBlk(var data : DataBlock)
    toParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "to", ""), float3(0.0))
    fromParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "from", ""), int(uint(INVALID_ENTITY_ID)))
    radiusMinMax = datablock_getPoint2(data, "radiusMinMax", float2(4.2, 5.2))

  def override update(dt : float) : EBehResult
    let eid = EntityId(uint(owner.blackBoard |> datablock_getInt(fromParam)))
    query(eid) <| $ [es] (transform : float3x4)
      let rad = rnd_float(radiusMinMax)
      let dir = rnd_dir2() * rad
      let offset = float3(dir.x, 0.0, dir.y)

      let position = transform * offset
      owner.blackBoard |> set(toParam, position)
    return EBehResult.ER_SUCCESS
