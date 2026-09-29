-- The notify-arrival function marks a check-in as notified. That update must not count as a
-- fresh arrival (which would reset the mark and allow repeat notifications), so only
-- people's own check-ins restart the clock.
create or replace function public.stamp_arrival() returns trigger
language plpgsql set search_path = '' as $$
begin
  if tg_op = 'UPDATE' and current_user = 'service_role' then
    return new;
  end if;
  new.arrived_at := now();
  new.notified := false;
  return new;
end;
$$;
