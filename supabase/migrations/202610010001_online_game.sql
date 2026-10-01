-- Supabase online rooms and full rounds. Apply after topic_packs migration.
-- All writes pass through authenticated, server-side RPCs; clients can only read
-- public room/member state and their own role through online_my_role.
begin;

create table public.online_rooms (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check (code ~ '^[A-HJ-NP-Z2-9]{6}$'),
  host_id uuid not null,
  topic_id text not null references public.topic_packs(id),
  status text not null default 'lobby'
    check (status in ('lobby','reveal','clues','discussion','voting','guess','result')),
  turn integer,
  result_word text,
  result_chameleon uuid,
  result_winner text check (result_winner in ('group','chameleon')),
  result_reason text,
  vote_counts jsonb,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '6 hours')
);
create table public.online_members (
  room_id uuid not null references public.online_rooms(id) on delete cascade,
  user_id uuid not null,
  seat integer not null check (seat between 0 and 7),
  name text not null check (char_length(name) between 1 and 20 and name = btrim(name)),
  ready boolean not null default false,
  revealed boolean not null default false,
  voted boolean not null default false,
  clue text,
  primary key (room_id, user_id),
  unique (room_id, seat)
);
create table public.online_secrets (
  room_id uuid primary key references public.online_rooms(id) on delete cascade,
  secret_word text not null,
  chameleon_id uuid not null
);
create table public.online_votes (
  room_id uuid not null references public.online_rooms(id) on delete cascade,
  voter_id uuid not null,
  suspect_id uuid not null,
  primary key (room_id, voter_id)
);
create index online_members_user_id_idx on public.online_members(user_id);

alter table public.online_rooms enable row level security;
alter table public.online_members enable row level security;
alter table public.online_secrets enable row level security;
alter table public.online_votes enable row level security;
revoke all on public.online_rooms, public.online_members, public.online_secrets,
  public.online_votes from public, anon, authenticated;
grant select on public.online_rooms, public.online_members to authenticated;

create function public.online_is_member(p_room uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select auth.uid() is not null and exists (
    select 1 from public.online_members
    where room_id = p_room and user_id = auth.uid()
  );
$$;
revoke all on function public.online_is_member(uuid) from public, anon;
grant execute on function public.online_is_member(uuid) to authenticated;

create policy "Members read their room" on public.online_rooms
  for select to authenticated using (public.online_is_member(id) and expires_at > now());
create policy "Members read the player list" on public.online_members
  for select to authenticated using (public.online_is_member(room_id));

create function public.online_create_room(p_name text, p_topic text)
returns uuid language plpgsql security definer set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_code text;
  v_room uuid;
  v_alphabet text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_n integer;
begin
  if v_user is null then raise exception 'Sign in to play online'; end if;
  p_name := btrim(p_name);
  if char_length(p_name) not between 1 and 20 then raise exception 'Enter a name (1–20 characters)'; end if;
  if not exists (select 1 from public.topic_packs where id = p_topic and is_published) then
    raise exception 'Choose a published topic';
  end if;
  for v_n in 1..10 loop
    select string_agg(substr(v_alphabet, floor(random() * length(v_alphabet))::int + 1, 1), '')
      into v_code from generate_series(1,6);
    begin
      insert into public.online_rooms(code, host_id, topic_id)
        values (v_code, v_user, p_topic) returning id into v_room;
      insert into public.online_members(room_id,user_id,seat,name)
        values (v_room,v_user,0,p_name);
      return v_room;
    exception when unique_violation then
      -- A code collision is extremely unlikely, but must never reuse a room.
      null;
    end;
  end loop;
  raise exception 'Could not create a room. Please retry';
end;
$$;

create function public.online_join_room(p_code text, p_name text)
returns uuid language plpgsql security definer set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_room public.online_rooms%rowtype;
  v_seat integer;
begin
  if v_user is null then raise exception 'Sign in to play online'; end if;
  p_name := btrim(p_name);
  if char_length(p_name) not between 1 and 20 then raise exception 'Enter a name (1–20 characters)'; end if;
  select * into v_room from public.online_rooms
    where code = upper(btrim(p_code)) for update;
  if not found or v_room.expires_at <= now() then raise exception 'Room not found or expired'; end if;
  if exists (select 1 from public.online_members where room_id=v_room.id and user_id=v_user) then
    return v_room.id;
  end if;
  if v_room.status <> 'lobby' then raise exception 'This game has already started'; end if;
  if exists (select 1 from public.online_members
    where room_id=v_room.id and lower(name)=lower(p_name)) then
    raise exception 'That name is already taken';
  end if;
  select min(candidate) into v_seat from generate_series(0,7) as candidate
    where not exists (select 1 from public.online_members
      where room_id=v_room.id and seat=candidate);
  if v_seat is null then raise exception 'This room is full'; end if;
  insert into public.online_members(room_id,user_id,seat,name)
    values(v_room.id,v_user,v_seat,p_name);
  return v_room.id;
end;
$$;

create function public.online_set_ready(p_room uuid, p_ready boolean)
returns void language plpgsql security definer set search_path = ''
as $$
begin
  if not exists (select 1 from public.online_rooms where id=p_room and status='lobby' and expires_at>now()) then
    raise exception 'Lobby closed'; end if;
  update public.online_members set ready=p_ready
    where room_id=p_room and user_id=auth.uid();
  if not found then raise exception 'Join this room first'; end if;
end;
$$;

create function public.online_set_topic(p_room uuid, p_topic text)
returns void language plpgsql security definer set search_path = ''
as $$
declare v_room public.online_rooms%rowtype;
begin
  select * into v_room from public.online_rooms where id=p_room for update;
  if v_room.host_id is distinct from auth.uid() or v_room.status <> 'lobby' then
    raise exception 'Only the host can change the lobby topic'; end if;
  if not exists (select 1 from public.topic_packs where id=p_topic and is_published) then
    raise exception 'Choose a published topic'; end if;
  update public.online_rooms set topic_id=p_topic where id=p_room;
  update public.online_members set ready=false where room_id=p_room;
end;
$$;

create function public.online_leave_room(p_room uuid)
returns void language plpgsql security definer set search_path = ''
as $$
declare v_room public.online_rooms%rowtype; v_host uuid;
begin
  select * into v_room from public.online_rooms where id=p_room for update;
  if not found then return; end if;
  if v_room.status <> 'lobby' then raise exception 'Round already started'; end if;
  delete from public.online_members where room_id=p_room and user_id=auth.uid();
  if not found then return; end if;
  select user_id into v_host from public.online_members where room_id=p_room order by seat limit 1;
  if v_host is null then delete from public.online_rooms where id=p_room;
  elsif v_room.host_id=auth.uid() then
    update public.online_rooms set host_id=v_host where id=p_room;
  end if;
end;
$$;

create function public.online_start_round(p_room uuid)
returns void language plpgsql security definer set search_path = ''
as $$
declare v_room public.online_rooms%rowtype; v_words text[]; v_chameleon uuid;
begin
  select * into v_room from public.online_rooms where id=p_room for update;
  if not found or v_room.host_id is distinct from auth.uid() or v_room.status<>'lobby'
      or v_room.expires_at<=now() then raise exception 'Only the host can start this lobby'; end if;
  if (select count(*) from public.online_members where room_id=p_room) not between 3 and 8 or
      exists(select 1 from public.online_members where room_id=p_room and not ready) then
    raise exception 'Wait for 3–8 ready players'; end if;
  select words into v_words from public.topic_packs where id=v_room.topic_id and is_published;
  if v_words is null then raise exception 'Topic unavailable'; end if;
  select user_id into v_chameleon from public.online_members
    where room_id=p_room order by random() limit 1;
  insert into public.online_secrets(room_id,secret_word,chameleon_id)
    values(p_room,v_words[floor(random()*array_length(v_words,1))::int+1],v_chameleon);
  update public.online_rooms set status='reveal',turn=null where id=p_room;
end;
$$;

create function public.online_my_role(p_room uuid)
returns table(is_chameleon boolean, word text)
language plpgsql security definer set search_path = ''
as $$
declare v_secret public.online_secrets%rowtype;
begin
  if not public.online_is_member(p_room) then raise exception 'Join this room first'; end if;
  select * into v_secret from public.online_secrets where room_id=p_room;
  if not found then raise exception 'Round has not started'; end if;
  return query select v_secret.chameleon_id=auth.uid(),
    case when v_secret.chameleon_id=auth.uid() then null::text else v_secret.secret_word end;
end;
$$;

create function public.online_finish_reveal(p_room uuid)
returns void language plpgsql security definer set search_path = ''
as $$
declare v_room public.online_rooms%rowtype;
begin
  select * into v_room from public.online_rooms where id=p_room for update;
  if v_room.status<>'reveal' then raise exception 'Not revealing roles'; end if;
  update public.online_members set revealed=true where room_id=p_room and user_id=auth.uid();
  if not found then raise exception 'Join this room first'; end if;
  if not exists(select 1 from public.online_members where room_id=p_room and not revealed) then
    update public.online_rooms set status='clues',turn=(select min(seat) from public.online_members where room_id=p_room)
      where id=p_room;
  end if;
end;
$$;

create function public.online_submit_clue(p_room uuid, p_clue text)
returns void language plpgsql security definer set search_path = ''
as $$
declare v_room public.online_rooms%rowtype; v_seat integer; v_next integer;
begin
  select * into v_room from public.online_rooms where id=p_room for update;
  if v_room.status<>'clues' then raise exception 'Not accepting clues'; end if;
  if p_clue !~ '^[^[:space:]]{1,40}$' then raise exception 'Enter one word'; end if;
  select seat into v_seat from public.online_members where room_id=p_room and user_id=auth.uid();
  if v_seat is distinct from v_room.turn then raise exception 'Wait for your turn'; end if;
  update public.online_members set clue=p_clue where room_id=p_room and user_id=auth.uid();
  select min(seat) into v_next from public.online_members where room_id=p_room and seat>v_room.turn;
  if v_next is null then update public.online_rooms set status='discussion',turn=null where id=p_room;
  else update public.online_rooms set turn=v_next where id=p_room; end if;
end;
$$;

create function public.online_start_voting(p_room uuid)
returns void language plpgsql security definer set search_path = ''
as $$
declare v_room public.online_rooms%rowtype;
begin
  select * into v_room from public.online_rooms where id=p_room for update;
  if v_room.status<>'discussion' or v_room.host_id is distinct from auth.uid() then
    raise exception 'Only the host can start voting'; end if;
  update public.online_rooms set status='voting' where id=p_room;
end;
$$;

create function public.online_cast_vote(p_room uuid, p_suspect uuid)
returns void language plpgsql security definer set search_path = ''
as $$
declare
  v_room public.online_rooms%rowtype;
  v_secret public.online_secrets%rowtype;
  v_leader uuid;
  v_max integer;
  v_ties integer;
  v_counts jsonb;
begin
  select * into v_room from public.online_rooms where id=p_room for update;
  if v_room.status<>'voting' then raise exception 'Voting is closed'; end if;
  if not exists(select 1 from public.online_members where room_id=p_room and user_id=auth.uid()) then
    raise exception 'Join this room first'; end if;
  if p_suspect=auth.uid() or not exists(select 1 from public.online_members where room_id=p_room and user_id=p_suspect) then
    raise exception 'Vote for another player'; end if;
  insert into public.online_votes(room_id,voter_id,suspect_id) values(p_room,auth.uid(),p_suspect);
  update public.online_members set voted=true where room_id=p_room and user_id=auth.uid();
  if (select count(*) from public.online_votes where room_id=p_room) <
     (select count(*) from public.online_members where room_id=p_room) then return; end if;
  select jsonb_object_agg(m.user_id::text, coalesce(c.total,0)) into v_counts
    from public.online_members m left join (
      select suspect_id,count(*)::integer as total from public.online_votes
      where room_id=p_room group by suspect_id
    ) c on c.suspect_id=m.user_id where m.room_id=p_room;
  select suspect_id, count(*)::integer into v_leader,v_max from public.online_votes
    where room_id=p_room group by suspect_id order by count(*) desc, suspect_id limit 1;
  select count(*) into v_ties from (
    select suspect_id from public.online_votes where room_id=p_room
      group by suspect_id having count(*)=v_max
  ) leaders;
  select * into v_secret from public.online_secrets where room_id=p_room;
  if v_ties>1 then
    update public.online_rooms set status='result',result_word=v_secret.secret_word,
      result_chameleon=v_secret.chameleon_id,result_winner='chameleon',
      result_reason='The vote was tied. The Chameleon slipped away.',vote_counts=v_counts where id=p_room;
  elsif v_leader<>v_secret.chameleon_id then
    update public.online_rooms set status='result',result_word=v_secret.secret_word,
      result_chameleon=v_secret.chameleon_id,result_winner='chameleon',
      result_reason='The group accused the wrong player. The Chameleon escaped.',vote_counts=v_counts where id=p_room;
  else
    update public.online_rooms set status='guess',result_chameleon=v_secret.chameleon_id,
      vote_counts=v_counts where id=p_room;
  end if;
end;
$$;

create function public.online_guess_word(p_room uuid, p_guess text)
returns void language plpgsql security definer set search_path = ''
as $$
declare v_room public.online_rooms%rowtype; v_secret public.online_secrets%rowtype;
begin
  select * into v_room from public.online_rooms where id=p_room for update;
  select * into v_secret from public.online_secrets where room_id=p_room;
  if v_room.status<>'guess' or v_secret.chameleon_id is distinct from auth.uid() then
    raise exception 'Only the Chameleon may guess'; end if;
  if not exists(select 1 from public.topic_packs where id=v_room.topic_id and p_guess=any(words)) then
    raise exception 'Choose a word from the board'; end if;
  update public.online_rooms set status='result',result_word=v_secret.secret_word,
    result_winner=case when p_guess=v_secret.secret_word then 'chameleon' else 'group' end,
    result_reason=case when p_guess=v_secret.secret_word then
      'Caught, but clever! The Chameleon guessed the secret word.' else
      'The Chameleon guessed '||p_guess||'. The group kept its secret.' end
    where id=p_room;
end;
$$;

revoke execute on function public.online_create_room(text,text),public.online_join_room(text,text),
  public.online_set_ready(uuid,boolean),public.online_set_topic(uuid,text),public.online_leave_room(uuid),
  public.online_start_round(uuid),public.online_my_role(uuid),public.online_finish_reveal(uuid),
  public.online_submit_clue(uuid,text),public.online_start_voting(uuid),public.online_cast_vote(uuid,uuid),
  public.online_guess_word(uuid,text) from public,anon;
grant execute on function public.online_create_room(text,text),public.online_join_room(text,text),
  public.online_set_ready(uuid,boolean),public.online_set_topic(uuid,text),public.online_leave_room(uuid),
  public.online_start_round(uuid),public.online_my_role(uuid),public.online_finish_reveal(uuid),
  public.online_submit_clue(uuid,text),public.online_start_voting(uuid),public.online_cast_vote(uuid,uuid),
  public.online_guess_word(uuid,text) to authenticated;

-- Enable changes to room and member state in Supabase Realtime.
alter publication supabase_realtime add table public.online_rooms, public.online_members;
commit;
