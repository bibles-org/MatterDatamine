require ecs


[es(tag=server, no_order)]
def attract_region_stay_timer_update(evt : UpdateStageInfoAct;
                                     var am_bot__attractRegionStayTimer : float&)
  if am_bot__attractRegionStayTimer > 0.f
    am_bot__attractRegionStayTimer -= evt.dt