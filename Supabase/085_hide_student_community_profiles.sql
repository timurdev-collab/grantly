-- Hide legacy student Community profiles for the 1.0 release.
update public.community_profiles
set is_visible = false,
    bio = null,
    updated_at = now()
where is_visible = true
   or bio is not null;
