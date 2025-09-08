require ecs
require game.events.events_game
require game.es.action_common
require AnimV20
require DagorSystem
require debug.logerr_once


[es(tag=netClient, REQUIRE=actions)]
def actions_run_es(evt : RunActionCmd; eid : EntityId)
  run_action_by_id(eid, evt.id, evt.overridePropsId, -1, evt.overrideTime,
    evt.overrideAt, evt.actionPeriod)


[es(tag=netClient, REQUIRE=actions)]
def actions_interrupt_es(evt : InterruptActionsCmd; eid : EntityId)
  interrupt_actions(eid)

[es(tag=gameClient, on_appear)]
def actions_resume_anim_graph_node_on_action_init(evt : Event;
                                                  eid : EntityId;
                                                  actions__actions : Array;
                                                  actions__resumeGraphNodeNodeNames : StringList;
                                                  actions__resumeGraphNodeActionNames : StringList;
                                                  var actions__resumeGraphNodeNodeId : IntList;
                                                  var actions__resumeGraphNodeActionId : IntList;
                                                  animchar : AnimcharBaseComponent)
  if length(actions__resumeGraphNodeNodeNames) != length(actions__resumeGraphNodeActionNames)
    logerr("({eid})<{getEntityTemplateName(eid)}: actions__resumeGraphNodeNodeNames and actions__resumeGraphNodeActionNames must have the same length.")

  for nodeName, actionName in actions__resumeGraphNodeNodeNames, actions__resumeGraphNodeActionNames
    let nodeId = *animchar.animGraph |> anim_graph_getBlendNodeId("{nodeName}")
    let actionId = get_action_idx(actions__actions, "{actionName}")
    if nodeId == -1
      logerr("({eid})<{getEntityTemplateName(eid)}: actions__resumeGraphNodeNodeNames: can't find blend node {nodeName} in anim graph from ")
    if actionId == -1
      logerr("({eid})<{getEntityTemplateName(eid)}: actions__resumeGraphNodeActionNames: can't find action {actionName}")

    if actionId >= 0 && nodeId >= 0
      actions__resumeGraphNodeNodeId |> push(nodeId)
      actions__resumeGraphNodeActionId |> push(actionId)

[es(tag=gameClient)]
def actions_resume_anim_graph_node_on_action(evt : EventAction;
                                             eid : EntityId;
                                             actions__resumeGraphNodeNodeId : IntList;
                                             actions__resumeGraphNodeActionId : IntList;
                                             var animchar : AnimcharBaseComponent)
  for action, nodeId in actions__resumeGraphNodeActionId, actions__resumeGraphNodeNodeId
    if action == evt.actionIdx
      var node = *animchar.animGraph |> anim_graph_getBlendNodePtr(nodeId)
      if node == null
        logerr_once("{eid})<{getEntityTemplateName(eid)}: actions_resume_anim_graph_node_on_action: can't find blend node with id {nodeId} in anim graph")
        continue
      *node |> anim_blend_node_resume(*animchar.animState, true)
