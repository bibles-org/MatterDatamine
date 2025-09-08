require ecs
require net
require DngNet

//Idealu teh node should remove this template.
//But the node might exit before finishing. and exit() might fail too.
[es(tag=server, after=beh_tree_update_es)]
def remove_agent_in_climbing_template(act : UpdateStageInfoAct; eid : EntityId; agent_in_climbing__template : string; agent_in_climbing__removeAt : float)
  if agent_in_climbing__removeAt < act.curTime
    remote_remove_sub_template(eid, agent_in_climbing__template)
