--------------------------------------------------------------------------------
-- gateway.route ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Prefix → module → how many instances are in rotation. What another
 *        application (and GET /gateway/list) reads instead of gateway.node
 *        (track-a-gateway.md §5). Only `ready` counts: suspect, draining,
 *        overloaded and offline are outside rotation by contract К8.
 */
CREATE OR REPLACE VIEW gateway.route
AS
  SELECT p.prefix, n.module,
         count(*) FILTER (WHERE n.state = 'ready')::integer AS instances_ready,
         count(*)::integer                                   AS instances_total
    FROM gateway.node n
   CROSS JOIN LATERAL unnest(n.prefixes) AS p(prefix)
   GROUP BY p.prefix, n.module;

COMMENT ON VIEW gateway.route IS 'Routing table as the gateway sees it: one row per (prefix, module) with the number of ready instances. Zero ready with total > 0 is the 503 no-instance case of contract К7.';

GRANT SELECT ON gateway.route TO daemon, apibot, administrator;
