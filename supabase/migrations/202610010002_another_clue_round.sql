-- Repeat clue turns without changing the word or roles. Apply after 001.
begin;

alter table public.online_rooms
  add column clue_round integer not null default 1 check (clue_round >= 1);

create function public.online_another_clue_round(p_room uuid, p_expected_round integer)
returns void language plpgsql security definer set search_path = ''
as $$
declare v_room public.online_rooms%rowtype; v_first integer;
begin
  select * into v_room from public.online_rooms where id=p_room for update;
  if not found or auth.uid() is null or v_room.host_id is distinct from auth.uid()
      or not public.online_is_member(p_room) or v_room.expires_at <= now() then
    raise exception 'Only the host can start another clue round';
  end if;
  -- Reject duplicate or stale requests, including retries after a later round.
  if v_room.status <> 'discussion' or v_room.clue_round is distinct from p_expected_round then
    raise exception 'Wait for everyone to finish giving clues';
  end if;
  select min(seat) into v_first from public.online_members where room_id=p_room;
  if v_first is null then raise exception 'Room has no players'; end if;
  update public.online_members set clue=null where room_id=p_room;
  update public.online_rooms
    set status='clues', turn=v_first, clue_round=clue_round+1
    where id=p_room;
end;
$$;

revoke all on function public.online_another_clue_round(uuid,integer) from public,anon;
grant execute on function public.online_another_clue_round(uuid,integer) to authenticated;

commit;
