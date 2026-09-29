-- CHM-S1 contract for CHM-2. Apply once in a new Supabase project's SQL Editor.
-- The catalog is public content; app clients must never be allowed to edit it.
begin;

create function public.valid_topic_words(words text[])
returns boolean
language sql immutable
set search_path = ''
as $$
  select coalesce(
    array_ndims(words) = 1 and cardinality(words) = 12
    and (select count(distinct lower(btrim(word))) = 12
         and bool_and(word is not null and word = btrim(word)
                      and char_length(word) between 1 and 40)
         from unnest(words) as word), false);
$$;

create table public.topic_packs (
  id text primary key default gen_random_uuid()::text
    check (char_length(id) between 1 and 100 and id = btrim(id)),
  name text not null check (char_length(name) between 1 and 80 and name = btrim(name)),
  words text[] not null check (public.valid_topic_words(words)),
  is_published boolean not null default false,
  created_at timestamptz not null default now()
);

alter table public.topic_packs enable row level security;
revoke all on public.topic_packs from public, anon, authenticated;
grant select on public.topic_packs to anon, authenticated;
grant all on public.topic_packs to service_role;
create policy "Read published topic packs"
  on public.topic_packs for select to anon, authenticated
  using (is_published = true);

-- The validation helper is not an app API endpoint.
revoke execute on function public.valid_topic_words(text[]) from public, anon, authenticated;
grant execute on function public.valid_topic_words(text[]) to service_role;

commit;
