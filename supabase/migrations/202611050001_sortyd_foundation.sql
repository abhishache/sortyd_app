-- Sortyd Supabase Production Schema & Non-Destructive Merge Engine
-- Project: hdokavfcqxmbshmgwcam (Sortyd)

begin;

-- 1. Profiles table (automatically populated from auth.users)
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  full_name text,
  avatar_url text,
  provider text default 'email',
  active_list_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

drop policy if exists profiles_select_own on public.profiles;
create policy profiles_select_own on public.profiles
  for select to authenticated using ((select auth.uid()) = id);

drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles
  for update to authenticated using ((select auth.uid()) = id) with check ((select auth.uid()) = id);

drop policy if exists profiles_insert_own on public.profiles;
create policy profiles_insert_own on public.profiles
  for insert to authenticated with check ((select auth.uid()) = id);

-- Trigger to auto-create profile on signup (Email, Google, Apple)
create or replace function public.handle_new_sortyd_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, email, full_name, avatar_url, provider, updated_at)
  values (
    new.id,
    new.email,
    coalesce(
      new.raw_user_meta_data->>'full_name',
      new.raw_user_meta_data->>'name',
      split_part(coalesce(new.email, 'Member'), '@', 1)
    ),
    new.raw_user_meta_data->>'avatar_url',
    coalesce(new.raw_app_meta_data->>'provider', 'email'),
    now()
  )
  on conflict (id) do update set
    email = coalesce(excluded.email, public.profiles.email),
    full_name = coalesce(nullif(excluded.full_name, ''), public.profiles.full_name),
    avatar_url = coalesce(excluded.avatar_url, public.profiles.avatar_url),
    updated_at = now();
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert or update on auth.users
  for each row execute function public.handle_new_sortyd_user();

-- 2. Habit Lists table (normalized relational view of every user's lists)
create table if not exists public.habit_lists (
  user_id uuid not null references auth.users(id) on delete cascade,
  id uuid not null,
  name text not null,
  emoji text not null default '📋',
  is_archived boolean not null default false,
  is_todo boolean not null default false,
  is_weekly boolean not null default false,
  sort_order integer not null default 0,
  deleted boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, id)
);

alter table public.habit_lists enable row level security;

drop policy if exists habit_lists_owner_all on public.habit_lists;
create policy habit_lists_owner_all on public.habit_lists
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- 3. Habit Tasks table (normalized relational view of every task inside lists)
create table if not exists public.habit_tasks (
  user_id uuid not null references auth.users(id) on delete cascade,
  id uuid not null,
  list_id uuid not null,
  title text not null,
  is_completed boolean not null default false,
  manually_completed boolean not null default false,
  weight double precision not null default 0,
  reminder_is_one_time boolean not null default false,
  notification_lead_minutes integer not null default 0,
  duration_minutes integer,
  health_type text,
  health_target double precision,
  sort_order integer not null default 0,
  deleted boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, id)
);

alter table public.habit_tasks enable row level security;

drop policy if exists habit_tasks_owner_all on public.habit_tasks;
create policy habit_tasks_owner_all on public.habit_tasks
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- 4. Daily Snapshots table (habit completion history & streaks)
create table if not exists public.daily_snapshots (
  user_id uuid not null references auth.users(id) on delete cascade,
  id uuid not null,
  list_id uuid,
  snapshot_date text not null,
  completion_fraction double precision not null default 0,
  completed_task_ids jsonb not null default '[]'::jsonb,
  total_tasks integer not null default 0,
  updated_at timestamptz not null default now(),
  primary key (user_id, id)
);

alter table public.daily_snapshots enable row level security;

drop policy if exists daily_snapshots_owner_all on public.daily_snapshots;
create policy daily_snapshots_owner_all on public.daily_snapshots
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- 5. Weekly Plans table
create table if not exists public.weekly_plans (
  user_id uuid primary key references auth.users(id) on delete cascade,
  focus_theme text,
  plan_json jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.weekly_plans enable row level security;

drop policy if exists weekly_plans_owner_all on public.weekly_plans;
create policy weekly_plans_owner_all on public.weekly_plans
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- 6. User Workspaces table (canonical cross-platform state + device metadata)
create table if not exists public.user_workspaces (
  user_id uuid primary key references auth.users(id) on delete cascade,
  app_data jsonb not null default '{}'::jsonb,
  source_device text not null default 'Device',
  updated_at timestamptz not null default now()
);

alter table public.user_workspaces enable row level security;

drop policy if exists user_workspaces_owner_all on public.user_workspaces;
create policy user_workspaces_owner_all on public.user_workspaces
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- 7. RPC: Sync & relational fan-out for Sortyd Workspace
create or replace function public.sync_sortyd_workspace(
  p_app_data jsonb,
  p_source_device text default 'Device'
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_list jsonb;
  v_task jsonb;
  v_snap jsonb;
  v_list_id uuid;
  v_task_id uuid;
  v_snap_id uuid;
  v_list_idx integer := 0;
  v_task_idx integer := 0;
begin
  if v_uid is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if jsonb_typeof(p_app_data) <> 'object' then
    raise exception 'Invalid workspace payload' using errcode = '22023';
  end if;

  -- Upsert canonical workspace
  insert into public.user_workspaces (user_id, app_data, source_device, updated_at)
  values (v_uid, p_app_data, coalesce(nullif(left(p_source_device, 80), ''), 'Device'), now())
  on conflict (user_id) do update set
    app_data = excluded.app_data,
    source_device = excluded.source_device,
    updated_at = now();

  -- Update active_list_id on profile if valid UUID
  begin
    if p_app_data ? 'activeListID' and jsonb_typeof(p_app_data->'activeListID') = 'string' then
      update public.profiles
      set active_list_id = nullif(p_app_data->>'activeListID', '')::uuid,
          updated_at = now()
      where id = v_uid;
    end if;
  exception when others then
    null;
  end;

  -- Fan out lists & tasks into relational tables for structured queries & dashboard visibility
  if jsonb_typeof(p_app_data->'lists') = 'array' then
    for v_list in select * from jsonb_array_elements(p_app_data->'lists')
    loop
      begin
        v_list_id := (v_list->>'id')::uuid;
        insert into public.habit_lists (
          user_id, id, name, emoji, is_archived, is_todo, is_weekly, sort_order, deleted, updated_at
        ) values (
          v_uid,
          v_list_id,
          coalesce(v_list->>'name', 'List'),
          coalesce(v_list->>'emoji', '📋'),
          coalesce((v_list->>'isArchived')::boolean, false),
          coalesce((v_list->>'isTodo')::boolean, false),
          coalesce((v_list->>'isWeekly')::boolean, false),
          v_list_idx,
          false,
          now()
        )
        on conflict (user_id, id) do update set
          name = excluded.name,
          emoji = excluded.emoji,
          is_archived = excluded.is_archived,
          is_todo = excluded.is_todo,
          is_weekly = excluded.is_weekly,
          sort_order = excluded.sort_order,
          deleted = false,
          updated_at = now();

        v_list_idx := v_list_idx + 1;
        v_task_idx := 0;

        if jsonb_typeof(v_list->'tasks') = 'array' then
          for v_task in select * from jsonb_array_elements(v_list->'tasks')
          loop
            begin
              v_task_id := (v_task->>'id')::uuid;
              insert into public.habit_tasks (
                user_id, id, list_id, title, is_completed, manually_completed, weight,
                reminder_is_one_time, notification_lead_minutes, duration_minutes,
                health_type, health_target, sort_order, deleted, updated_at
              ) values (
                v_uid,
                v_task_id,
                v_list_id,
                coalesce(v_task->>'title', ''),
                coalesce((v_task->>'isCompleted')::boolean, false),
                coalesce((v_task->>'manuallyCompleted')::boolean, false),
                coalesce((v_task->>'weight')::double precision, 0),
                coalesce((v_task->>'reminderIsOneTime')::boolean, false),
                coalesce((v_task->>'notificationLeadMinutes')::integer, 0),
                case when jsonb_typeof(v_task->'durationMinutes') = 'number' then (v_task->>'durationMinutes')::integer else null end,
                v_task->>'healthType',
                case when jsonb_typeof(v_task->'healthTarget') = 'number' then (v_task->>'healthTarget')::double precision else null end,
                v_task_idx,
                false,
                now()
              )
              on conflict (user_id, id) do update set
                list_id = excluded.list_id,
                title = excluded.title,
                is_completed = excluded.is_completed,
                manually_completed = excluded.manually_completed,
                weight = excluded.weight,
                reminder_is_one_time = excluded.reminder_is_one_time,
                notification_lead_minutes = excluded.notification_lead_minutes,
                duration_minutes = excluded.duration_minutes,
                health_type = excluded.health_type,
                health_target = excluded.health_target,
                sort_order = excluded.sort_order,
                deleted = false,
                updated_at = now();

              v_task_idx := v_task_idx + 1;
            exception when others then
              null;
            end;
          end loop;
        end if;
      exception when others then
        null;
      end;
    end loop;
  end if;

  -- Fan out daily snapshots
  if jsonb_typeof(p_app_data->'snapshots') = 'array' then
    for v_snap in select * from jsonb_array_elements(p_app_data->'snapshots')
    loop
      begin
        v_snap_id := (v_snap->>'id')::uuid;
        insert into public.daily_snapshots (
          user_id, id, list_id, snapshot_date, completion_fraction, completed_task_ids, total_tasks, updated_at
        ) values (
          v_uid,
          v_snap_id,
          nullif(coalesce(v_snap->>'listID', v_snap->>'listId', ''), '')::uuid,
          coalesce(v_snap->>'date', ''),
          coalesce((v_snap->>'completionFraction')::double precision, 0),
          coalesce(v_snap->'completedTaskIDs', v_snap->'completedTaskIds', '[]'::jsonb),
          coalesce((v_snap->>'totalTasks')::integer, 0),
          now()
        )
        on conflict (user_id, id) do update set
          completion_fraction = greatest(public.daily_snapshots.completion_fraction, excluded.completion_fraction),
          completed_task_ids = excluded.completed_task_ids,
          total_tasks = greatest(public.daily_snapshots.total_tasks, excluded.total_tasks),
          updated_at = now();
      exception when others then
        null;
      end;
    end loop;
  end if;

  -- Fan out weekly plan
  if jsonb_typeof(p_app_data->'weeklyPlan') = 'object' then
    insert into public.weekly_plans (user_id, focus_theme, plan_json, updated_at)
    values (
      v_uid,
      p_app_data->'weeklyPlan'->>'focusTheme',
      p_app_data->'weeklyPlan',
      now()
    )
    on conflict (user_id) do update set
      focus_theme = excluded.focus_theme,
      plan_json = excluded.plan_json,
      updated_at = now();
  end if;

  return p_app_data;
end;
$$;

create or replace function public.get_sortyd_workspace()
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(
    (select jsonb_build_object(
      'data', w.app_data,
      'updatedAt', w.updated_at,
      'sourceDevice', w.source_device
    ) from public.user_workspaces w where w.user_id = auth.uid()),
    jsonb_build_object('data', null, 'updatedAt', null, 'sourceDevice', null)
  );
$$;

create or replace function public.delete_my_sortyd_account()
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  delete from auth.users where id = auth.uid();
end;
$$;

-- 8. Service-role / Edge Worker RPC for syncing a verified user_id directly into all relational tables
create or replace function public.admin_sync_sortyd_workspace(
  p_user_id uuid,
  p_app_data jsonb,
  p_source_device text default 'Device'
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_list jsonb;
  v_task jsonb;
  v_snap jsonb;
  v_list_id uuid;
  v_task_id uuid;
  v_snap_id uuid;
  v_list_idx integer := 0;
  v_task_idx integer := 0;
  v_seen_lists uuid[] := array[]::uuid[];
  v_seen_tasks uuid[] := array[]::uuid[];
begin
  if p_user_id is null then
    raise exception 'p_user_id is required' using errcode = '22023';
  end if;

  if jsonb_typeof(p_app_data) <> 'object' then
    raise exception 'Invalid workspace payload' using errcode = '22023';
  end if;

  -- Upsert canonical workspace
  insert into public.user_workspaces (user_id, app_data, source_device, updated_at)
  values (p_user_id, p_app_data, coalesce(nullif(left(p_source_device, 80), ''), 'Device'), now())
  on conflict (user_id) do update set
    app_data = excluded.app_data,
    source_device = excluded.source_device,
    updated_at = now();

  -- Update active_list_id on profile if valid UUID
  begin
    if p_app_data ? 'activeListID' and jsonb_typeof(p_app_data->'activeListID') = 'string' then
      update public.profiles
      set active_list_id = nullif(p_app_data->>'activeListID', '')::uuid,
          updated_at = now()
      where id = p_user_id;
    end if;
  exception when others then
    null;
  end;

  -- Fan out lists & tasks into relational tables
  if jsonb_typeof(p_app_data->'lists') = 'array' then
    for v_list in select * from jsonb_array_elements(p_app_data->'lists')
    loop
      begin
        v_list_id := (v_list->>'id')::uuid;
        v_seen_lists := array_append(v_seen_lists, v_list_id);

        insert into public.habit_lists (
          user_id, id, name, emoji, is_archived, is_todo, is_weekly, sort_order, deleted, updated_at
        ) values (
          p_user_id,
          v_list_id,
          coalesce(v_list->>'name', 'List'),
          coalesce(v_list->>'emoji', '📋'),
          coalesce((v_list->>'isArchived')::boolean, false),
          coalesce((v_list->>'isTodo')::boolean, false),
          coalesce((v_list->>'isWeekly')::boolean, false),
          v_list_idx,
          false,
          now()
        )
        on conflict (user_id, id) do update set
          name = excluded.name,
          emoji = excluded.emoji,
          is_archived = excluded.is_archived,
          is_todo = excluded.is_todo,
          is_weekly = excluded.is_weekly,
          sort_order = excluded.sort_order,
          deleted = false,
          updated_at = now();

        v_list_idx := v_list_idx + 1;
        v_task_idx := 0;

        if jsonb_typeof(v_list->'tasks') = 'array' then
          for v_task in select * from jsonb_array_elements(v_list->'tasks')
          loop
            begin
              v_task_id := (v_task->>'id')::uuid;
              v_seen_tasks := array_append(v_seen_tasks, v_task_id);

              insert into public.habit_tasks (
                user_id, id, list_id, title, is_completed, manually_completed, weight,
                reminder_is_one_time, notification_lead_minutes, duration_minutes,
                health_type, health_target, sort_order, deleted, updated_at
              ) values (
                p_user_id,
                v_task_id,
                v_list_id,
                coalesce(v_task->>'title', ''),
                coalesce((v_task->>'isCompleted')::boolean, false),
                coalesce((v_task->>'manuallyCompleted')::boolean, false),
                coalesce((v_task->>'weight')::double precision, 0),
                coalesce((v_task->>'reminderIsOneTime')::boolean, false),
                coalesce((v_task->>'notificationLeadMinutes')::integer, 0),
                case when jsonb_typeof(v_task->'durationMinutes') = 'number' then (v_task->>'durationMinutes')::integer else null end,
                v_task->>'healthType',
                case when jsonb_typeof(v_task->'healthTarget') = 'number' then (v_task->>'healthTarget')::double precision else null end,
                v_task_idx,
                false,
                now()
              )
              on conflict (user_id, id) do update set
                list_id = excluded.list_id,
                title = excluded.title,
                is_completed = excluded.is_completed,
                manually_completed = excluded.manually_completed,
                weight = excluded.weight,
                reminder_is_one_time = excluded.reminder_is_one_time,
                notification_lead_minutes = excluded.notification_lead_minutes,
                duration_minutes = excluded.duration_minutes,
                health_type = excluded.health_type,
                health_target = excluded.health_target,
                sort_order = excluded.sort_order,
                deleted = false,
                updated_at = now();

              v_task_idx := v_task_idx + 1;
            exception when others then
              null;
            end;
          end loop;
        end if;
      exception when others then
        null;
      end;
    end loop;
  end if;

  -- Fan out daily snapshots
  if jsonb_typeof(p_app_data->'snapshots') = 'array' then
    for v_snap in select * from jsonb_array_elements(p_app_data->'snapshots')
    loop
      begin
        v_snap_id := (v_snap->>'id')::uuid;
        insert into public.daily_snapshots (
          user_id, id, list_id, snapshot_date, completion_fraction, completed_task_ids, total_tasks, updated_at
        ) values (
          p_user_id,
          v_snap_id,
          nullif(coalesce(v_snap->>'listID', v_snap->>'listId', ''), '')::uuid,
          coalesce(v_snap->>'date', ''),
          coalesce((v_snap->>'completionFraction')::double precision, 0),
          coalesce(v_snap->'completedTaskIDs', v_snap->'completedTaskIds', '[]'::jsonb),
          coalesce((v_snap->>'totalTasks')::integer, 0),
          now()
        )
        on conflict (user_id, id) do update set
          completion_fraction = greatest(public.daily_snapshots.completion_fraction, excluded.completion_fraction),
          completed_task_ids = excluded.completed_task_ids,
          total_tasks = greatest(public.daily_snapshots.total_tasks, excluded.total_tasks),
          updated_at = now();
      exception when others then
        null;
      end;
    end loop;
  end if;

  -- Fan out weekly plan
  if jsonb_typeof(p_app_data->'weeklyPlan') = 'object' then
    insert into public.weekly_plans (user_id, focus_theme, plan_json, updated_at)
    values (
      p_user_id,
      p_app_data->'weeklyPlan'->>'focusTheme',
      p_app_data->'weeklyPlan',
      now()
    )
    on conflict (user_id) do update set
      focus_theme = excluded.focus_theme,
      plan_json = excluded.plan_json,
      updated_at = now();
  end if;

  return p_app_data;
end;
$$;

revoke all on function public.sync_sortyd_workspace(jsonb, text), public.get_sortyd_workspace(), public.delete_my_sortyd_account() from public, anon;
grant execute on function public.sync_sortyd_workspace(jsonb, text), public.get_sortyd_workspace(), public.delete_my_sortyd_account() to authenticated;
revoke all on function public.admin_sync_sortyd_workspace(uuid, jsonb, text) from public, anon, authenticated;
grant execute on function public.admin_sync_sortyd_workspace(uuid, jsonb, text) to service_role;

commit;
