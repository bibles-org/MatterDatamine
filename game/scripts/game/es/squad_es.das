require ecs
require DagorDataBlock
require BehNodes

[es(tag=server, on_appear)]
def squad_mate_init_beh_tree(evt : Event; transform : float3x4; beh_tree__enabled : bool;
                             var beh_tree : BehaviourTree&;
                             beh_tree__blackboard__wishPositionSet : bool = false)
  let wishPositionName = "wishPosition"
  var wishPositionParam = datablock_find_param(beh_tree.blackBoard, wishPositionName)
  if wishPositionParam == -1
    wishPositionParam = add(beh_tree.blackBoard, wishPositionName, transform[3])
  if beh_tree__enabled && !beh_tree__blackboard__wishPositionSet
    set(beh_tree.blackBoard, wishPositionParam, transform[3])
