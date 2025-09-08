require ecs
require math.base
require DngHuman
require game.events.events
require AnimV20
require Dacoll
require GeomNodeTree
require DagorMath
require PhysMat


[es(on_appear)]
def lean_node_init(evt : Event;
                   animchar : AnimcharBaseComponent;
                   human_lean__rootNodeName : string;
                   human_lean__eyeNodeName : string;
                   human_lean__leanMat : string;
                   var human_lean__headOffset : float3&;
                   var human_lean__rootNodeId : int&;
                   var human_lean__leanMatId : int&)
  human_lean__rootNodeId = geomtree_findNodeIndex(*animchar.nodeTree, human_lean__rootNodeName)
  var rootTm : float3x4
  geomtree_getNodeWtmScalar(*animchar.nodeTree, human_lean__rootNodeId, rootTm)
  human_lean__headOffset = inverse(rootTm) * geomtree_getNodeWpos(*animchar.nodeTree, geomtree_findNodeIndex(*animchar.nodeTree, human_lean__eyeNodeName))
  human_lean__leanMatId = get_material_id(human_lean__leanMat)


def rotate(rotQ : quat; var tm : float3x4&) : float3x4
  tm[0] = rotQ * tm[0]
  tm[1] = rotQ * tm[1]
  tm[2] = rotQ * tm[2]
  return tm


def calc_max_lean(eid : EntityId; direction : float) // 1.0 -> right; -1.0 -> left
  var res = direction
  query(eid) <| $ [es] (human_net_phys : HumanActor;
                        animchar : AnimcharBaseComponent;
                        human_lean__headOffset : float3;
                        human_lean__traceRad : float;
                        human_lean__rootNodeId : int;
                        human_lean__leanMatId : int)
    if human_lean__rootNodeId == -1
      return
    let leanAngle = human_net_phys.phys.leanDegrees * direction
    let curAngle = human_net_phys.phys.currentState.leanPosition
    var rootTm : float3x4
    geomtree_getNodeWtmScalar(*animchar.nodeTree, human_lean__rootNodeId, rootTm)
    var animTm : float3x4
    animchar |> animchar_get_tm(animTm)

    let headQ = quat(animTm[2], deg_to_rad(-curAngle)) // back lean to neutralize head rotation
    rotate(headQ, rootTm) // rotate root but around its position, not 0, 0, 0
    let headPos = rootTm * human_lean__headOffset // head position without lean
    let leanQ = quat(animTm[2], deg_to_rad(leanAngle)) // lean to wish head position
    rotate(leanQ, rootTm)
    let leanPos = rootTm * human_lean__headOffset // wish head position

    var out = ShapeQueryOutput()
    sphere_cast(headPos, leanPos, human_lean__traceRad, out, human_lean__leanMatId) // check collision for the lean
    res = out.t * direction
  return res


[es(REQUIRE_NOT=deadEntity)]
def human_lean_controls(evt : CmdPostPhysUpdate; eid : EntityId;
                        human_net_phys : HumanActor;
                        var human_net_phys__wishLean : float&)
  assume phys = human_net_phys.phys

  if !phys.currentState.isControllable
    human_net_phys__wishLean = 0.
    return

  var ctLean = clamp(phys.appliedCT.leanPosition, -1., 1.)
  if ctLean != 0.f
    ctLean = calc_max_lean(eid, ctLean)
  human_net_phys__wishLean = ctLean * phys.leanDegrees

[es(REQUIRE_NOT=deadEntity, after=human_lean_controls)]
def human_lean_apply(evt : CmdPostPhysUpdate;
                     human_net_phys__leanSpeed : float = 180.0;
                     human_net_phys__wishLean : float;
                     var human_net_phys : HumanActor&)
  assume currentState = human_net_phys.phys.currentState

  currentState.leanPosition = move_to(currentState.leanPosition, human_net_phys__wishLean, evt.dt, human_net_phys__leanSpeed)
