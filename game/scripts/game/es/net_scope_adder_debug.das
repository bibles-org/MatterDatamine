options no_aot
require ecs
require ecs.safe
require game.es.net_console_macro

[net_console_cmd(name="net.replicas_histogram")]
def replicas_histogram()
  get_client_connections() <| $(connections)
    for connId in range(0, length(connections))
      var conn : IConnection? = connections[connId]
      if conn == null
        continue
      var hist : table<string; int>
      var totalScope = 0
      var total = 0
      var totalAlways = 0
      var totalHist : table<string; int>
      var isAlwaysInScope : table<string; bool>
      query() <| $ [es] (eid : EntityId; replication : NetObject)
        let key = getEntityTemplateName(eid)
        total += 1
        totalHist.insert(key, (totalHist?[key] ?? 0) + 1)
        hist.insert(key, hist?[key] ?? 0)
        isAlwaysInScope.insert(key, !has(eid, "net__scopeDistanceSq"))
        if connection_isEntityInScope(*conn, replication.eid)
          hist.insert(key, hist.get_value(key) + 1)
          totalScope += 1
          if isAlwaysInScope.get_value(key)
            totalAlways += 1
      var hist_arr : array<tuple<templ : string; count : int>>
      for key, count in keys(hist), values(hist)
        hist_arr |> emplace((key, count))
      sort(hist_arr) <| $(a, b)
        return b.count < a.count
      let percent = 100f * float(totalScope) / float(total)
      print("For conn #{connId} dump histogram of total {totalScope} entities in scope of {length(hist_arr)} templates from {total} entities ({percent}%) ; always in scope = {totalAlways} ({100f * float(totalAlways) / float(totalScope)}%)")
      for hist_entry in hist_arr
        let templTotal = totalHist[hist_entry.templ]
        let templPercent = 100f * float(hist_entry.count) / float(templTotal)
        print("{hist_entry.count} from {templTotal} ({templPercent}% ; isAlways={isAlwaysInScope.get_value(hist_entry.templ)}) of {hist_entry.templ}")
