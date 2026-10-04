-- Put the strongest verified scholarships at the top of Explore.
-- "Verified first" now ranks:
-- 1) verified records before curated records
-- 2) exact official scholarship links before merely reachable links
-- 3) highest reliability score
-- 4) most recently successfully checked

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
  with profile as (
    select p.*
    from public.student_profiles p
    where p.id = auth.uid()
  ),
  behavior_source as (
    select distinct e.scholarship_id
    from public.product_events e
    where e.user_id = auth.uid()
      and e.scholarship_id is not null
      and e.created_at >= now() - interval '180 days'
      and e.event_name in (
        'scholarship_save',
        'official_site_click',
        'application_status_change'
      )
  ),
  behavior_countries as (
    select distinct lower(s.country) as value
    from behavior_source b
    join public.scholarships s on s.id = b.scholarship_id
  ),
  behavior_funding as (
    select distinct lower(s.funding_type) as value
    from behavior_source b
    join public.scholarships s on s.id = b.scholarship_id
  ),
  behavior_fields as (
    select distinct lower(f.field) as value
    from behavior_source b
    join public.scholarships s on s.id = b.scholarship_id
    cross join lateral unnest(s.fields) as f(field)
  ),
  scored as (
    select
      s.*,
      case
        when nullif(btrim(p_query), '') is null then 0::numeric
        else greatest(
          case
            when lower(s.title) = lower(btrim(p_query)) then 100
            when lower(s.title) like lower(btrim(p_query)) || '%' then 80
            else 0
          end,
          extensions.similarity(lower(s.title), lower(btrim(p_query))) * 70,
          extensions.similarity(lower(s.provider), lower(btrim(p_query))) * 45,
          extensions.similarity(lower(s.country), lower(btrim(p_query))) * 35,
          coalesce((
            select max(
              case
                when lower(f) = lower(btrim(p_query)) then 55
                when lower(f) like '%' || lower(btrim(p_query)) || '%' then 45
                else extensions.similarity(lower(f), lower(btrim(p_query))) * 30
              end
            )
            from unnest(s.fields) f
          ), 0)
        )
      end as query_score,
      (
        case when exists (
          select 1 from profile p
          where nullif(btrim(p.degree_level), '') is not null
            and exists (
              select 1 from unnest(s.degree_levels) d
              where lower(d) = lower(p.degree_level)
            )
        ) then 10 else 0 end
        + case when exists (
          select 1 from profile p
          where nullif(btrim(p.intended_major), '') is not null
            and exists (
              select 1 from unnest(s.fields) f
              where lower(f) = 'all fields'
                 or lower(f) like '%' || lower(p.intended_major) || '%'
                 or lower(p.intended_major) like '%' || lower(f) || '%'
            )
        ) then 8 else 0 end
        + case when exists (
          select 1 from profile p
          where lower(s.country) = any (
            select lower(c)
            from unnest(coalesce(p.target_countries, '{}')) c
          )
        ) then 7 else 0 end
        + case when exists (
          select 1 from behavior_countries bc
          where bc.value = lower(s.country)
        ) then 5 else 0 end
        + case when exists (
          select 1 from behavior_funding bf
          where bf.value = lower(s.funding_type)
        ) then 4 else 0 end
        + case when exists (
          select 1 from behavior_fields bf
          where exists (
            select 1 from unnest(s.fields) sf
            where lower(sf) = bf.value
               or lower(sf) = 'all fields'
          )
        ) then 5 else 0 end
      )::integer as personalization_score
    from public.scholarships s
    where s.status = 'published'
      and coalesce(s.verification_status, 'verified') <> 'needs_review'
      and coalesce(s.link_status, 'unchecked') not in ('dead', 'generic')
      and public.scholarship_is_discoverable(s)
      and not exists (
        select 1
        from public.recommendation_feedback rf
        where rf.user_id = auth.uid()
          and rf.scholarship_id = s.id
          and rf.feedback = 'not_interested'
      )
      and (
        nullif(btrim(p_query), '') is null
        or lower(s.title) like '%' || lower(btrim(p_query)) || '%'
        or lower(s.provider) like '%' || lower(btrim(p_query)) || '%'
        or lower(s.country) like '%' || lower(btrim(p_query)) || '%'
        or extensions.similarity(lower(s.title), lower(btrim(p_query))) >= 0.20
        or extensions.similarity(lower(s.provider), lower(btrim(p_query))) >= 0.24
        or exists (
          select 1 from unnest(s.fields) f
          where lower(f) like '%' || lower(btrim(p_query)) || '%'
             or extensions.similarity(lower(f), lower(btrim(p_query))) >= 0.28
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
        or lower(coalesce(s.verification_status, 'verified')) =
          lower(btrim(p_source))
      )
  )
  select
    to_jsonb(sc) - 'query_score' - 'personalization_score'
      || jsonb_build_object('university', to_jsonb(u)),
    count(*) over (),
    case
      when auth.uid() is null then false
      else exists (
        select 1
        from public.saved_scholarships ss
        where ss.user_id = auth.uid()
          and ss.scholarship_id = sc.id
      )
    end
  from scored sc
  left join public.universities u on u.id = sc.university_id
  order by
    case when p_sort = 'Deadline' then sc.deadline end asc nulls last,

    case when p_sort = 'Verified first'
      then (coalesce(sc.verification_status, '') = 'verified')::integer
    end desc nulls last,

    case when p_sort = 'Verified first'
      then (coalesce(sc.link_status, '') = 'exact')::integer
    end desc nulls last,

    case when p_sort = 'Verified first'
      then sc.reliability_score
    end desc nulls last,

    case when p_sort = 'Verified first'
      then sc.last_successful_check_at
    end desc nulls last,

    case when nullif(btrim(p_query), '') is not null
      then sc.query_score
    end desc nulls last,

    case when p_sort = 'Recommended'
      then sc.reliability_score
    end desc nulls last,

    case when p_sort = 'Recommended'
      then sc.personalization_score
    end desc nulls last,

    case when p_sort = 'Recommended'
      then (lower(sc.funding_type) like '%fully%')::integer
    end desc nulls last,

    sc.title asc
  offset greatest(coalesce(p_offset, 0), 0)
  limit greatest(1, least(coalesce(p_limit, 24), 100));
$$;
