require ecs
require game.events.events
require DngHuman
require DagorSystem


[es(track=human_net_phys__canSprint)]
def toggle_sprint_es(evt : Event;
                     var human_net_phys : HumanActor;
                     human_net_phys__canSprint : bool)
  human_net_phys.phys.canSprint = human_net_phys__canSprint


[es(track=human_net_phys__canJump)]
def toggle_jump_es(evt : Event;
                   var human_net_phys : HumanActor;
                   human_net_phys__canJump : bool)
  human_net_phys.phys.canJump = human_net_phys__canJump


[es(track=human_net_phys__canClimb)]
def toggle_climb_es(evt : Event;
                    var human_net_phys : HumanActor;
                    human_net_phys__canClimb : bool)
  human_net_phys.phys.canClimb = human_net_phys__canClimb


[es(track=human_net_phys__canCrawl)]
def toggle_crawl_es(evt : Event;
                    var human_net_phys : HumanActor;
                    human_net_phys__canCrawl : bool)
  human_net_phys.phys.canCrawl = human_net_phys__canCrawl
