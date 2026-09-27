-- Data reliability step 4: distinguish closed/expired cycles from invalid records.
-- Closed or expired opportunities remain stored and visible in saved applications/admin,
-- but are removed from discovery and recommendations until a current cycle is confirmed.

create or replace function public.scholarship_is_discoverable(
  s public.scholarships
)
returns boolean
language sql
stable
security invoker
set search_path = public
as $$
  select
    s.status = 'published'
    and coalesce(s.verification_status, 'verified') <> 'needs_review'
    and coalesce(s.link_status, 'unchecked') not in ('dead', 'generic')
    and coalesce(s.cycle_status, 'unknown') not in ('closed', 'discontinued')
    and (
      s.deadline is null
      or s.deadline >= current_date
    )
    and coalesce(s.deadline_verification_status, 'unconfirmed') <> 'expired';
$$;

revoke execute on function public.scholarship_is_discoverable(public.scholarships)
from public;
grant execute on function public.scholarship_is_discoverable(public.scholarships)
to anon, authenticated;


create or replace function public.score_scholarship_for_user(
  p_scholarship_id uuid
)
returns table (
  score integer,
  eligible boolean,
  reasons text[],
  blockers text[]
)
language plpgsql
stable
security invoker
set search_path = public, extensions
as $$
declare
  p public.student_profiles%rowtype;
  s public.scholarships%rowtype;
  v_score integer := 30;
  v_reasons text[] := '{}';
  v_blockers text[] := '{}';
  v_gpa_percent numeric;
  v_region_match boolean := false;
  v_country_match boolean := false;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  select * into p
  from public.student_profiles
  where id = auth.uid();

  if not found then
    raise exception 'Student profile not found';
  end if;

  select * into s
  from public.scholarships
  where id = p_scholarship_id
    and status = 'published'
    and coalesce(verification_status, 'verified') <> 'needs_review'
    and coalesce(link_status, 'unchecked') not in ('dead', 'generic')
    and public.scholarship_is_discoverable(s);

  if not found then
    return;
  end if;

  if p.gpa_value is not null
     and p.gpa_scale is not null
     and p.gpa_scale > 0 then
    v_gpa_percent := p.gpa_value / p.gpa_scale * 100;
  end if;

  if nullif(btrim(p.degree_level), '') is not null then
    if exists (
      select 1 from unnest(s.degree_levels) d
      where lower(d) = lower(p.degree_level)
    ) then
      v_score := v_score + 16;
      v_reasons := array_append(
        v_reasons,
        'Your ' || p.degree_level || ' study level is eligible'
      );
    else
      v_blockers := array_append(
        v_blockers,
        'Your ' || p.degree_level || ' study level is not listed as eligible'
      );
    end if;
  end if;

  if exists (
      select 1 from unnest(s.eligible_nationalities) n
      where upper(n) = 'ALL'
    )
    or (
      nullif(btrim(p.nationality), '') is not null
      and exists (
        select 1 from unnest(s.eligible_nationalities) n
        where lower(n) = lower(p.nationality)
      )
    ) then
    v_score := v_score + 10;
    if nullif(btrim(p.nationality), '') is not null then
      v_reasons := array_append(
        v_reasons,
        p.nationality || ' applicants appear eligible'
      );
    else
      v_reasons := array_append(v_reasons, 'Open to all nationalities');
    end if;
  else
    v_blockers := array_append(
      v_blockers,
      coalesce(p.nationality, 'Your nationality') ||
      ' is not listed as eligible'
    );
  end if;

  if s.min_gpa_percent is not null and v_gpa_percent is not null then
    if v_gpa_percent >= s.min_gpa_percent then
      v_score := v_score + 12;
      v_reasons := array_append(
        v_reasons,
        'Your GPA (' || round(v_gpa_percent, 1)::text ||
        '%) clears the ' || trunc(s.min_gpa_percent)::integer ||
        '% minimum'
      );
    else
      v_blockers := array_append(
        v_blockers,
        'Your GPA (' || round(v_gpa_percent, 1)::text ||
        '%) is below the ' || trunc(s.min_gpa_percent)::integer ||
        '% minimum'
      );
    end if;
  elsif v_gpa_percent is not null then
    v_score := v_score + 4;
    v_reasons := array_append(v_reasons, 'No minimum GPA is listed');
  end if;

  if s.min_ielts is not null and p.ielts is not null then
    if p.ielts >= s.min_ielts then
      v_score := v_score + 10;
      v_reasons := array_append(
        v_reasons,
        'Your IELTS ' || p.ielts::text ||
        ' clears the ' || s.min_ielts::text || ' minimum'
      );
    else
      v_blockers := array_append(
        v_blockers,
        'Your IELTS ' || p.ielts::text ||
        ' is below the ' || s.min_ielts::text || ' minimum'
      );
    end if;
  elsif s.min_ielts is null then
    v_score := v_score + 2;
  end if;

  if nullif(btrim(p.intended_major), '') is not null
     and exists (
       select 1 from unnest(s.fields) f
       where lower(f) = 'all fields'
          or lower(f) like '%' || lower(p.intended_major) || '%'
          or lower(p.intended_major) like '%' || lower(f) || '%'
     ) then
    v_score := v_score + 9;
    v_reasons := array_append(
      v_reasons,
      'Fits your intended field: ' || p.intended_major
    );
  end if;

  v_region_match := exists (
    select 1 from unnest(coalesce(p.target_regions, '{}')) r
    where lower(r) = lower(s.region)
  );

  v_country_match := exists (
    select 1 from unnest(coalesce(p.target_countries, '{}')) c
    where lower(c) = lower(s.country)
  );

  if v_country_match then
    v_score := v_score + 7;
    v_reasons := array_append(
      v_reasons,
      s.country || ' is one of your target countries'
    );
  elsif v_region_match then
    v_score := v_score + 5;
    v_reasons := array_append(
      v_reasons,
      s.region || ' matches your target regions'
    );
  end if;

  if p.family_income_usd is not null
     and p.family_income_usd <= 15000
     and lower(s.funding_type) like '%fully%' then
    v_score := v_score + 5;
    v_reasons := array_append(
      v_reasons,
      'Full funding strongly matches your financial profile'
    );
  elsif lower(s.funding_type) like '%fully%' then
    v_score := v_score + 2;
  end if;

  if coalesce(s.verification_status, 'verified') = 'verified' then
    v_score := v_score + 2;
  end if;

  eligible := coalesce(cardinality(v_blockers), 0) = 0;

  if not eligible then
    v_score := least(v_score, 54);
  end if;

  score := greatest(0, least(100, v_score));
  reasons := v_reasons;
  blockers := v_blockers;
  return next;
end;
$$;

create or replace function public.get_my_scholarship_matches(
  p_offset integer default 0,
  p_limit integer default 24
)
returns table (
  scholarship jsonb,
  score integer,
  eligible boolean,
  reasons text[],
  blockers text[],
  total_count bigint
)
language sql
stable
security invoker
set search_path = public, extensions
as $$
  with behavior_source as (
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
    where lower(f.field) <> 'all fields'
  ),
  ranked as (
    select
      to_jsonb(s) || jsonb_build_object('university', to_jsonb(u)) as scholarship,
      greatest(
        0,
        least(
          100,
          m.score
          + case when exists (
              select 1 from behavior_countries bc
              where bc.value = lower(s.country)
            ) then 5 else 0 end
          + case when exists (
              select 1 from behavior_funding bf
              where bf.value = lower(s.funding_type)
            ) then 4 else 0 end
          + case when exists (
              select 1
              from behavior_fields bf
              where exists (
                select 1 from unnest(s.fields) sf
                where lower(sf) = bf.value
                   or lower(sf) = 'all fields'
              )
            ) then 5 else 0 end
          + case when rf.feedback = 'interested' then 8 else 0 end
          - case when ss.scholarship_id is not null then 4 else 0 end
        )
      )::integer as final_score,
      m.eligible,
      case
        when (
          exists (
            select 1 from behavior_countries bc
            where bc.value = lower(s.country)
          )
          or exists (
            select 1 from behavior_funding bf
            where bf.value = lower(s.funding_type)
          )
          or exists (
            select 1
            from behavior_fields bf
            where exists (
              select 1 from unnest(s.fields) sf
              where lower(sf) = bf.value
                 or lower(sf) = 'all fields'
            )
          )
        )
        then array_append(
          m.reasons,
          'Similar to opportunities you saved, opened or applied to'
        )
        else m.reasons
      end as final_reasons,
      m.blockers,
      s.deadline,
      s.title
    from public.scholarships s
    left join public.universities u on u.id = s.university_id
    cross join lateral public.score_scholarship_for_user(s.id) m
    left join public.recommendation_feedback rf
      on rf.user_id = auth.uid()
     and rf.scholarship_id = s.id
    left join public.saved_scholarships ss
      on ss.user_id = auth.uid()
     and ss.scholarship_id = s.id
    where s.status = 'published'
      and coalesce(s.verification_status, 'verified') <> 'needs_review'
      and coalesce(s.link_status, 'unchecked') not in ('dead', 'generic')
      and public.scholarship_is_discoverable(s)
      and coalesce(rf.feedback, '') <> 'not_interested'
  )
  select
    r.scholarship,
    r.final_score,
    r.eligible,
    r.final_reasons,
    r.blockers,
    count(*) over ()
  from ranked r
  order by
    r.eligible desc,
    r.final_score desc,
    r.deadline asc nulls last,
    r.title asc
  offset greatest(coalesce(p_offset, 0), 0)
  limit greatest(1, least(coalesce(p_limit, 24), 100));
$$;

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
      then (coalesce(sc.verification_status, 'verified') = 'verified')::integer
    end desc nulls last,
    case when nullif(btrim(p_query), '') is not null
      then sc.query_score
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
      and public.scholarship_is_discoverable(scholarships)
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
