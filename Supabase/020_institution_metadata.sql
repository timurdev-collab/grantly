-- Enrich normalized provider records with type and website metadata.

alter table public.universities
  add column if not exists entity_type text not null default 'university'
  check (entity_type in ('university','government','foundation','organization','multi_institution','other'));

update public.universities
set entity_type = case
  when name ~* '(^| )(various|universities|university network|consortium)( |$)' then 'multi_institution'
  when name ~* '(government|ministry|embassy)' then 'government'
  when name ~* 'foundation' then 'foundation'
  when name ~* '(bank|council|commission|institute|academy|association|agency|programme|program)' then 'organization'
  else 'university'
end;

with candidate as (
  select distinct on (u.id)
    u.id,
    regexp_replace(s.official_url, '^(https?://[^/]+).*$', '\1') as origin
  from public.universities u
  join public.scholarships s on s.university_id = u.id
  where nullif(btrim(s.official_url), '') is not null
    and s.official_url ~ '^https?://'
  order by u.id, char_length(s.official_url) asc
)
update public.universities u
set website_url = c.origin
from candidate c
where u.id = c.id
  and u.website_url is null;

create index if not exists universities_entity_type_idx
  on public.universities(entity_type);
