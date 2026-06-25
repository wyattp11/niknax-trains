update public.slots
set label = null
where lower(trim(coalesce(label, ''))) = 'niknax boost';
