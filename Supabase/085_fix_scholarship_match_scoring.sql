-- Fix personalized scholarship scoring returning no rows.
-- The prior PL/pgSQL function passed its uninitialized row variable to
-- scholarship_is_discoverable() instead of the selected table row.

create or replace function public.score_scholarship_for_user(
  p_scholarship_id uuid
)
returns table(
  score integer,
  eligible boolean,
  reasons text[],
  blockers text[]
)
language plpgsql
stable
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

  select *
  into p
  from public.student_profiles
  where id = auth.uid();

  if not found then
    raise exception 'Student profile not found';
  end if;

  select sch.*
  into s
  from public.scholarships sch
  where sch.id = p_scholarship_id
    and sch.status = 'published'
    and coalesce(sch.verification_status, 'verified') <> 'needs_review'
    and coalesce(sch.link_status, 'unchecked') not in ('dead', 'generic')
    and public.scholarship_is_discoverable(sch);

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

  v_score := v_score + case
    when coalesce(s.reliability_score, 0) >= 85 then 6
    when coalesce(s.reliability_score, 0) >= 70 then 4
    when coalesce(s.reliability_score, 0) >= 55 then 2
    else 0
  end;

  if coalesce(s.reliability_score, 0) >= 70 then
    v_reasons := array_append(
      v_reasons,
      'Source data is recently verified and reliable'
    );
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

revoke execute on function public.score_scholarship_for_user(uuid)
from public, anon;
grant execute on function public.score_scholarship_for_user(uuid)
to authenticated;
