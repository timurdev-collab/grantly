-- Hybrid profile + behavioral recommendation ranking.
-- Combines eligibility/profile fit, the student's own interactions and
-- anonymized collaborative signals from students with overlapping interests.

create index if not exists product_events_user_scholarship_recent_idx
on public.product_events(user_id, scholarship_id, created_at desc)
where scholarship_id is not null;

create index if not exists recommendation_feedback_user_scholarship_idx
on public.recommendation_feedback(user_id, scholarship_id);

create or replace function public.get_my_scholarship_matches(
  p_offset integer default 0,
  p_limit integer default 24
)
returns table(
  scholarship jsonb,
  score integer,
  eligible boolean,
  reasons text[],
  blockers text[],
  total_count bigint
)
language sql
stable
set search_path to 'public','extensions'
as $function$
  with my_positive as (
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

    union

    select rf.scholarship_id
    from public.recommendation_feedback rf
    where rf.user_id = auth.uid()
      and rf.feedback = 'interested'
  ),
  behavior_countries as (
    select distinct lower(s.country) as value
    from my_positive b
    join public.scholarships s on s.id = b.scholarship_id
  ),
  behavior_funding as (
    select distinct lower(s.funding_type) as value
    from my_positive b
    join public.scholarships s on s.id = b.scholarship_id
  ),
  behavior_fields as (
    select distinct lower(f.field) as value
    from my_positive b
    join public.scholarships s on s.id = b.scholarship_id
    cross join lateral unnest(s.fields) as f(field)
    where lower(f.field) <> 'all fields'
  ),
  peer_overlap as (
    select
      e.user_id,
      count(distinct e.scholarship_id)::numeric as overlap_count
    from public.product_events e
    join my_positive mine
      on mine.scholarship_id = e.scholarship_id
    where e.user_id is not null
      and e.user_id <> auth.uid()
      and e.created_at >= now() - interval '180 days'
      and e.event_name in (
        'scholarship_save',
        'official_site_click',
        'application_status_change'
      )
    group by e.user_id
    having count(distinct e.scholarship_id) >= 1
  ),
  peer_interest as (
    select
      e.scholarship_id,
      sum(least(po.overlap_count, 4))::numeric as affinity
    from peer_overlap po
    join public.product_events e
      on e.user_id = po.user_id
    where e.scholarship_id is not null
      and e.created_at >= now() - interval '180 days'
      and e.event_name in (
        'scholarship_save',
        'official_site_click',
        'application_status_change'
      )
      and not exists (
        select 1
        from my_positive mine
        where mine.scholarship_id = e.scholarship_id
      )
    group by e.scholarship_id
  ),
  peer_scaled as (
    select
      pi.scholarship_id,
      least(
        8,
        round(
          8 * pi.affinity /
          nullif(max(pi.affinity) over (), 0)
        )::integer
      ) as peer_boost
    from peer_interest pi
  ),
  ranked as (
    select
      to_jsonb(s) || jsonb_build_object(
        'university',
        to_jsonb(u)
      ) as scholarship,
      greatest(
        0,
        least(
          100,
          m.score
          + case when exists (
              select 1
              from behavior_countries bc
              where bc.value = lower(s.country)
            ) then 5 else 0 end
          + case when exists (
              select 1
              from behavior_funding bf
              where bf.value = lower(s.funding_type)
            ) then 4 else 0 end
          + case when exists (
              select 1
              from behavior_fields bf
              where exists (
                select 1
                from unnest(s.fields) sf
                where lower(sf) = bf.value
                   or lower(sf) = 'all fields'
              )
            ) then 5 else 0 end
          + case when rf.feedback = 'interested' then 8 else 0 end
          + coalesce(ps.peer_boost, 0)
          - case when ss.scholarship_id is not null then 4 else 0 end
        )
      )::integer as final_score,
      m.eligible,
      case
        when coalesce(ps.peer_boost, 0) > 0 then
          array_append(
            case
              when (
                exists (
                  select 1
                  from behavior_countries bc
                  where bc.value = lower(s.country)
                )
                or exists (
                  select 1
                  from behavior_funding bf
                  where bf.value = lower(s.funding_type)
                )
                or exists (
                  select 1
                  from behavior_fields bf
                  where exists (
                    select 1
                    from unnest(s.fields) sf
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
            end,
            'Students with similar interests also engaged with this opportunity'
          )
        when (
          exists (
            select 1
            from behavior_countries bc
            where bc.value = lower(s.country)
          )
          or exists (
            select 1
            from behavior_funding bf
            where bf.value = lower(s.funding_type)
          )
          or exists (
            select 1
            from behavior_fields bf
            where exists (
              select 1
              from unnest(s.fields) sf
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
      s.title,
      s.reliability_score
    from public.scholarships s
    left join public.universities u
      on u.id = s.university_id
    cross join lateral public.score_scholarship_for_user(s.id) m
    left join public.recommendation_feedback rf
      on rf.user_id = auth.uid()
     and rf.scholarship_id = s.id
    left join public.saved_scholarships ss
      on ss.user_id = auth.uid()
     and ss.scholarship_id = s.id
    left join peer_scaled ps
      on ps.scholarship_id = s.id
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
    r.reliability_score desc nulls last,
    r.title asc
  offset greatest(coalesce(p_offset, 0), 0)
  limit greatest(1, least(coalesce(p_limit, 24), 100));
$function$;
