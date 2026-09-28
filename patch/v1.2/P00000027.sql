--------------------------------------------------------------------------------
-- P00000027 -------------------------------------------------------------------
--------------------------------------------------------------------------------
-- ERR-400-093 AreaParentCycle: EditArea refuses a parent that is the area
-- itself or one of its descendants (ship-safety T315). A cycle among areas made
-- every walk up the tree run forever.
--
-- init.sql is not re-run on a database in service, so the code is registered
-- here — from the catalogue itself, as P00000025 and P00000026 do. RegisterError
-- is an upsert: the catalogue texts already present are rewritten as they are. The check and the raiser are
-- routines, carried by update.
--
-- Re-runnable.
--------------------------------------------------------------------------------

\ir '../../error/init.sql'
