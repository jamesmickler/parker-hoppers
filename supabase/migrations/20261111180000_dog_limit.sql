-- Park Hoppers: at most 10 dogs per person.
-- A check-in can list up to 10 dogs, and automatic check-in brings all of a person's dogs, so
-- someone with more than 10 could never check in.

create or replace function public.limit_dogs_per_person() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if (select count(*) from public.dogs where owner_id = new.owner_id) >= 10 then
    raise exception 'You can add up to 10 dogs.' using errcode = '23514';
  end if;
  return new;
end;
$$;
revoke execute on function public.limit_dogs_per_person() from public, anon, authenticated;

drop trigger if exists limit_dogs_per_person on public.dogs;
create trigger limit_dogs_per_person before insert on public.dogs
  for each row execute function public.limit_dogs_per_person();
