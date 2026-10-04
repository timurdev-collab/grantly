-- Correct moderation regexes: use explicit POSIX-safe token boundaries.

delete from public.content_moderation_patterns
where category in (
  'profanity','hate','self_harm_abuse',
  'sexual_threat','violent_threat','sexual_exploitation'
);

insert into public.content_moderation_patterns(pattern, category)
values
  ('(^|[^[:alnum:]_])(fuck|fucking|motherfucker)([^[:alnum:]_]|$)', 'profanity'),
  ('(^|[^[:alnum:]_])(nigger|kike|faggot)([^[:alnum:]_]|$)', 'hate'),
  ('(^|[^[:alnum:]_])(kill yourself|kys)([^[:alnum:]_]|$)', 'self_harm_abuse'),
  ('(^|[^[:alnum:]_])(rape you|i will rape)([^[:alnum:]_]|$)', 'sexual_threat'),
  ('(^|[^[:alnum:]_])(i will kill you|going to kill you)([^[:alnum:]_]|$)', 'violent_threat'),
  ('(^|[^[:alnum:]_])(child porn|child pornography)([^[:alnum:]_]|$)', 'sexual_exploitation'),
  ('(пош[её]л нах|иди нах|сука бля)', 'profanity'),
  ('(địt mẹ|đụ má)', 'profanity')
on conflict (pattern) do nothing;
