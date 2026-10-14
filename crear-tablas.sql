begin;
-- Ejecutar en Supabase SQL Editor o con supabase db reset/push.
create table public.private_members (
 owner_id uuid primary key references auth.users(id) on delete cascade,
 created_at timestamptz not null default now()
);
alter table public.private_members enable row level security;
revoke all on public.private_members from anon, authenticated;
create function public.is_plan_member() returns boolean language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.private_members where owner_id=(select auth.uid()));
$$;
revoke all on function public.is_plan_member() from public;
grant execute on function public.is_plan_member() to authenticated;
create function public.touch_updated_at() returns trigger language plpgsql set search_path = '' as $$
begin new.updated_at=now(); return new; end; $$;
create table public.user_state (
 owner_id uuid primary key references auth.users(id) on delete cascade,
 payload jsonb not null check(jsonb_typeof(payload)='object' and payload->>'version'='1'),
 revision bigint not null default 1 check(revision>0),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.state_versions (
 id bigint generated always as identity primary key,
 owner_id uuid not null references auth.users(id) on delete cascade,
 revision bigint not null, payload jsonb not null, created_at timestamptz not null default now(),
 unique(owner_id, revision)
);
-- Snapshot transaccional para el MVP: user_state es el estado autoritativo.
-- Las siguientes tablas dejan preparada la estructura relacional; no son una segunda fuente de saldos.

create table public.profiles (
 id uuid primary key default gen_random_uuid(), owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 display_name text not null default 'Mi espacio', timezone text not null default 'America/Argentina/Buenos_Aires',
 status text not null default 'planned' check(status in ('planned','confirmed','cancelled')),
 source text not null default 'manual' check(source in ('pdf_seed','manual','recurring')),
 confidence text not null default 'unverified' check(confidence in ('confirmed','estimate','unverified')),
 source_page integer check(source_page>0), note text,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table public.accounts (
 id uuid primary key default gen_random_uuid(), owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 name text not null, kind text not null check(kind in ('cash','bank','fund')), declared_balance bigint not null default 0, balance_verified boolean not null default false,
 status text not null default 'planned' check(status in ('planned','confirmed','cancelled')),
 source text not null default 'manual' check(source in ('pdf_seed','manual','recurring')),
 confidence text not null default 'unverified' check(confidence in ('confirmed','estimate','unverified')),
 source_page integer check(source_page>0), note text,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table public.categories (
 id uuid primary key default gen_random_uuid(), owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 name text not null, monthly_limit bigint not null default 0 check(monthly_limit>=0),
 status text not null default 'planned' check(status in ('planned','confirmed','cancelled')),
 source text not null default 'manual' check(source in ('pdf_seed','manual','recurring')),
 confidence text not null default 'unverified' check(confidence in ('confirmed','estimate','unverified')),
 source_page integer check(source_page>0), note text,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table public.budget_periods (
 id uuid primary key default gen_random_uuid(), owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 month date not null, closed_at timestamptz, snapshot jsonb,
 status text not null default 'planned' check(status in ('planned','confirmed','cancelled')),
 source text not null default 'manual' check(source in ('pdf_seed','manual','recurring')),
 confidence text not null default 'unverified' check(confidence in ('confirmed','estimate','unverified')),
 source_page integer check(source_page>0), note text,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table public.budget_lines (
 id uuid primary key default gen_random_uuid(), owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 period_id uuid references public.budget_periods(id), category_id uuid references public.categories(id), amount bigint not null check(amount>=0),
 status text not null default 'planned' check(status in ('planned','confirmed','cancelled')),
 source text not null default 'manual' check(source in ('pdf_seed','manual','recurring')),
 confidence text not null default 'unverified' check(confidence in ('confirmed','estimate','unverified')),
 source_page integer check(source_page>0), note text,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table public.income_entries (
 id uuid primary key default gen_random_uuid(), owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 period_id uuid references public.budget_periods(id), amount bigint not null check(amount>0), occurred_on date not null, extraordinary boolean not null default false,
 status text not null default 'planned' check(status in ('planned','confirmed','cancelled')),
 source text not null default 'manual' check(source in ('pdf_seed','manual','recurring')),
 confidence text not null default 'unverified' check(confidence in ('confirmed','estimate','unverified')),
 source_page integer check(source_page>0), note text,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table public.cards (
 id uuid primary key default gen_random_uuid(), owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 name text not null, closing_day integer not null check(closing_day between 1 and 31), due_day integer not null check(due_day between 1 and 31),
 status text not null default 'planned' check(status in ('planned','confirmed','cancelled')),
 source text not null default 'manual' check(source in ('pdf_seed','manual','recurring')),
 confidence text not null default 'unverified' check(confidence in ('confirmed','estimate','unverified')),
 source_page integer check(source_page>0), note text,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table public.statement_cycles (
 id uuid primary key default gen_random_uuid(), owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 card_id uuid references public.cards(id), starts_on date not null, closes_on date not null, due_on date not null, confirmed_total bigint check(confirmed_total>=0), check(starts_on<=closes_on and closes_on<due_on),
 status text not null default 'planned' check(status in ('planned','confirmed','cancelled')),
 source text not null default 'manual' check(source in ('pdf_seed','manual','recurring')),
 confidence text not null default 'unverified' check(confidence in ('confirmed','estimate','unverified')),
 source_page integer check(source_page>0), note text,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table public.installment_plans (
 id uuid primary key default gen_random_uuid(), owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 card_id uuid references public.cards(id), total_amount bigint not null check(total_amount>0), installments_count integer not null check(installments_count between 1 and 60), purchase_date date not null,
 status text not null default 'planned' check(status in ('planned','confirmed','cancelled')),
 source text not null default 'manual' check(source in ('pdf_seed','manual','recurring')),
 confidence text not null default 'unverified' check(confidence in ('confirmed','estimate','unverified')),
 source_page integer check(source_page>0), note text,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table public.installments (
 id uuid primary key default gen_random_uuid(), owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 plan_id uuid references public.installment_plans(id), cycle_id uuid references public.statement_cycles(id), installment_number integer not null check(installment_number>0), amount bigint not null check(amount>=0),
 status text not null default 'planned' check(status in ('planned','confirmed','cancelled')),
 source text not null default 'manual' check(source in ('pdf_seed','manual','recurring')),
 confidence text not null default 'unverified' check(confidence in ('confirmed','estimate','unverified')),
 source_page integer check(source_page>0), note text,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table public.obligations (
 id uuid primary key default gen_random_uuid(), owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 period_id uuid references public.budget_periods(id), label text not null, amount bigint not null check(amount>=0), included_in_card boolean not null default false, expected_on date, paid_on date,
 status text not null default 'planned' check(status in ('planned','confirmed','cancelled')),
 source text not null default 'manual' check(source in ('pdf_seed','manual','recurring')),
 confidence text not null default 'unverified' check(confidence in ('confirmed','estimate','unverified')),
 source_page integer check(source_page>0), note text,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table public.funds (
 id uuid primary key default gen_random_uuid(), owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 name text not null, target_amount bigint not null default 0 check(target_amount>=0),
 status text not null default 'planned' check(status in ('planned','confirmed','cancelled')),
 source text not null default 'manual' check(source in ('pdf_seed','manual','recurring')),
 confidence text not null default 'unverified' check(confidence in ('confirmed','estimate','unverified')),
 source_page integer check(source_page>0), note text,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table public.fund_transfers (
 id uuid primary key default gen_random_uuid(), owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 fund_id uuid references public.funds(id), amount bigint not null check(amount>0), direction text not null check(direction in ('in','out')), occurred_on date not null,
 status text not null default 'planned' check(status in ('planned','confirmed','cancelled')),
 source text not null default 'manual' check(source in ('pdf_seed','manual','recurring')),
 confidence text not null default 'unverified' check(confidence in ('confirmed','estimate','unverified')),
 source_page integer check(source_page>0), note text,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table public.plan_scenarios (
 id uuid primary key default gen_random_uuid(), owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 name text not null, is_draft boolean not null default true, parameters jsonb not null default '{}',
 status text not null default 'planned' check(status in ('planned','confirmed','cancelled')),
 source text not null default 'manual' check(source in ('pdf_seed','manual','recurring')),
 confidence text not null default 'unverified' check(confidence in ('confirmed','estimate','unverified')),
 source_page integer check(source_page>0), note text,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table public.assumptions (
 id uuid primary key default gen_random_uuid(), owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 scenario_id uuid references public.plan_scenarios(id), name text not null, value jsonb not null, effective_month date,
 status text not null default 'planned' check(status in ('planned','confirmed','cancelled')),
 source text not null default 'manual' check(source in ('pdf_seed','manual','recurring')),
 confidence text not null default 'unverified' check(confidence in ('confirmed','estimate','unverified')),
 source_page integer check(source_page>0), note text,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table public.reconciliation_flags (
 id uuid primary key default gen_random_uuid(), owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 message text not null, resolved boolean not null default false,
 status text not null default 'planned' check(status in ('planned','confirmed','cancelled')),
 source text not null default 'manual' check(source in ('pdf_seed','manual','recurring')),
 confidence text not null default 'unverified' check(confidence in ('confirmed','estimate','unverified')),
 source_page integer check(source_page>0), note text,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table public.audit_log (
 id uuid primary key default gen_random_uuid(), owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 action text not null, entity_id uuid, metadata jsonb not null default '{}',
 status text not null default 'planned' check(status in ('planned','confirmed','cancelled')),
 source text not null default 'manual' check(source in ('pdf_seed','manual','recurring')),
 confidence text not null default 'unverified' check(confidence in ('confirmed','estimate','unverified')),
 source_page integer check(source_page>0), note text,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table public.transactions (
 id uuid primary key default gen_random_uuid(), owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 category_id uuid references public.categories(id), account_id uuid references public.accounts(id), card_id uuid references public.cards(id), cycle_id uuid references public.statement_cycles(id), amount bigint not null check(amount>0), kind text not null check(kind in ('expense','income','transfer','card_payment')), description text not null, purchase_date date not null, settlement_date date, budget_month date not null,
 status text not null default 'planned' check(status in ('planned','confirmed','cancelled')),
 source text not null default 'manual' check(source in ('pdf_seed','manual','recurring')),
 confidence text not null default 'unverified' check(confidence in ('confirmed','estimate','unverified')),
 source_page integer check(source_page>0), note text,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

do $$
declare t text;
begin
 foreach t in array array['user_state','profiles','accounts','categories','budget_periods','budget_lines','income_entries','cards','statement_cycles','installment_plans','installments','obligations','funds','fund_transfers','plan_scenarios','assumptions','reconciliation_flags','audit_log','transactions'] loop
 execute format('alter table public.%I enable row level security',t);
 execute format('revoke all on public.%I from anon, authenticated',t);
 execute format('grant select, insert, update on public.%I to authenticated',t);
 execute format('create policy owner_select on public.%I for select to authenticated using (owner_id = (select auth.uid()) and public.is_plan_member())',t);
 execute format('create policy owner_insert on public.%I for insert to authenticated with check (owner_id = (select auth.uid()) and public.is_plan_member())',t);
 execute format('create policy owner_update on public.%I for update to authenticated using (owner_id = (select auth.uid()) and public.is_plan_member()) with check (owner_id = (select auth.uid()) and public.is_plan_member())',t);
 execute format('create trigger updated_at before update on public.%I for each row execute function public.touch_updated_at()',t);
 if t <> 'user_state' then execute format('create index on public.%I(owner_id)',t); end if;
 end loop;
end $$;
alter table public.state_versions enable row level security;
revoke all on public.state_versions from anon, authenticated;
grant select on public.state_versions to authenticated;
create policy own_versions on public.state_versions for select to authenticated using (owner_id=(select auth.uid()) and public.is_plan_member());
-- Auditoría append-only: no conceder modificación directa al cliente.
revoke insert, update on public.audit_log from authenticated;
create function public.guard_plan_state() returns trigger language plpgsql set search_path='' as $$
declare p jsonb; before_tx jsonb; after_tx jsonb; before_ft jsonb; after_ft jsonb; t jsonb; n jsonb; income bigint; expense bigint; transfers bigint;
begin
 if new.owner_id <> auth.uid() then raise exception 'owner mismatch'; end if;
 if jsonb_typeof(new.payload->'periods') <> 'array' or jsonb_typeof(new.payload->'transactions') <> 'array' or jsonb_typeof(new.payload->'fundTransfers') <> 'array' then raise exception 'Invalid payload'; end if;
 if tg_op='UPDATE' then
  if new.revision<>old.revision+1 then raise exception 'revision conflict'; end if;
  for p in select value from jsonb_array_elements(old.payload->'periods') where value->>'closed'='true' loop
   select value into n from jsonb_array_elements(new.payload->'periods') where value->>'month'=p->>'month';
   if n is distinct from p then raise exception 'closed period immutable'; end if;
   select coalesce(jsonb_agg(value order by value->>'id'),'[]') into before_tx from jsonb_array_elements(coalesce(old.payload->'statementConfirmations','[]')) where value->>'month'=p->>'month';
   select coalesce(jsonb_agg(value order by value->>'id'),'[]') into after_tx from jsonb_array_elements(coalesce(new.payload->'statementConfirmations','[]')) where value->>'month'=p->>'month';
   if before_tx is distinct from after_tx then raise exception 'closed statements immutable'; end if;
   select coalesce(jsonb_agg(value order by value->>'id'),'[]') into before_tx from jsonb_array_elements(old.payload->'transactions') where left(value->>'date',7)=p->>'month';
   select coalesce(jsonb_agg(value order by value->>'id'),'[]') into after_tx from jsonb_array_elements(new.payload->'transactions') where left(value->>'date',7)=p->>'month';
   select coalesce(jsonb_agg(value order by value->>'id'),'[]') into before_ft from jsonb_array_elements(old.payload->'fundTransfers') where left(value->>'date',7)=p->>'month';
   select coalesce(jsonb_agg(value order by value->>'id'),'[]') into after_ft from jsonb_array_elements(new.payload->'fundTransfers') where left(value->>'date',7)=p->>'month';
   if before_tx is distinct from after_tx or before_ft is distinct from after_ft then raise exception 'closed transactions immutable'; end if;
  end loop;
  for p in select value from jsonb_array_elements(old.payload->'periods') loop
   for t in select value from jsonb_array_elements(p->'lines') where value->>'status'='paid' loop
    if not exists(select 1 from jsonb_array_elements(new.payload->'periods') newp cross join lateral jsonb_array_elements(newp.value->'lines') newl where newp.value->>'month'=p->>'month' and newl.value->>'id'=t->>'id') then raise exception 'keep paid obligations in history'; end if;
   end loop;
  end loop;
  for t in select value from jsonb_array_elements(old.payload->'fundTransfers') loop
   if not exists(select 1 from jsonb_array_elements(new.payload->'fundTransfers') where value->>'id'=t->>'id') then raise exception 'cancel fund transfer instead of deleting'; end if;
  end loop;
  for t in select value from jsonb_array_elements(old.payload->'transactions') loop
   if not exists(select 1 from jsonb_array_elements(new.payload->'transactions') where value->>'id'=t->>'id') then raise exception 'cancel instead of deleting'; end if;
  end loop;
 end if;
 for p in select value from jsonb_array_elements(new.payload->'funds') loop
  select coalesce(sum(case when value->>'direction'='in' then (value->>'amount')::bigint else -(value->>'amount')::bigint end),0) into transfers from jsonb_array_elements(new.payload->'fundTransfers') where value->>'fundId'=p->>'id' and value->>'status'='confirmed';
  if transfers<0 then raise exception 'insufficient fund balance'; end if;
 end loop;
 for p in select value from jsonb_array_elements(new.payload->'periods') where value->>'distributed'='true' loop
  income=case when p->>'incomeConfirmed'='true' then (p->>'income')::bigint else 0 end + (p->>'financing')::bigint;
  select income+coalesce(sum((value->>'amount')::bigint),0) into income from jsonb_array_elements(new.payload->'transactions') where value->>'type'='income' and value->>'status'='confirmed' and left(value->>'date',7)=p->>'month';
  select coalesce(sum((value->>'amount')::bigint),0) into expense from jsonb_array_elements(p->'lines') where value->>'status'<>'cancelled' and value->>'includedInCard'='false';
  select coalesce(sum(case when value->>'direction'='in' then (value->>'amount')::bigint else -(value->>'amount')::bigint end),0) into transfers from jsonb_array_elements(new.payload->'fundTransfers') where value->>'status'='confirmed' and left(value->>'date',7)=p->>'month';
  if income-expense-transfers-(p->>'reserve')::bigint<0 then raise exception 'distribution exceeds effective income'; end if;
 end loop;
 return new;
end $$;
create trigger guard_state before insert or update on public.user_state for each row execute function public.guard_plan_state();
create function public.record_plan_version() returns trigger language plpgsql security definer set search_path='' as $$
begin
 insert into public.state_versions(owner_id,revision,payload) values(new.owner_id,new.revision,new.payload);
 insert into public.audit_log(owner_id,action,status,confidence,metadata) values(new.owner_id,'state_saved','confirmed','confirmed',jsonb_build_object('revision',new.revision));
 return new;
end $$;
create trigger record_version after insert or update on public.user_state for each row execute function public.record_plan_version();
revoke all on function public.guard_plan_state(),public.record_plan_version(),public.touch_updated_at() from public,anon,authenticated;
-- Una FK no puede enlazar un registro de otro propietario, aun con UUID conocido.
create function public.guard_related_owner() returns trigger language plpgsql set search_path='' as $$
declare fk record; linked uuid; linked_owner uuid;
begin
 for fk in
  select child.attname as column_name, parent.relname as table_name
  from pg_constraint c
  join pg_class parent on parent.oid=c.confrelid
  join pg_namespace ns on ns.oid=parent.relnamespace
  join pg_attribute child on child.attrelid=c.conrelid and child.attnum=c.conkey[1]
  where c.conrelid=tg_relid and c.contype='f' and ns.nspname='public'
 loop
  linked=(to_jsonb(new)->>fk.column_name)::uuid;
  if linked is not null then
   execute format('select owner_id from public.%I where id=$1',fk.table_name) into linked_owner using linked;
   if linked_owner is distinct from new.owner_id then raise exception 'related owner mismatch'; end if;
  end if;
 end loop;
 return new;
end $$;
do $$ declare t text; begin
 foreach t in array array['budget_lines','income_entries','statement_cycles','installment_plans','installments','obligations','fund_transfers','assumptions','transactions'] loop
  execute format('create trigger related_owner before insert or update on public.%I for each row execute function public.guard_related_owner()',t);
 end loop;
end $$;
revoke all on function public.guard_related_owner() from public,anon,authenticated;

commit;
