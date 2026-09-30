-- Allow resumable social video uploads while keeping media private.

update storage.buckets
set file_size_limit = 262144000
where id = 'social-media';
