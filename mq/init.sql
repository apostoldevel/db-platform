--------------------------------------------------------------------------------
-- Initialization --------------------------------------------------------------
--------------------------------------------------------------------------------

-- The group takes a GENERATED identifier rather than the next number in the
-- 00000000-0000-4000-a000-* range. That range is shared by the platform and by
-- every project built on it, with nothing dividing the two: ...006 is already a
-- group of a project's own in more than one installation, and a platform group
-- claiming it would collide on install. Code that needs this group asks for it
-- by code -- GetGroup('mq') -- not by a literal.

SELECT AddMemberToGroup(GetUser('apibot'), CreateGroup('mq', 'Обмен сообщениями', 'Группа для пользователей и служб, которым разрешён обмен сообщениями между узлами'));

-- The local node. Named after the database and given the hub role, because a
-- single installation is a hub until a deployment says otherwise; an edge node
-- is renamed and re-roled when it is set up, and that is a one-line change
-- through mq.edit_peer.

SELECT mq.create_peer(current_database(), current_database(), 'hub', true);

-- API
SELECT RegisterRoute('mq', AddEndpoint('SELECT * FROM rest.mq($1, $2);'));
