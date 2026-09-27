-- Backend step 1: filter metadata for Explore.

create or replace function public.scholarship_filter_options()
returns jsonb
language sql
stable
security invoker
set search_path = public
as $$
  with eligible as (
    select *
    from public.scholarships
    where status = 'published'
      and coalesce(verification_status, 'verified') <> 'needs_review'
      and coalesce(link_status, 'unchecked') not in ('dead', 'generic')
  )
  select jsonb_build_object(
    'countries', coalesce((
      select jsonb_agg(value order by value)
      from (
        select distinct country as value
        from eligible
        where nullif(btrim(country), '') is not null
      ) x
    ), '[]'::jsonb),
    'degrees', coalesce((
      select jsonb_agg(value order by value)
      from (
        select distinct unnest(degree_levels) as value
        from eligible
      ) x
      where nullif(btrim(value), '') is not null
    ), '[]'::jsonb),
    'fields', coalesce((
      select jsonb_agg(value order by value)
      from (
        select distinct unnest(fields) as value
        from eligible
      ) x
      where nullif(btrim(value), '') is not null
    ), '[]'::jsonb),
    'funding', coalesce((
      select jsonb_agg(value order by value)
      from (
        select distinct funding_type as value
        from eligible
        where nullif(btrim(funding_type), '') is not null
      ) x
    ), '[]'::jsonb)
  );
$$;
