// Run after installing @electric-sql/pglite in build/ui-sql-check (see docs).
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { PGlite } from '../../build/ui-sql-check/node_modules/@electric-sql/pglite/dist/index.js';

const db = new PGlite();
try {
  await db.exec(`
    create role anon;
    create role authenticated;
    create schema auth;
    create function auth.uid() returns uuid language sql stable as
      $$ select nullif(current_setting('test.uid', true), '')::uuid $$;
    create table public.topic_packs (id text primary key, name text, words text[], is_published boolean);
    insert into public.topic_packs values ('food','Food & drink',array['Pizza','Sushi'],true);
    create publication supabase_realtime;
  `);
  for (const file of ['202610010001_online_game.sql', '202610010002_another_clue_round.sql']) {
    await db.exec(await readFile(new URL(`../migrations/${file}`, import.meta.url), 'utf8'));
  }
  const host = '00000000-0000-0000-0000-000000000001';
  const guest = '00000000-0000-0000-0000-000000000002';
  const third = '00000000-0000-0000-0000-000000000003';
  const outsider = '00000000-0000-0000-0000-000000000004';
  const uid = value => db.query("select set_config('test.uid', $1, false)", [value]);
  await uid(host);
  const room = (await db.query("select public.online_create_room('Host','food') as id")).rows[0].id;
  const code = (await db.query('select code from public.online_rooms where id=$1', [room])).rows[0].code;
  for (const [id, name] of [[guest, 'Guest'], [third, 'Third']]) {
    await uid(id);
    await db.query('select public.online_join_room($1,$2)', [code, name]);
  }
  for (const id of [host, guest, third]) {
    await uid(id);
    await db.query('select public.online_set_ready($1,true)', [room]);
  }
  await uid(host);
  await db.query('select public.online_start_round($1)', [room]);
  const secret = (await db.query('select * from public.online_secrets where room_id=$1', [room])).rows[0];
  const repeat = round => db.query('select public.online_another_clue_round($1,$2)', [room, round]);
  await assert.rejects(repeat(1), /Wait for everyone/);
  for (const id of [host, guest, third]) {
    await uid(id);
    await db.query('select public.online_finish_reveal($1)', [room]);
  }
  for (let round = 1; round <= 3; round++) {
    for (const id of [host, guest, third]) {
      await uid(id);
      await db.query("select public.online_submit_clue($1,'tasty')", [room]);
    }
    const state = (await db.query('select status,clue_round from public.online_rooms where id=$1', [room])).rows[0];
    assert.deepEqual(state, { status: 'discussion', clue_round: round });
    if (round === 3) break;
    for (const id of ['', guest, outsider]) {
      await uid(id);
      await assert.rejects(repeat(round), /Only the host/);
    }
    await uid(host);
    await assert.rejects(repeat(null), /Wait for everyone/);
    if (round > 1) await assert.rejects(repeat(round - 1), /Wait for everyone/);
    await repeat(round);
    await assert.rejects(repeat(round), /Wait for everyone/);
    assert.deepEqual((await db.query('select * from public.online_secrets where room_id=$1', [room])).rows[0], secret);
    assert.equal((await db.query('select count(*)::integer as n from public.online_members where room_id=$1 and clue is not null', [room])).rows[0].n, 0);
    const next = (await db.query('select status,turn from public.online_rooms where id=$1', [room])).rows[0];
    assert.deepEqual(next, { status: 'clues', turn: 0 });
  }
  await uid(host);
  await db.query("update public.online_rooms set expires_at=now()-interval '1 minute' where id=$1", [room]);
  await assert.rejects(repeat(3), /Only the host/);
  await db.query("update public.online_rooms set expires_at=now()+interval '1 hour' where id=$1", [room]);
  await db.query('select public.online_start_voting($1)', [room]);
  await assert.rejects(repeat(3), /Wait for everyone/);
  assert.equal((await db.query("select has_function_privilege('anon','public.online_another_clue_round(uuid,integer)','execute') as allowed")).rows[0].allowed, false);
  assert.equal((await db.query("select has_function_privilege('authenticated','public.online_another_clue_round(uuid,integer)','execute') as allowed")).rows[0].allowed, true);
  console.log('PASS: real SQL transitions, repeated rounds, preserved secrets, cleared clues, host/member/auth checks, expiry, stale requests, voting, and grants.');
} finally {
  await db.close();
}
