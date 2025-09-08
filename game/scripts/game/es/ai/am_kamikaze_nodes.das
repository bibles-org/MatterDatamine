options always_export_initializer = true
require ecs
require BehNodes
require DagorSystem
require DagorDataBlock


[beh_node(name="kamikazeExplode")]
class KamikazeExplode : BehNodeAdapter

  def override loadFromBlk(var data : DataBlock)
    let eid = beh_tree_eid(owner)
    if !(query(eid) <| $ [es(REQUIRE=(kamikaze__activatorTemplate))] {})
      logerr("{eid}: <{getEntityTemplateName(eid)}> KamikazeExplode requires kamikaze.activatorTemplate  fields")

  def override update(dt : float) : EBehResult
    let result = EBehResult.ER_SUCCESS
    let eid = beh_tree_eid(owner)
    query(eid) <| $ [es] (transform : float3x4; kamikaze__activatorTemplate : string)
      createEntity(kamikaze__activatorTemplate) <| $(initializer)
        set(initializer, "ownerEid", eid)
        set(initializer, "transform", transform)
    return result