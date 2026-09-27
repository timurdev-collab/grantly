-- Backend step 1: server-side scholarship matching.

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
set search_path = public
as $$
declare
  p public.student_profiles%rowtype;
  s public.scholarships%rowtype;
  v_score integer := 35;
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
    and coalesce(link_status, 'unchecked') not in ('dead', 'generic');

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
      v_score := v_score + 15;
      v_reasons := array_append(v_reasons, 'Supports ' || p.degree_level || ' study');
    else
      v_blockers := array_append(v_blockers, 'Degree level is not listed as eligible');
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
    v_reasons := array_append(v_reasons, 'Nationality appears eligible');
  else
    v_blockers := array_append(v_blockers, 'Nationality is not listed as eligible');
  end if;

  if s.min_gpa_percent is not null and v_gpa_percent is not null then
    if v_gpa_percent >= s.min_gpa_percent then
      v_score := v_score + 12;
      v_reasons := array_append(v_reasons, 'Meets the GPA threshold');
    else
      v_blockers := array_append(
        v_blockers,
        'GPA is below the listed ' || trunc(s.min_gpa_percent)::integer || '% threshold'
      );
    end if;
  elsif v_gpa_percent is not null then
    v_score := v_score + 4;
  end if;

  if s.min_ielts is not null and p.ielts is not null then
    if p.ielts >= s.min_ielts then
      v_score := v_score + 10;
      v_reasons := array_append(v_reasons, 'Meets the IELTS threshold');
    else
      v_blockers := array_append(
        v_blockers,
        'IELTS is below the listed ' || s.min_ielts::text || ' threshold'
      );
    end if;
  end if;

  if nullif(btrim(p.intended_major), '') is not null
     and exists (
       select 1 from unnest(s.fields) f
       where lower(f) = 'all fields'
          or lower(f) like '%' || lower(p.intended_major) || '%'
          or lower(p.intended_major) like '%' || lower(f) || '%'
     ) then
    v_score := v_score + 8;
    v_reasons := array_append(v_reasons, 'Academic field matches');
  end if;

  v_region_match := exists (
    select 1 from unnest(coalesce(p.target_regions, '{}')) r
    where lower(r) = lower(s.region)
  );

  v_country_match := exists (
    select 1 from unnest(coalesce(p.target_countries, '{}')) c
    where lower(c) = lower(s.country)
  );

  if v_region_match or v_country_match then
    v_score := v_score + 6;
    v_reasons := array_append(v_reasons, 'Matches a target destination');
  end if;

  if p.family_income_usd is not null
     and p.family_income_usd <= 15000
     and lower(s.funding_type) like '%fully%' then
    v_score := v_score + 4;
    v_reasons := array_append(v_reasons, 'Strong funding fit');
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
set search_path = public
as $$
  with ranked as (
    select
      to_jsonb(s) as scholarship,
      m.score,
      m.eligible,
      m.reasons,
      m.blockers,
      s.deadline,
      s.title
    from public.scholarships s
    cross join lateral public.score_scholarship_for_user(s.id) m
    where s.status = 'published'
      and coalesce(s.verification_status, 'verified') <> 'needs_review'
      and coalesce(s.link_status, 'unchecked') not in ('dead', 'generic')
  )
  select
    r.scholarship,
    r.score,
    r.eligible,
    r.reasons,
    r.blockers,
    count(*) over ()
  from ranked r
  order by
    r.eligible desc,
    r.score desc,
    r.deadline asc nulls last,
    r.title asc
  offset greatest(coalesce(p_offset, 0), 0)
  limit greatest(1, least(coalesce(p_limit, 24), 100));
$$;
