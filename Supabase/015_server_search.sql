-- Backend step 1: server-side scholarship search and pagination.

create extension if not exists pg_trgm with schema extensions;

create index if not exists scholarships_title_trgm_idx
  on public.scholarships using gin (title extensions.gin_trgm_ops);

create index if not exists scholarships_provider_trgm_idx
  on public.scholarships using gin (provider extensions.gin_trgm_ops);

create index if not exists scholarships_degree_levels_gin_idx
  on public.scholarships using gin (degree_levels);

create index if not exists scholarships_fields_gin_idx
  on public.scholarships using gin (fields);

create or replace function public.search_scholarships(
  p_query text default null,
  p_country text default null,
  p_degree text default null,
  p_field text default null,
  p_funding text default null,
  p_source text default null,
  p_sort text default 'Recommended',
  p_offset integer default 0,
  p_limit integer default 24
)
returns table (
  scholarship jsonb,
  total_count bigint,
  is_saved boolean
)
language sql
stable
security invoker
set search_path = public, extensions
as $$
  with filtered as (
    select s.*
    from public.scholarships s
    where s.status = 'published'
      and coalesce(s.verification_status, 'verified') <> 'needs_review'
      and coalesce(s.link_status, 'unchecked') not in ('dead', 'generic')
      and (
        nullif(btrim(p_query), '') is null
        or s.title ilike '%' || btrim(p_query) || '%'
        or s.provider ilike '%' || btrim(p_query) || '%'
        or s.country ilike '%' || btrim(p_query) || '%'
        or exists (
          select 1 from unnest(s.fields) f
          where f ilike '%' || btrim(p_query) || '%'
        )
      )
      and (
        nullif(btrim(p_country), '') is null
        or lower(s.country) = lower(btrim(p_country))
      )
      and (
        nullif(btrim(p_degree), '') is null
        or exists (
          select 1 from unnest(s.degree_levels) d
          where lower(d) = lower(btrim(p_degree))
        )
      )
      and (
        nullif(btrim(p_field), '') is null
        or exists (
          select 1 from unnest(s.fields) f
          where lower(f) = lower(btrim(p_field))
        )
      )
      and (
        nullif(btrim(p_funding), '') is null
        or lower(s.funding_type) = lower(btrim(p_funding))
      )
      and (
        nullif(btrim(p_source), '') is null
        or lower(coalesce(s.verification_status, 'verified')) = lower(btrim(p_source))
      )
  ),
  ordered as (
    select f.*
    from filtered f
    order by
      case when p_sort = 'Deadline' then f.deadline end asc nulls last,
      case when p_sort in ('Recommended', 'Verified first')
        then (coalesce(f.verification_status, 'verified') = 'verified')::integer
      end desc nulls last,
      case when p_sort = 'Recommended'
        then (lower(f.funding_type) like '%fully%')::integer
      end desc nulls last,
      f.title asc
  )
  select
    to_jsonb(o),
    count(*) over (),
    case
      when auth.uid() is null then false
      else exists (
        select 1
        from public.saved_scholarships ss
        where ss.user_id = auth.uid()
          and ss.scholarship_id = o.id
      )
    end
  from ordered o
  offset greatest(coalesce(p_offset, 0), 0)
  limit greatest(1, least(coalesce(p_limit, 24), 100));
$$;

grant execute on function public.search_scholarships(
  text, text, text, text, text, text, text, integer, integer
) to anon, authenticated;
