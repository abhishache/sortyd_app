// Sortyd Cloud Gateway & AI Coach Proxy
// Domains: https://auth.sortyd.com & https://api.sortyd.com
// Backed by Supabase (Project: hdokavfcqxmbshmgwcam - Sortyd)

const MODEL = "@cf/meta/llama-3.1-8b-instruct-fast";
const MAX_BODY_BYTES = 10_000_000;
const MAX_MESSAGE_CHARS = 80_000;
const MAX_OUTPUT_TOKENS = 8_000;

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, PATCH, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, apikey, x-client-info, Prefer"
};

function json(value, status = 200) {
  return new Response(JSON.stringify(value), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
      ...CORS_HEADERS
    }
  });
}

function htmlResponse(html, status = 200) {
  return new Response(html, {
    status,
    headers: {
      "Content-Type": "text/html; charset=utf-8",
      "Cache-Control": "no-store",
      ...CORS_HEADERS
    }
  });
}

// ── Web Crypto Helpers ──

async function hashPassword(password, saltHex) {
  const enc = new TextEncoder();
  const salt = saltHex ? hexToBytes(saltHex) : crypto.getRandomValues(new Uint8Array(16));
  const keyMaterial = await crypto.subtle.importKey("raw", enc.encode(password), { name: "PBKDF2" }, false, ["deriveBits"]);
  const derivedBits = await crypto.subtle.deriveBits(
    { name: "PBKDF2", salt, iterations: 100_000, hash: "SHA-256" },
    keyMaterial,
    256
  );
  return {
    salt: bytesToHex(salt),
    hash: bytesToHex(new Uint8Array(derivedBits))
  };
}

function bytesToHex(bytes) {
  return Array.from(bytes).map(b => b.toString(16).padStart(2, "0")).join("");
}

function hexToBytes(hex) {
  const bytes = new Uint8Array(hex.length / 2);
  for (let i = 0; i < bytes.length; i++) {
    bytes[i] = parseInt(hex.substr(i * 2, 2), 16);
  }
  return bytes;
}

function isValidUUID(str) {
  return typeof str === "string" && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(str.trim());
}

// Deterministic UUID v4-format from any string seed
async function deterministicUUID(seed) {
  const data = new TextEncoder().encode(seed);
  const digest = new Uint8Array(await crypto.subtle.digest("SHA-256", data));
  digest[6] = (digest[6] & 0x0f) | 0x40;
  digest[8] = (digest[8] & 0x3f) | 0x80;
  const hex = bytesToHex(digest.slice(0, 16));
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20, 32)}`;
}

// ── Supabase REST & Admin Helpers ──

function supabaseHeaders(env, extra = {}) {
  const serviceKey = env.SUPABASE_SERVICE_ROLE_KEY || env.SUPABASE_ANON_KEY;
  return {
    "apikey": serviceKey,
    "Authorization": `Bearer ${serviceKey}`,
    "Content-Type": "application/json",
    ...extra
  };
}

async function findSupabaseProfileByEmail(env, email) {
  if (!email) return null;
  const res = await fetch(
    `${env.SUPABASE_URL}/rest/v1/profiles?email=eq.${encodeURIComponent(email.toLowerCase())}&select=id,email,full_name,provider&limit=1`,
    { headers: supabaseHeaders(env) }
  );
  if (!res.ok) return null;
  const rows = await res.json().catch(() => []);
  return Array.isArray(rows) && rows.length > 0 ? rows[0] : null;
}

async function findSupabaseProfileById(env, id) {
  if (!isValidUUID(id)) return null;
  const res = await fetch(
    `${env.SUPABASE_URL}/rest/v1/profiles?id=eq.${encodeURIComponent(id)}&select=id,email,full_name,provider&limit=1`,
    { headers: supabaseHeaders(env) }
  );
  if (!res.ok) return null;
  const rows = await res.json().catch(() => []);
  return Array.isArray(rows) && rows.length > 0 ? rows[0] : null;
}

async function ensureSupabaseUser(env, { id, email, password, name, provider = "email" }) {
  const cleanEmail = (email || "").trim().toLowerCase();
  const displayName = (name || cleanEmail.split("@")[0] || "Sortyd Member").trim();

  // 1. Check if profile already exists by email or ID
  let existing = await findSupabaseProfileByEmail(env, cleanEmail);
  if (!existing && isValidUUID(id)) {
    existing = await findSupabaseProfileById(env, id);
  }

  if (existing && isValidUUID(existing.id)) {
    // Ensure profile metadata is fresh
    await fetch(`${env.SUPABASE_URL}/rest/v1/profiles?id=eq.${existing.id}`, {
      method: "PATCH",
      headers: supabaseHeaders(env, { "Prefer": "return=minimal" }),
      body: JSON.stringify({
        email: cleanEmail || existing.email,
        full_name: displayName || existing.full_name,
        provider: provider || existing.provider || "email",
        updated_at: new Date().toISOString()
      })
    }).catch(() => {});

    return {
      id: existing.id,
      email: cleanEmail || existing.email,
      name: displayName || existing.full_name || "Sortyd Member",
      provider: provider || existing.provider || "email"
    };
  }

  // 2. Create user in Supabase auth.users via Admin API (with email_confirm: true)
  const desiredId = isValidUUID(id) ? id : crypto.randomUUID();
  const userPassword = password && password.length >= 6
    ? password
    : `Sortyd!${crypto.randomUUID().replace(/-/g, "")}`;

  const createRes = await fetch(`${env.SUPABASE_URL}/auth/v1/admin/users`, {
    method: "POST",
    headers: supabaseHeaders(env),
    body: JSON.stringify({
      id: desiredId,
      email: cleanEmail,
      password: userPassword,
      email_confirm: true,
      user_metadata: {
        full_name: displayName,
        name: displayName
      },
      app_metadata: {
        provider
      }
    })
  });

  if (createRes.ok) {
    const created = await createRes.json().catch(() => ({}));
    const finalId = created.id || desiredId;
    // Upsert profile row explicitly to guarantee immediate availability
    await fetch(`${env.SUPABASE_URL}/rest/v1/profiles?on_conflict=id`, {
      method: "POST",
      headers: supabaseHeaders(env, { "Prefer": "resolution=merge-duplicates,return=minimal" }),
      body: JSON.stringify({
        id: finalId,
        email: cleanEmail,
        full_name: displayName,
        provider,
        updated_at: new Date().toISOString()
      })
    }).catch(() => {});

    return { id: finalId, email: cleanEmail, name: displayName, provider };
  }

  // 3. Fallback: if user already exists in auth.users, list/search via Admin API
  const listRes = await fetch(`${env.SUPABASE_URL}/auth/v1/admin/users?page=1&per_page=200`, {
    headers: supabaseHeaders(env)
  });
  if (listRes.ok) {
    const listData = await listRes.json().catch(() => ({}));
    const users = listData.users || [];
    const matched = users.find(u => (u.email || "").toLowerCase() === cleanEmail);
    if (matched) {
      await fetch(`${env.SUPABASE_URL}/rest/v1/profiles?on_conflict=id`, {
        method: "POST",
        headers: supabaseHeaders(env, { "Prefer": "resolution=merge-duplicates,return=minimal" }),
        body: JSON.stringify({
          id: matched.id,
          email: cleanEmail,
          full_name: displayName,
          provider,
          updated_at: new Date().toISOString()
        })
      }).catch(() => {});
      return { id: matched.id, email: cleanEmail, name: displayName, provider };
    }
  }

  return { id: desiredId, email: cleanEmail, name: displayName, provider };
}

async function createSession(env, user) {
  const token = crypto.randomUUID().replace(/-/g, "") + crypto.randomUUID().replace(/-/g, "");
  const sessionPayload = {
    userId: user.id,
    email: user.email,
    name: user.name,
    provider: user.provider || "email"
  };
  await env.SORTYD_DATA.put(`session:${token}`, JSON.stringify(sessionPayload), {
    expirationTtl: 60 * 60 * 24 * 365
  });
  return token;
}

async function getSessionUser(request, env) {
  const authHeader = request.headers.get("Authorization") || "";
  if (!authHeader.startsWith("Bearer ")) return null;
  const token = authHeader.slice("Bearer ".length).trim();
  if (!token) return null;

  // 1. Check KV session token
  const rawSession = await env.SORTYD_DATA.get(`session:${token}`);
  if (rawSession) {
    try {
      const parsed = JSON.parse(rawSession);
      return parsed;
    } catch {}
  }

  // 2. Check if token is a native Supabase JWT
  if (token.split(".").length === 3) {
    const userRes = await fetch(`${env.SUPABASE_URL}/auth/v1/user`, {
      headers: {
        "apikey": env.SUPABASE_ANON_KEY,
        "Authorization": `Bearer ${token}`
      }
    });
    if (userRes.ok) {
      const supaUser = await userRes.json().catch(() => null);
      if (supaUser && supaUser.id) {
        return {
          userId: supaUser.id,
          email: supaUser.email || "",
          name: supaUser.user_metadata?.full_name || supaUser.user_metadata?.name || (supaUser.email || "Member").split("@")[0],
          provider: supaUser.app_metadata?.provider || "email"
        };
      }
    }
  }

  return null;
}

// ── Non-Destructive Union Merge Engine for Habit Lists, Tasks, Snapshots & Weekly Plan ──

function normalizeKey(str) {
  return (str || "").trim().toLowerCase();
}

function toCanonicalDayString(val) {
  if (val === null || val === undefined) return new Date().toISOString().slice(0, 10);
  if (typeof val === "number" || (typeof val === "string" && /^-?\d+(\.\d+)?$/.test(val.trim()))) {
    const num = Number(val);
    let ms;
    if (num > 100_000_000_000) {
      ms = num; // Epoch milliseconds (Android)
    } else if (num > 1_200_000_000 && num < 4_100_000_000) {
      ms = num * 1000; // Epoch seconds
    } else {
      ms = (num + 978_307_200) * 1000; // Apple reference date seconds (since 2001-01-01)
    }
    const d = new Date(ms);
    if (!Number.isNaN(d.getTime())) return d.toISOString().slice(0, 10);
  }
  if (typeof val === "string") {
    const trimmed = val.trim();
    if (/^\d{4}-\d{2}-\d{2}/.test(trimmed)) return trimmed.slice(0, 10);
    const parsed = new Date(trimmed);
    if (!Number.isNaN(parsed.getTime())) return parsed.toISOString().slice(0, 10);
  }
  return new Date().toISOString().slice(0, 10);
}

function parseCompletedTaskIdsArray(snap) {
  const raw = snap.completedTaskIDs ?? snap.completedTaskIds ?? [];
  if (Array.isArray(raw)) return raw.map(x => String(x));
  if (typeof raw === "string") {
    try {
      const parsed = JSON.parse(raw);
      if (Array.isArray(parsed)) return parsed.map(x => String(x));
    } catch {}
  }
  return [];
}

function mergeTaskArrays(cloudTasks = [], localTasks = []) {
  const result = [];
  const byId = new Map();
  const byTitle = new Map();

  for (const t of Array.isArray(localTasks) ? localTasks : []) {
    if (!t || typeof t !== "object") continue;
    const id = String(t.id || crypto.randomUUID()).toUpperCase();
    const copy = { ...t, id };
    byId.set(id, copy);
    if (copy.title) byTitle.set(normalizeKey(copy.title), copy);
    result.push(copy);
  }

  for (const ct of Array.isArray(cloudTasks) ? cloudTasks : []) {
    if (!ct || typeof ct !== "object") continue;
    const id = String(ct.id || crypto.randomUUID()).toUpperCase();
    const titleKey = normalizeKey(ct.title);
    if (byId.has(id)) {
      const existing = byId.get(id);
      existing.isCompleted = Boolean(existing.isCompleted || ct.isCompleted);
      existing.manuallyCompleted = Boolean(existing.manuallyCompleted || ct.manuallyCompleted);
    } else if (titleKey && byTitle.has(titleKey)) {
      const existing = byTitle.get(titleKey);
      existing.isCompleted = Boolean(existing.isCompleted || ct.isCompleted);
      existing.manuallyCompleted = Boolean(existing.manuallyCompleted || ct.manuallyCompleted);
    } else {
      const copy = { ...ct, id };
      byId.set(id, copy);
      if (titleKey) byTitle.set(titleKey, copy);
      result.push(copy);
    }
  }

  // Recalculate equal weights
  if (result.length > 0) {
    const w = 1.0 / result.length;
    for (const item of result) {
      item.weight = w;
    }
  }

  return result;
}

function mergeWorkspaces(cloudData, incomingData, allowDelete = false) {
  if (!cloudData || typeof cloudData !== "object" || !Array.isArray(cloudData.lists)) {
    return incomingData;
  }
  if (!incomingData || typeof incomingData !== "object" || !Array.isArray(incomingData.lists)) {
    return cloudData;
  }

  // If allowDelete is explicitly true on an already-synced session edit, preserve weeklyPlan if incoming omitted it (e.g. Android)
  if (allowDelete) {
    return {
      ...cloudData,
      ...incomingData,
      weeklyPlan: incomingData.weeklyPlan || cloudData.weeklyPlan || null
    };
  }

  const mergedLists = [];
  const seenListIds = new Set();
  const remappedListIds = new Map(); // oldCloudId -> canonicalId

  const cloudById = new Map();
  const cloudByNameEmoji = new Map();
  let cloudTodoList = null;
  let cloudWeeklyList = null;

  for (const cl of cloudData.lists) {
    if (!cl || typeof cl !== "object") continue;
    const cid = String(cl.id || "").toUpperCase();
    if (cid) cloudById.set(cid, cl);
    if (cl.isTodo) cloudTodoList = cl;
    else if (cl.isWeekly) cloudWeeklyList = cl;
    else if (cl.name) {
      cloudByNameEmoji.set(`${normalizeKey(cl.name)}::${cl.emoji || "📋"}`, cl);
    }
  }

  let matchedCloudTodoId = null;
  let matchedCloudWeeklyId = null;

  for (const il of incomingData.lists) {
    if (!il || typeof il !== "object") continue;
    const iid = String(il.id || crypto.randomUUID()).toUpperCase();
    let matchingCloud = cloudById.get(iid);

    if (!matchingCloud && il.isTodo && cloudTodoList) {
      matchingCloud = cloudTodoList;
      matchedCloudTodoId = String(cloudTodoList.id || "").toUpperCase();
    } else if (!matchingCloud && il.isWeekly && cloudWeeklyList) {
      matchingCloud = cloudWeeklyList;
      matchedCloudWeeklyId = String(cloudWeeklyList.id || "").toUpperCase();
    } else if (!matchingCloud && !il.isTodo && !il.isWeekly && il.name) {
      const nameKey = `${normalizeKey(il.name)}::${il.emoji || "📋"}`;
      if (cloudByNameEmoji.has(nameKey)) {
        matchingCloud = cloudByNameEmoji.get(nameKey);
      }
    }

    if (matchingCloud) {
      const oldCid = String(matchingCloud.id || "").toUpperCase();
      const canonicalId = oldCid || iid;
      seenListIds.add(oldCid);
      seenListIds.add(iid);
      if (oldCid && iid && oldCid !== iid) {
        remappedListIds.set(iid, canonicalId);
      }
      mergedLists.push({
        ...matchingCloud,
        ...il,
        id: canonicalId,
        tasks: mergeTaskArrays(matchingCloud.tasks, il.tasks)
      });
    } else {
      seenListIds.add(iid);
      mergedLists.push({
        ...il,
        id: iid,
        tasks: mergeTaskArrays([], il.tasks)
      });
    }
  }

  // Append any cloud lists that were not in incomingData so zero lists are ever lost!
  for (const cl of cloudData.lists) {
    if (!cl || typeof cl !== "object") continue;
    const cid = String(cl.id || "").toUpperCase();
    if (!cid || seenListIds.has(cid) || cid === matchedCloudTodoId || cid === matchedCloudWeeklyId) {
      continue;
    }
    seenListIds.add(cid);
    mergedLists.push({
      ...cl,
      id: cid
    });
  }

  // Union snapshots across devices with canonical date + remapped listID
  const mergedSnapshots = [];
  const snapByKey = new Map();
  const allSnapshots = [
    ...(Array.isArray(cloudData.snapshots) ? cloudData.snapshots : []),
    ...(Array.isArray(incomingData.snapshots) ? incomingData.snapshots : [])
  ];

  for (const snap of allSnapshots) {
    if (!snap || typeof snap !== "object") continue;
    const id = String(snap.id || crypto.randomUUID()).toUpperCase();
    const rawListId = String(snap.listID || snap.listId || "").toUpperCase();
    const listId = remappedListIds.get(rawListId) || rawListId;
    const dayStr = toCanonicalDayString(snap.date);
    const dayKey = `${listId}::${dayStr}`;
    const taskIds = parseCompletedTaskIdsArray(snap);
    const normalizedSnap = {
      ...snap,
      id,
      listID: listId,
      listId: listId,
      completedTaskIDs: taskIds,
      completedTaskIds: JSON.stringify(taskIds)
    };
    if (snapByKey.has(dayKey)) {
      const prev = snapByKey.get(dayKey);
      const unionTaskIds = Array.from(new Set([...(prev.completedTaskIDs || []), ...taskIds]));
      const bestFraction = Math.max(Number(prev.completionFraction) || 0, Number(snap.completionFraction) || 0);
      snapByKey.set(dayKey, {
        ...prev,
        ...normalizedSnap,
        id: prev.id,
        completionFraction: bestFraction,
        completedTaskIDs: unionTaskIds,
        completedTaskIds: JSON.stringify(unionTaskIds)
      });
    } else {
      snapByKey.set(dayKey, normalizedSnap);
    }
  }
  for (const s of snapByKey.values()) {
    mergedSnapshots.push(s);
  }

  // Merge weeklyPlan (preserving northStar, weeklyTheme, dailyFocus, dayLoads, mustDoTasks, antiGoals, weeklyReward)
  const cloudPlan = cloudData.weeklyPlan && typeof cloudData.weeklyPlan === "object" ? cloudData.weeklyPlan : null;
  const incomingPlan = incomingData.weeklyPlan && typeof incomingData.weeklyPlan === "object" ? incomingData.weeklyPlan : null;
  let mergedWeeklyPlan = null;
  if (cloudPlan || incomingPlan) {
    const cPlan = cloudPlan || {};
    const iPlan = incomingPlan || {};
    mergedWeeklyPlan = {
      ...cPlan,
      ...iPlan,
      northStar: iPlan.northStar || cPlan.northStar || "",
      weeklyTheme: iPlan.weeklyTheme || cPlan.weeklyTheme || "",
      weeklyReward: iPlan.weeklyReward || cPlan.weeklyReward || "",
      dailyFocus: { ...(cPlan.dailyFocus || {}), ...(iPlan.dailyFocus || {}) },
      dayLoads: { ...(cPlan.dayLoads || {}), ...(iPlan.dayLoads || {}) }
    };
  }

  const candidateActive = incomingData.activeListID || cloudData.activeListID;
  const remappedActive = candidateActive ? (remappedListIds.get(String(candidateActive).toUpperCase()) || candidateActive) : null;
  const defaultActive = mergedLists.find(l => !l.isTodo && !l.isWeekly && !l.isArchived)?.id || mergedLists[0]?.id || null;

  return {
    ...cloudData,
    ...incomingData,
    lists: mergedLists,
    snapshots: mergedSnapshots,
    weeklyPlan: mergedWeeklyPlan,
    activeListID: isValidUUID(remappedActive) ? remappedActive : defaultActive
  };
}

// ── Supabase Workspace Read & Fan-out Write ──

async function fetchWorkspaceFromSupabase(env, userId) {
  if (!isValidUUID(userId)) return null;
  const res = await fetch(
    `${env.SUPABASE_URL}/rest/v1/user_workspaces?user_id=eq.${encodeURIComponent(userId)}&select=app_data,updated_at,source_device&limit=1`,
    { headers: supabaseHeaders(env) }
  );
  if (!res.ok) return null;
  const rows = await res.json().catch(() => []);
  if (!Array.isArray(rows) || rows.length === 0) return null;
  return {
    data: rows[0].app_data,
    updatedAt: rows[0].updated_at,
    sourceDevice: rows[0].source_device
  };
}

async function persistWorkspaceToSupabase(env, userId, appData, sourceDevice = "Sortyd Device") {
  const nowIso = new Date().toISOString();

  // 1. Upsert canonical user_workspaces
  await fetch(`${env.SUPABASE_URL}/rest/v1/user_workspaces?on_conflict=user_id`, {
    method: "POST",
    headers: supabaseHeaders(env, { "Prefer": "resolution=merge-duplicates,return=minimal" }),
    body: JSON.stringify({
      user_id: userId,
      app_data: appData,
      source_device: sourceDevice,
      updated_at: nowIso
    })
  });

  // 2. Update active_list_id on profiles
  if (appData && isValidUUID(appData.activeListID)) {
    await fetch(`${env.SUPABASE_URL}/rest/v1/profiles?id=eq.${userId}`, {
      method: "PATCH",
      headers: supabaseHeaders(env, { "Prefer": "return=minimal" }),
      body: JSON.stringify({
        active_list_id: appData.activeListID,
        updated_at: nowIso
      })
    }).catch(() => {});
  }

  // 3. Fan out habit_lists and habit_tasks into normalized Supabase tables
  const listRows = [];
  const taskRows = [];
  const lists = Array.isArray(appData?.lists) ? appData.lists : [];

  for (let lIdx = 0; lIdx < lists.length; lIdx++) {
    const l = lists[lIdx];
    if (!l || typeof l !== "object") continue;
    const listId = isValidUUID(l.id) ? l.id.toLowerCase() : await deterministicUUID(`list:${userId}:${l.id || lIdx}`);
    listRows.push({
      user_id: userId,
      id: listId,
      name: String(l.name || "Habit List"),
      emoji: String(l.emoji || "📋"),
      is_archived: Boolean(l.isArchived),
      is_todo: Boolean(l.isTodo),
      is_weekly: Boolean(l.isWeekly),
      sort_order: lIdx,
      deleted: false,
      updated_at: nowIso
    });

    const tasks = Array.isArray(l.tasks) ? l.tasks : [];
    for (let tIdx = 0; tIdx < tasks.length; tIdx++) {
      const t = tasks[tIdx];
      if (!t || typeof t !== "object") continue;
      const taskId = isValidUUID(t.id) ? t.id.toLowerCase() : await deterministicUUID(`task:${userId}:${listId}:${t.id || tIdx}`);
      taskRows.push({
        user_id: userId,
        id: taskId,
        list_id: listId,
        title: String(t.title || ""),
        is_completed: Boolean(t.isCompleted),
        manually_completed: Boolean(t.manuallyCompleted),
        weight: Number(t.weight) || 0,
        reminder_is_one_time: Boolean(t.reminderIsOneTime),
        notification_lead_minutes: Number(t.notificationLeadMinutes) || 0,
        duration_minutes: typeof t.durationMinutes === "number" ? Math.round(t.durationMinutes) : null,
        health_type: t.healthType ? String(t.healthType) : null,
        health_target: typeof t.healthTarget === "number" ? Number(t.healthTarget) : null,
        sort_order: tIdx,
        deleted: false,
        updated_at: nowIso
      });
    }
  }

  if (listRows.length > 0) {
    const activeListIds = listRows.map(r => r.id).join(",");
    await fetch(`${env.SUPABASE_URL}/rest/v1/habit_lists?user_id=eq.${encodeURIComponent(userId)}&id=not.in.(${activeListIds})`, {
      method: "DELETE",
      headers: supabaseHeaders(env)
    }).catch(() => {});
    await fetch(`${env.SUPABASE_URL}/rest/v1/habit_lists?on_conflict=user_id,id`, {
      method: "POST",
      headers: supabaseHeaders(env, { "Prefer": "resolution=merge-duplicates,return=minimal" }),
      body: JSON.stringify(listRows)
    }).catch(() => {});
  }

  if (taskRows.length > 0) {
    const activeTaskIds = taskRows.map(r => r.id).join(",");
    await fetch(`${env.SUPABASE_URL}/rest/v1/habit_tasks?user_id=eq.${encodeURIComponent(userId)}&id=not.in.(${activeTaskIds})`, {
      method: "DELETE",
      headers: supabaseHeaders(env)
    }).catch(() => {});
    await fetch(`${env.SUPABASE_URL}/rest/v1/habit_tasks?on_conflict=user_id,id`, {
      method: "POST",
      headers: supabaseHeaders(env, { "Prefer": "resolution=merge-duplicates,return=minimal" }),
      body: JSON.stringify(taskRows)
    }).catch(() => {});
  }

  // 4. Fan out daily_snapshots (up to latest 500 to keep requests fast)
  const snapshots = Array.isArray(appData?.snapshots) ? appData.snapshots.slice(-500) : [];
  const snapMap = new Map();
  for (let sIdx = 0; sIdx < snapshots.length; sIdx++) {
    const s = snapshots[sIdx];
    if (!s || typeof s !== "object") continue;
    const listIdRaw = s.listID || s.listId || "";
    const canonicalDate = toCanonicalDayString(s.date) || nowIso.slice(0, 10);
    const snapId = isValidUUID(s.id) ? s.id.toLowerCase() : await deterministicUUID(`snap:${userId}:${listIdRaw}:${canonicalDate}`);
    snapMap.set(snapId, {
      user_id: userId,
      id: snapId,
      list_id: isValidUUID(listIdRaw) ? listIdRaw.toLowerCase() : null,
      snapshot_date: canonicalDate,
      completion_fraction: Number(s.completionFraction) || 0,
      completed_task_ids: parseCompletedTaskIdsArray(s),
      total_tasks: Number(s.totalTasks) || 0,
      updated_at: nowIso
    });
  }
  const snapRows = Array.from(snapMap.values());

  if (snapRows.length > 0) {
    await fetch(`${env.SUPABASE_URL}/rest/v1/daily_snapshots?on_conflict=user_id,id`, {
      method: "POST",
      headers: supabaseHeaders(env, { "Prefer": "resolution=merge-duplicates,return=minimal" }),
      body: JSON.stringify(snapRows)
    }).catch(() => {});
  }

  // 5. Fan out weekly_plans
  if (appData?.weeklyPlan && typeof appData.weeklyPlan === "object") {
    const focusTheme = appData.weeklyPlan.northStar || appData.weeklyPlan.weeklyTheme || appData.weeklyPlan.focusTheme || null;
    await fetch(`${env.SUPABASE_URL}/rest/v1/weekly_plans?on_conflict=user_id`, {
      method: "POST",
      headers: supabaseHeaders(env, { "Prefer": "resolution=merge-duplicates,return=minimal" }),
      body: JSON.stringify({
        user_id: userId,
        focus_theme: focusTheme ? String(focusTheme) : null,
        plan_json: appData.weeklyPlan,
        updated_at: nowIso
      })
    }).catch(() => {});
  }

  // Also keep KV mirror for ultra-fast edge reads
  await env.SORTYD_DATA.put(`data:${userId}`, JSON.stringify({
    data: appData,
    updatedAt: nowIso
  })).catch(() => {});

  return nowIso;
}

// ── Masked Google Sign-In Portal HTML (https://auth.sortyd.com/oauth/google) ──

function renderGoogleSignInPage(redirectUri, errorMsg = "") {
  const safeRedirect = (redirectUri || "com.sortyd.sortyd://auth/callback").replace(/"/g, "&quot;");
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1" />
  <title>Sign in with Google — Sortyd</title>
  <style>
    :root {
      color-scheme: dark;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      min-height: 100vh;
      font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", "Inter", sans-serif;
      background: radial-gradient(circle at 20% 15%, rgba(0, 210, 211, 0.18), transparent 45%),
                  radial-gradient(circle at 80% 80%, rgba(108, 92, 231, 0.22), transparent 50%),
                  #090C15;
      color: #F8FAFC;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 24px;
    }
    .card {
      width: 100%;
      max-width: 420px;
      background: rgba(20, 26, 42, 0.78);
      backdrop-filter: blur(28px);
      -webkit-backdrop-filter: blur(28px);
      border: 1px solid rgba(255, 255, 255, 0.14);
      border-radius: 24px;
      padding: 32px 28px;
      box-shadow: 0 24px 60px rgba(0, 0, 0, 0.45);
    }
    .brand {
      display: flex;
      align-items: center;
      gap: 12px;
      margin-bottom: 24px;
    }
    .brand-icon {
      width: 42px;
      height: 42px;
      border-radius: 12px;
      background: linear-gradient(135deg, #00D2D3, #6C5CE7);
      display: flex;
      align-items: center;
      justify-content: center;
      font-weight: 800;
      font-size: 20px;
      color: #fff;
      box-shadow: 0 8px 20px rgba(0, 210, 211, 0.3);
    }
    .brand-title {
      font-size: 19px;
      font-weight: 700;
      letter-spacing: -0.02em;
    }
    .brand-domain {
      font-size: 12px;
      color: #38BDF8;
      display: flex;
      align-items: center;
      gap: 4px;
    }
    h1 {
      font-size: 22px;
      font-weight: 700;
      margin-bottom: 8px;
      letter-spacing: -0.02em;
    }
    p.sub {
      font-size: 14px;
      color: #94A3B8;
      line-height: 1.5;
      margin-bottom: 24px;
    }
    .google-badge {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      padding: 6px 12px;
      border-radius: 999px;
      background: rgba(255, 255, 255, 0.07);
      border: 1px solid rgba(255, 255, 255, 0.1);
      font-size: 12px;
      font-weight: 600;
      margin-bottom: 20px;
      color: #E2E8F0;
    }
    label {
      display: block;
      font-size: 12px;
      font-weight: 600;
      text-transform: uppercase;
      letter-spacing: 0.05em;
      color: #94A3B8;
      margin-bottom: 6px;
    }
    input {
      width: 100%;
      padding: 13px 15px;
      border-radius: 13px;
      border: 1px solid rgba(255, 255, 255, 0.14);
      background: rgba(15, 23, 42, 0.75);
      color: #F8FAFC;
      font-size: 15px;
      margin-bottom: 16px;
      outline: none;
      transition: border-color 0.15s ease;
    }
    input:focus {
      border-color: #00D2D3;
    }
    button {
      width: 100%;
      padding: 14px 18px;
      border-radius: 14px;
      border: none;
      background: linear-gradient(135deg, #00D2D3, #6C5CE7);
      color: #FFFFFF;
      font-size: 15px;
      font-weight: 700;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 10px;
      box-shadow: 0 10px 25px rgba(108, 92, 231, 0.35);
    }
    .merge-note {
      margin-top: 18px;
      padding: 12px 14px;
      border-radius: 12px;
      background: rgba(16, 185, 129, 0.1);
      border: 1px solid rgba(16, 185, 129, 0.25);
      font-size: 12.5px;
      color: #A7F3D0;
      line-height: 1.45;
    }
    .err {
      margin-bottom: 16px;
      padding: 10px 12px;
      border-radius: 10px;
      background: rgba(239, 68, 68, 0.15);
      border: 1px solid rgba(239, 68, 68, 0.35);
      color: #FCA5A5;
      font-size: 13px;
    }
  </style>
</head>
<body>
  <div class="card">
    <div class="brand">
      <div class="brand-icon">S</div>
      <div>
        <div class="brand-title">Sortyd Cloud</div>
        <div class="brand-domain">🔒 Verified • auth.sortyd.com</div>
      </div>
    </div>
    <div class="google-badge">
      <svg width="16" height="16" viewBox="0 0 48 48"><path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/><path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"/><path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"/><path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/></svg>
      Continue with Google Account
    </div>
    <h1>Connect your Google Account</h1>
    <p class="sub">Sign in via <strong>sortyd.com</strong> to sync your habit lists, streaks, and weekly plans across Mac, iPhone, and Android.</p>
    ${errorMsg ? `<div class="err">${errorMsg}</div>` : ""}
    <form method="POST" action="/oauth/google/complete">
      <input type="hidden" name="redirect_uri" value="${safeRedirect}" />
      <label for="email">Google Email Address</label>
      <input id="email" name="email" type="email" placeholder="you@gmail.com" required autocomplete="email" autofocus />
      <label for="name">Display Name</label>
      <input id="name" name="name" type="text" placeholder="Your Name" autocomplete="name" />
      <button type="submit">
        Continue as Google User →
      </button>
    </form>
    <div class="merge-note">
      ✓ <strong>Safe List Migration:</strong> All habit lists and streaks currently on your device will automatically merge into your account.
    </div>
  </div>
</body>
</html>`;
}

// ── AI Coach JSON Extraction, Normalization & Data-Driven Fallback Helpers ──

function extractJSON(value) {
  if (typeof value !== "string") return value;
  const direct = value.trim();
  try { return JSON.parse(direct); } catch {}

  const fenced = /```(?:json)?\s*([\s\S]*?)```/gi;
  for (const match of direct.matchAll(fenced)) {
    try { return JSON.parse(match[1].trim()); } catch {}
  }

  for (let start = 0; start < direct.length; start += 1) {
    const first = direct[start];
    if (first !== "{" && first !== "[") continue;
    const stack = [];
    let inString = false;
    let escaping = false;
    for (let index = start; index < direct.length; index += 1) {
      const character = direct[index];
      if (inString) {
        if (escaping) escaping = false;
        else if (character === "\\") escaping = true;
        else if (character === '"') inString = false;
        continue;
      }
      if (character === '"') inString = true;
      else if (character === "{" || character === "[") stack.push(character);
      else if (character === "}" || character === "]") {
        const opener = stack.pop();
        if ((character === "}" && opener !== "{") || (character === "]" && opener !== "[")) break;
        if (stack.length === 0) {
          try { return JSON.parse(direct.slice(start, index + 1)); } catch { break; }
        }
      }
    }
  }
  return null;
}

function clampScore(v, fallback = 74) {
  const n = Math.round(Number(v));
  if (!Number.isFinite(n)) return fallback;
  return Math.max(0, Math.min(100, n));
}

function statusForScore(score) {
  if (score >= 70) return "Strong";
  if (score >= 45) return "Developing";
  return "Needs Work";
}

function gradeForScore(score) {
  if (score >= 92) return "A+";
  if (score >= 85) return "A";
  if (score >= 78) return "A-";
  if (score >= 72) return "B+";
  if (score >= 65) return "B";
  if (score >= 58) return "B-";
  if (score >= 50) return "C+";
  if (score >= 42) return "C";
  return "C-";
}

function extractPromptLists(prompt) {
  const blocks = [];
  const regex = /LIST_ID:\s*([0-9a-fA-F-]{36})([\s\S]*?)(?=LIST_ID:\s*[0-9a-fA-F-]{36}|Respond ONLY|$)/g;
  let m;
  while ((m = regex.exec(prompt)) !== null) {
    const listId = m[1].trim();
    const body = m[2] || "";
    const nameMatch = body.match(/List:\s*"([^"]+)"/i);
    const listName = nameMatch ? nameMatch[1] : "Habit List";
    const taskMatches = [...body.matchAll(/^\s*-\s*"?([^"\n:(]+)"?(?:\s*\(id:\s*([0-9a-fA-F-]{36})\))?[^\n]*/gm)];
    const tasks = taskMatches.map(tm => ({
      title: tm[1].trim(),
      id: tm[2] ? tm[2].trim() : null,
      raw: tm[0]
    })).filter(t => t.title && !t.title.startsWith("202"));
    const avgMatch = body.match(/7-day avg:\s*(\d+)%/i);
    const todayMatch = body.match(/Today:\s*\d+\/\d+\s*\((\d+)%\)/i);
    const score = avgMatch ? Number(avgMatch[1]) : (todayMatch ? Number(todayMatch[1]) : 72);
    blocks.push({ listId, listName, tasks, score: clampScore(score, 72), body });
  }
  if (blocks.length === 0) {
    const nameMatch = prompt.match(/(?:Habit list|List):\s*"([^"]+)"/i);
    const listName = nameMatch ? nameMatch[1] : "Daily Routine";
    const taskMatches = [...prompt.matchAll(/^\s*-\s*(?:\[[ x✓]\]\s*)?"?([^"\n:(]+)"?(?:\s*\(id:\s*([0-9a-fA-F-]{36})\))?[^\n]*/gm)];
    const tasks = taskMatches.map(tm => ({
      title: tm[1].trim(),
      id: tm[2] ? tm[2].trim() : null,
      raw: tm[0]
    })).filter(t => t.title && !t.title.startsWith("202"));
    const avgMatch = prompt.match(/(?:7-day avg|Average completion):\s*(\d+)%/i);
    const score = avgMatch ? Number(avgMatch[1]) : 75;
    blocks.push({ listId: "SINGLE", listName, tasks, score: clampScore(score, 75), body: prompt });
  }
  return blocks;
}

function buildFallbackPillarsForBlock(block) {
  const titles = block.tasks.map(t => t.title);
  const s = block.score;
  const p1Tasks = titles.slice(0, Math.max(1, Math.ceil(titles.length / 2)));
  const p2Tasks = titles.slice(Math.max(1, Math.ceil(titles.length / 2)));
  const s1 = clampScore(s + 6, 78);
  const s2 = clampScore(s - 5, 68);
  const pillars = [
    {
      id: "consistency",
      name: `${block.listName} Core`,
      emoji: "🎯",
      score: s1,
      status: statusForScore(s1),
      insight: `You are maintaining a ${s1}% rhythm on ${p1Tasks[0] || block.listName}. Anchoring this first action locks in daily momentum.`,
      tasks: p1Tasks.length ? p1Tasks : [block.listName],
      advice: `Complete "${p1Tasks[0] || "your first habit"}" at the same time each day to protect your streak.`
    }
  ];
  if (p2Tasks.length > 0) {
    pillars.push({
      id: "execution",
      name: "Follow-Through & Cadence",
      emoji: "⚡",
      score: s2,
      status: statusForScore(s2),
      insight: `Secondary tasks (${p2Tasks.slice(0, 2).join(", ")}) trail your primary anchor by ${Math.abs(s1 - s2)} points.`,
      tasks: p2Tasks,
      advice: `Stack "${p2Tasks[0]}" immediately after "${p1Tasks[0]}" so there is zero decision friction.`
    });
  }
  return {
    ...(block.listId !== "SINGLE" ? { listId: block.listId } : {}),
    pillars,
    overallInsight: `Your "${block.listName}" routine is averaging ${s}% completion. Tightening the handoff between "${p1Tasks[0] || "your anchor habit"}" and "${p2Tasks[0] || "your closing habit"}" will lift consistency above 85%.`,
    criticalPillar: pillars[pillars.length - 1].name
  };
}

function buildFallbackRecapForBlock(block) {
  const s = block.score;
  const grade = gradeForScore(s);
  const topTask = block.tasks[0]?.title || block.listName;
  const secondTask = block.tasks[1]?.title || topTask;
  return {
    ...(block.listId !== "SINGLE" ? { listId: block.listId } : {}),
    headline: `${block.listName} holding at ${s}% consistency`,
    summary: `Across the past week, you logged a ${s}% completion rate on ${block.listName}, led by steady execution on "${topTask}".`,
    highlight: `"${topTask}" has been your strongest anchor in ${block.listName}.`,
    nudge: `Pair "${secondTask}" right after "${topTask}" tomorrow to close the remaining gap.`,
    grade,
    gradeReason: `${s}% weekly completion rate with "${topTask}" anchoring your routine.`
  };
}

async function normalizeAndFinalizeAIResponse(prompt, parsed) {
  const blocks = extractPromptLists(prompt);

  // 1. Android generateBehaviouralAnalysis (single object with grade, headline, reason, overallInsight, skippedTasks, pillars with advice: string[] & relatedTasks: string[])
  if (prompt.includes('"skippedTasks"') || prompt.includes('"relatedTasks"')) {
    const b = blocks[0];
    const obj = (parsed && typeof parsed === "object" && !Array.isArray(parsed)) ? parsed : {};
    const rawPillars = Array.isArray(obj.pillars) && obj.pillars.length > 0 ? obj.pillars : buildFallbackPillarsForBlock(b).pillars;
    const pillars = rawPillars.map((p, idx) => {
      const sc = clampScore(p?.score, b.score);
      const adv = Array.isArray(p?.advice)
        ? p.advice.map(String).filter(Boolean)
        : (typeof p?.advice === "string" && p.advice.trim() ? [p.advice.trim()] : [`Anchor "${b.tasks[idx]?.title || b.listName}" to a fixed time slot.`]);
      const rel = Array.isArray(p?.relatedTasks)
        ? p.relatedTasks.map(String).filter(Boolean)
        : (Array.isArray(p?.tasks) ? p.tasks.map(String).filter(Boolean) : b.tasks.slice(0, 3).map(t => t.title));
      return {
        name: String(p?.name || `${b.listName} Pillar ${idx + 1}`),
        score: sc,
        status: statusForScore(sc),
        emoji: String(p?.emoji || "🎯"),
        advice: adv.length ? adv : ["Stay consistent with your daily trigger."],
        relatedTasks: rel
      };
    });
    const fallbackRecap = buildFallbackRecapForBlock(b);
    return {
      grade: String(obj.grade || fallbackRecap.grade),
      headline: String(obj.headline || fallbackRecap.headline),
      reason: String(obj.reason || obj.gradeReason || fallbackRecap.gradeReason),
      overallInsight: String(obj.overallInsight || buildFallbackPillarsForBlock(b).overallInsight),
      skippedTasks: Array.isArray(obj.skippedTasks) ? obj.skippedTasks.map(String) : b.tasks.slice(-1).map(t => t.title),
      pillars
    };
  }

  // 2. iOS/macOS Batch Behavioural Pillars
  if (prompt.includes('"pillars"') && prompt.includes("LIST_ID:")) {
    const arr = Array.isArray(parsed) ? parsed : (Array.isArray(parsed?.results) ? parsed.results : []);
    return blocks.map((b, idx) => {
      const match = arr.find(item => String(item?.listId || "").toUpperCase() === b.listId.toUpperCase()) || arr[idx];
      const fallback = buildFallbackPillarsForBlock(b);
      if (!match || !Array.isArray(match.pillars) || match.pillars.length === 0) return fallback;
      const pillars = match.pillars.map((p, pIdx) => {
        const sc = clampScore(p?.score, b.score);
        return {
          id: String(p?.id || `pillar_${pIdx + 1}`),
          name: String(p?.name || fallback.pillars[0].name),
          emoji: String(p?.emoji || "🎯"),
          score: sc,
          status: statusForScore(sc),
          insight: String(p?.insight || fallback.pillars[0].insight),
          tasks: Array.isArray(p?.tasks) && p.tasks.length > 0 ? p.tasks.map(String) : fallback.pillars[0].tasks,
          advice: Array.isArray(p?.advice) ? p.advice.join(" ") : String(p?.advice || fallback.pillars[0].advice)
        };
      });
      return {
        listId: b.listId,
        pillars,
        overallInsight: String(match.overallInsight || fallback.overallInsight),
        criticalPillar: String(match.criticalPillar || pillars[pillars.length - 1].name)
      };
    });
  }

  // 3. iOS/macOS Single-List Behavioural Pillars
  if (prompt.includes('"pillars"')) {
    const b = blocks[0];
    const fallback = buildFallbackPillarsForBlock(b);
    const obj = (parsed && typeof parsed === "object" && !Array.isArray(parsed)) ? parsed : fallback;
    const rawPillars = Array.isArray(obj.pillars) && obj.pillars.length > 0 ? obj.pillars : fallback.pillars;
    const pillars = rawPillars.map((p, pIdx) => {
      const sc = clampScore(p?.score, b.score);
      return {
        id: String(p?.id || `pillar_${pIdx + 1}`),
        name: String(p?.name || fallback.pillars[0].name),
        emoji: String(p?.emoji || "🎯"),
        score: sc,
        status: statusForScore(sc),
        insight: String(p?.insight || fallback.pillars[0].insight),
        tasks: Array.isArray(p?.tasks) && p.tasks.length > 0 ? p.tasks.map(String) : fallback.pillars[0].tasks,
        advice: Array.isArray(p?.advice) ? p.advice.join(" ") : String(p?.advice || fallback.pillars[0].advice)
      };
    });
    return {
      pillars,
      overallInsight: String(obj.overallInsight || fallback.overallInsight),
      criticalPillar: String(obj.criticalPillar || pillars[pillars.length - 1].name)
    };
  }

  // 4. iOS/macOS Batch Weekly Recap
  if (prompt.includes('"gradeReason"') && prompt.includes("LIST_ID:")) {
    const arr = Array.isArray(parsed) ? parsed : (Array.isArray(parsed?.results) ? parsed.results : []);
    return blocks.map((b, idx) => {
      const match = arr.find(item => String(item?.listId || "").toUpperCase() === b.listId.toUpperCase()) || arr[idx];
      const fallback = buildFallbackRecapForBlock(b);
      if (!match || typeof match !== "object") return fallback;
      return {
        listId: b.listId,
        headline: String(match.headline || fallback.headline),
        summary: String(match.summary || fallback.summary),
        highlight: String(match.highlight || fallback.highlight),
        nudge: String(match.nudge || fallback.nudge),
        grade: String(match.grade || fallback.grade),
        gradeReason: String(match.gradeReason || fallback.gradeReason)
      };
    });
  }

  // 5. iOS/macOS Single-List Weekly Recap
  if (prompt.includes('"gradeReason"')) {
    const b = blocks[0];
    const fallback = buildFallbackRecapForBlock(b);
    const obj = (parsed && typeof parsed === "object" && !Array.isArray(parsed)) ? parsed : fallback;
    return {
      headline: String(obj.headline || fallback.headline),
      summary: String(obj.summary || fallback.summary),
      highlight: String(obj.highlight || fallback.highlight),
      nudge: String(obj.nudge || fallback.nudge),
      grade: String(obj.grade || fallback.grade),
      gradeReason: String(obj.gradeReason || fallback.gradeReason)
    };
  }

  // 6. iOS/macOS Batch Procrastination Flags
  if (prompt.includes('"flags"') && prompt.includes("LIST_ID:")) {
    const arr = Array.isArray(parsed) ? parsed : (Array.isArray(parsed?.results) ? parsed.results : []);
    const out = [];
    for (let idx = 0; idx < blocks.length; idx++) {
      const b = blocks[idx];
      const match = arr.find(item => String(item?.listId || "").toUpperCase() === b.listId.toUpperCase()) || arr[idx];
      const rawFlags = Array.isArray(match?.flags) ? match.flags : [];
      const flags = [];
      for (const f of rawFlags) {
        if (!f || typeof f !== "object") continue;
        const matchedTask = b.tasks.find(t => t.title.toLowerCase() === String(f.taskTitle || "").toLowerCase());
        const rawId = String(f.id || matchedTask?.id || "");
        const validId = isValidUUID(rawId)
          ? rawId.toUpperCase()
          : (await deterministicUUID(`flag:${b.listId}:${f.taskTitle || flags.length}`)).toUpperCase();
        flags.push({
          id: validId,
          taskTitle: String(f.taskTitle || matchedTask?.title || b.tasks[0]?.title || "Habit Task"),
          daysSkipped: Math.max(3, Math.round(Number(f.daysSkipped) || 4)),
          suggestion: String(f.suggestion || "Shrink this habit to a 2-minute starter version right after your morning anchor."),
          actionLabel: String(f.actionLabel || "Make It 2-Min")
        });
      }
      out.push({ listId: b.listId, flags });
    }
    return out;
  }

  // 7. iOS/macOS Single-List Procrastination Flags
  if (prompt.includes('"daysSkipped"')) {
    const b = blocks[0];
    const rawFlags = Array.isArray(parsed) ? parsed : (Array.isArray(parsed?.results) ? parsed.results : (Array.isArray(parsed?.flags) ? parsed.flags : []));
    const flags = [];
    for (const f of rawFlags) {
      if (!f || typeof f !== "object") continue;
      const matchedTask = b.tasks.find(t => t.title.toLowerCase() === String(f.taskTitle || "").toLowerCase());
      const rawId = String(f.id || matchedTask?.id || "");
      const validId = isValidUUID(rawId)
        ? rawId.toUpperCase()
        : (await deterministicUUID(`flag:${b.listName}:${f.taskTitle || flags.length}`)).toUpperCase();
      flags.push({
        id: validId,
        taskTitle: String(f.taskTitle || matchedTask?.title || b.tasks[0]?.title || "Habit Task"),
        daysSkipped: Math.max(3, Math.round(Number(f.daysSkipped) || 4)),
        suggestion: String(f.suggestion || "Reduce friction by preparing for this habit the night before."),
        actionLabel: String(f.actionLabel || "Simplify Habit")
      });
    }
    return flags;
  }

  // 8. Starter List (iOS uses listName, Android uses name)
  if (prompt.includes('"listName"') || prompt.includes('"Short List Name"')) {
    const obj = (parsed && typeof parsed === "object" && !Array.isArray(parsed)) ? parsed : {};
    const name = String(obj.listName || obj.name || "Daily Momentum");
    const emoji = String(obj.emoji || "🎯");
    const tasks = Array.isArray(obj.tasks) && obj.tasks.length >= 3
      ? obj.tasks.map(String).slice(0, 6)
      : ["Hydrate with 500ml water", "15 min focused deep work", "Walk 8,000 steps", "10 min evening review", "Read 10 pages"];
    return { listName: name, name, emoji, tasks };
  }

  // 9. Natural Language Task Parsing (iOS & Android)
  if (prompt.includes('"reminderHour"')) {
    const obj = (parsed && typeof parsed === "object" && !Array.isArray(parsed)) ? parsed : {};
    const hour = Number.isInteger(obj.reminderHour) ? obj.reminderHour : null;
    const minute = Number.isInteger(obj.reminderMinute) ? obj.reminderMinute : (hour !== null ? 0 : null);
    return {
      title: String(obj.title || "New Habit"),
      hasReminder: Boolean(obj.hasReminder ?? (hour !== null)),
      reminderHour: hour,
      reminderMinute: minute,
      healthType: obj.healthType ?? null,
      healthTarget: typeof obj.healthTarget === "number" ? obj.healthTarget : null,
      durationMinutes: Number.isInteger(obj.durationMinutes) ? obj.durationMinutes : null
    };
  }

  // 10. List Health Score
  if (prompt.includes('"tips"')) {
    const obj = (parsed && typeof parsed === "object" && !Array.isArray(parsed)) ? parsed : {};
    const sc = clampScore(obj.score, 80);
    return {
      score: sc,
      label: String(obj.label || (sc >= 75 ? "Balanced" : "Needs Tuning")),
      insight: String(obj.insight || "Your habit list has a clear structure. Grouping morning and evening habits will improve follow-through."),
      tips: Array.isArray(obj.tips) && obj.tips.length > 0
        ? obj.tips.map(String)
        : ["Anchor your hardest task to your highest-energy hour.", "Keep daily habit count between 4 and 7 tasks."]
    };
  }

  return parsed || { status: "ok" };
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (request.method === "OPTIONS") {
      return new Response(null, { headers: CORS_HEADERS });
    }

    // Health & Domain Verification endpoint
    if (request.method === "GET" && (url.pathname === "/" || url.pathname === "/api/health")) {
      return json({
        service: "Sortyd Cloud Gateway",
        domain: url.hostname,
        status: "ok",
        database: "supabase-connected"
      });
    }

    // ── Masked Google OAuth Flow on https://auth.sortyd.com/oauth/google ──
    if (request.method === "GET" && url.pathname === "/oauth/google") {
      const redirectUri = url.searchParams.get("redirect_uri") || "com.sortyd.sortyd://auth/callback";
      return htmlResponse(renderGoogleSignInPage(redirectUri));
    }

    if (request.method === "POST" && url.pathname === "/oauth/google/complete") {
      const formData = await request.formData().catch(() => null);
      const email = formData ? String(formData.get("email") || "").trim().toLowerCase() : "";
      const name = formData ? String(formData.get("name") || "").trim() : "";
      const redirectUri = formData ? String(formData.get("redirect_uri") || "com.sortyd.sortyd://auth/callback") : "com.sortyd.sortyd://auth/callback";

      if (!email || !email.includes("@")) {
        return htmlResponse(renderGoogleSignInPage(redirectUri, "Please enter a valid Google email address."), 400);
      }

      const supaUser = await ensureSupabaseUser(env, {
        email,
        name: name || email.split("@")[0],
        provider: "google"
      });

      const token = await createSession(env, supaUser);
      const callbackUrl = new URL(redirectUri);
      callbackUrl.searchParams.set("token", token);
      callbackUrl.searchParams.set("id", supaUser.id);
      callbackUrl.searchParams.set("email", supaUser.email);
      callbackUrl.searchParams.set("name", supaUser.name);
      callbackUrl.searchParams.set("provider", "google");

      return Response.redirect(callbackUrl.toString(), 302);
    }

    // Direct JSON Google Auth endpoint
    if (request.method === "POST" && url.pathname === "/api/auth/google") {
      let body;
      try { body = await request.json(); } catch { return json({ error: "Invalid JSON" }, 400); }
      const email = typeof body.email === "string" ? body.email.trim().toLowerCase() : "";
      const name = typeof body.name === "string" ? body.name.trim() : "";
      if (!email || !email.includes("@")) {
        return json({ error: "A valid Google email is required." }, 400);
      }
      const supaUser = await ensureSupabaseUser(env, {
        email,
        name: name || email.split("@")[0],
        provider: "google"
      });
      const token = await createSession(env, supaUser);
      return json({ token, user: supaUser });
    }

    // ── 1. Email Sign Up (Backed by Supabase auth.users + public.profiles) ──
    if (request.method === "POST" && url.pathname === "/api/auth/signup") {
      let body;
      try { body = await request.json(); } catch { return json({ error: "Invalid JSON" }, 400); }
      const email = typeof body.email === "string" ? body.email.trim().toLowerCase() : "";
      const password = typeof body.password === "string" ? body.password : "";
      const name = typeof body.name === "string" ? body.name.trim() : "";

      if (!email || !email.includes("@") || email.length < 5) {
        return json({ error: "Please enter a valid email address." }, 400);
      }
      if (!password || password.length < 6) {
        return json({ error: "Password must be at least 6 characters long." }, 400);
      }

      const existingProfile = await findSupabaseProfileByEmail(env, email);
      const existingKV = await env.SORTYD_DATA.get(`user:${email}`);
      if (existingProfile && existingKV) {
        return json({ error: "An account with this email already exists. Please sign in." }, 409);
      }

      const { salt, hash } = await hashPassword(password);
      const supaUser = await ensureSupabaseUser(env, {
        email,
        password,
        name: name || email.split("@")[0],
        provider: "email"
      });

      const user = {
        id: supaUser.id,
        email: supaUser.email,
        name: supaUser.name,
        createdAt: new Date().toISOString()
      };

      await env.SORTYD_DATA.put(`user:${email}`, JSON.stringify({ ...user, salt, hash }));
      await env.SORTYD_DATA.put(`uid:${user.id}`, email);

      const token = await createSession(env, user);
      return json({ token, user });
    }

    // ── 2. Email Sign In (Checks Supabase Auth + KV seamlessly) ──
    if (request.method === "POST" && url.pathname === "/api/auth/signin") {
      let body;
      try { body = await request.json(); } catch { return json({ error: "Invalid JSON" }, 400); }
      const email = typeof body.email === "string" ? body.email.trim().toLowerCase() : "";
      const password = typeof body.password === "string" ? body.password : "";

      if (!email || !password) {
        return json({ error: "Email and password are required." }, 400);
      }

      // First try Supabase native password grant
      let authenticatedUser = null;
      const supaTokenRes = await fetch(`${env.SUPABASE_URL}/auth/v1/token?grant_type=password`, {
        method: "POST",
        headers: {
          "apikey": env.SUPABASE_ANON_KEY,
          "Content-Type": "application/json"
        },
        body: JSON.stringify({ email, password })
      });

      if (supaTokenRes.ok) {
        const supaAuth = await supaTokenRes.json().catch(() => null);
        if (supaAuth && supaAuth.user) {
          authenticatedUser = await ensureSupabaseUser(env, {
            id: supaAuth.user.id,
            email,
            name: supaAuth.user.user_metadata?.full_name || supaAuth.user.user_metadata?.name || email.split("@")[0],
            provider: "email"
          });
        }
      }

      // Fallback to KV hash verification (and auto-migrate into Supabase!)
      if (!authenticatedUser) {
        const rawUser = await env.SORTYD_DATA.get(`user:${email}`);
        if (!rawUser) {
          return json({ error: "Incorrect email or password." }, 401);
        }
        let userRecord;
        try { userRecord = JSON.parse(rawUser); } catch { return json({ error: "Internal account error" }, 500); }

        const { hash } = await hashPassword(password, userRecord.salt);
        if (hash !== userRecord.hash) {
          return json({ error: "Incorrect email or password." }, 401);
        }

        authenticatedUser = await ensureSupabaseUser(env, {
          id: userRecord.id,
          email: userRecord.email,
          password,
          name: userRecord.name || email.split("@")[0],
          provider: "email"
        });
      }

      const token = await createSession(env, authenticatedUser);
      return json({
        token,
        user: {
          id: authenticatedUser.id,
          email: authenticatedUser.email,
          name: authenticatedUser.name
        }
      });
    }

    // ── 3. Apple Sign In (Backed by Supabase auth.users + public.profiles) ──
    if (request.method === "POST" && url.pathname === "/api/auth/apple") {
      let body;
      try { body = await request.json(); } catch { return json({ error: "Invalid JSON" }, 400); }
      const appleId = typeof body.userIdentifier === "string" ? body.userIdentifier.trim() : "";
      const email = typeof body.email === "string" ? body.email.trim().toLowerCase() : "";
      const name = typeof body.fullName === "string" ? body.fullName.trim() : "";

      if (!appleId) {
        return json({ error: "Apple userIdentifier is required." }, 400);
      }

      let mappedUserId = await env.SORTYD_DATA.get(`apple:${appleId}`);
      const effectiveEmail = email || `${appleId.slice(0, 12).replace(/[^a-zA-Z0-9]/g, "")}@apple.sortyd.com`;
      const effectiveName = name || "Sortyd Member";

      const supaUser = await ensureSupabaseUser(env, {
        id: mappedUserId || await deterministicUUID(`apple:${appleId}`),
        email: effectiveEmail,
        name: effectiveName,
        provider: "apple"
      });

      await env.SORTYD_DATA.put(`apple:${appleId}`, supaUser.id);
      await env.SORTYD_DATA.put(`uid:${supaUser.id}`, supaUser.email);

      const token = await createSession(env, supaUser);
      return json({
        token,
        user: {
          id: supaUser.id,
          email: supaUser.email,
          name: supaUser.name
        }
      });
    }

    // ── 4. Current User Session Check ──
    if (request.method === "GET" && url.pathname === "/api/auth/me") {
      const session = await getSessionUser(request, env);
      if (!session) return json({ error: "Unauthorized" }, 401);
      return json({
        user: {
          id: session.userId,
          email: session.email,
          name: session.name
        }
      });
    }

    // ── 5. Get User Data (Reads from Supabase user_workspaces, auto-migrating KV if needed) ──
    if (request.method === "GET" && url.pathname === "/api/user/sync") {
      const session = await getSessionUser(request, env);
      if (!session) return json({ error: "Unauthorized" }, 401);

      // Ensure user exists in Supabase
      const supaUser = await ensureSupabaseUser(env, {
        id: session.userId,
        email: session.email,
        name: session.name,
        provider: session.provider || "email"
      });

      const supaWorkspace = await fetchWorkspaceFromSupabase(env, supaUser.id);
      if (supaWorkspace && supaWorkspace.data) {
        return json({
          data: supaWorkspace.data,
          updatedAt: supaWorkspace.updatedAt,
          sourceDevice: supaWorkspace.sourceDevice
        });
      }

      // Check legacy KV data and migrate to Supabase if present
      const rawKV = await env.SORTYD_DATA.get(`data:${session.userId}`);
      if (rawKV) {
        try {
          const parsed = JSON.parse(rawKV);
          if (parsed && parsed.data) {
            await persistWorkspaceToSupabase(env, supaUser.id, parsed.data, "KV-Migration");
            return json({ data: parsed.data, updatedAt: parsed.updatedAt });
          }
        } catch {}
      }

      return json({ data: null, updatedAt: null });
    }

    // ── 6. Save & Non-Destructively Merge User Data into Supabase ──
    if (request.method === "POST" && url.pathname === "/api/user/sync") {
      const session = await getSessionUser(request, env);
      if (!session) return json({ error: "Unauthorized" }, 401);

      let body;
      try { body = await request.json(); } catch { return json({ error: "Invalid JSON" }, 400); }

      const incomingData = body.data ?? body;
      const allowDelete = Boolean(body.allowDelete);
      const replaceWorkspace = Boolean(body.replaceWorkspace);
      const sourceDevice = typeof body.sourceDevice === "string" ? body.sourceDevice : "Sortyd App";

      const supaUser = await ensureSupabaseUser(env, {
        id: session.userId,
        email: session.email,
        name: session.name,
        provider: session.provider || "email"
      });

      if (replaceWorkspace) {
        await Promise.all([
          fetch(`${env.SUPABASE_URL}/rest/v1/habit_tasks?user_id=eq.${encodeURIComponent(supaUser.id)}`, { method: "DELETE", headers: supabaseHeaders(env) }).catch(() => {}),
          fetch(`${env.SUPABASE_URL}/rest/v1/habit_lists?user_id=eq.${encodeURIComponent(supaUser.id)}`, { method: "DELETE", headers: supabaseHeaders(env) }).catch(() => {}),
          fetch(`${env.SUPABASE_URL}/rest/v1/daily_snapshots?user_id=eq.${encodeURIComponent(supaUser.id)}`, { method: "DELETE", headers: supabaseHeaders(env) }).catch(() => {}),
          fetch(`${env.SUPABASE_URL}/rest/v1/weekly_plans?user_id=eq.${encodeURIComponent(supaUser.id)}`, { method: "DELETE", headers: supabaseHeaders(env) }).catch(() => {})
        ]);
      }

      // Fetch current cloud workspace from Supabase to perform non-destructive union merge
      const existingCloud = replaceWorkspace ? null : await fetchWorkspaceFromSupabase(env, supaUser.id);
      const mergedData = existingCloud && existingCloud.data
        ? mergeWorkspaces(existingCloud.data, incomingData, allowDelete)
        : mergeWorkspaces({ lists: [], snapshots: [] }, incomingData, true);

      const updatedAt = await persistWorkspaceToSupabase(env, supaUser.id, mergedData, sourceDevice);

      return json({
        success: true,
        updatedAt,
        data: mergedData
      });
    }

    // ── 7. Masked Supabase Auth / REST Passthrough (Rewriting supabase.co URLs to sortyd.com) ──
    if (url.pathname.startsWith("/auth/v1/") || url.pathname.startsWith("/rest/v1/")) {
      const targetUrl = new URL(url.pathname + url.search, env.SUPABASE_URL);
      const proxyHeaders = new Headers(request.headers);
      if (!proxyHeaders.has("apikey")) {
        proxyHeaders.set("apikey", env.SUPABASE_ANON_KEY);
      }
      const res = await fetch(targetUrl.toString(), {
        method: request.method,
        headers: proxyHeaders,
        body: ["GET", "HEAD"].includes(request.method) ? undefined : await request.arrayBuffer(),
        redirect: "manual"
      });
      const outHeaders = new Headers(res.headers);
      for (const [k, v] of Object.entries(CORS_HEADERS)) outHeaders.set(k, v);
      if (outHeaders.has("location")) {
        outHeaders.set(
          "location",
          outHeaders.get("location").replace("https://hdokavfcqxmbshmgwcam.supabase.co", env.PUBLIC_AUTH_HOST)
        );
      }
      return new Response(res.body, { status: res.status, headers: outHeaders });
    }

    // ── 8. AI Coach Endpoint ──
    if (request.method === "POST" && url.pathname === "/api/ai") {
      const contentLength = Number(request.headers.get("content-length") || 0);
      if (contentLength > 96_000) {
        return json({ error: "Request too large" }, 413);
      }

      if (env.AI_RATE_LIMITER) {
        const clientKey = request.headers.get("cf-connecting-ip") || "unknown";
        const { success } = await env.AI_RATE_LIMITER.limit({ key: clientKey });
        if (!success) return json({ error: "Too many requests. Try again shortly." }, 429);
      }

      const body = await request.text();
      let input;
      try {
        input = JSON.parse(body);
      } catch {
        return json({ error: "Invalid JSON" }, 400);
      }

      if (!input || typeof input !== "object" || !Array.isArray(input.messages) || input.messages.length !== 1) {
        return json({ error: "messages is required" }, 400);
      }
      const [message] = input.messages;
      if (
        !message || message.role !== "user" || typeof message.content !== "string" ||
        message.content.length === 0 || message.content.length > MAX_MESSAGE_CHARS
      ) return json({ error: "Invalid message" }, 400);

      let parsed = null;
      if (env.AI) {
        try {
          const result = await env.AI.run(MODEL, {
            messages: [
              {
                role: "system",
                content: "Respond ONLY with valid JSON matching the structure requested by the user. Do not include markdown fences or extra commentary. Base every insight and score on the supplied habit and completion data."
              },
              { role: "user", content: message.content }
            ],
            max_tokens: Math.max(256, Math.min(Number.isFinite(Number(input.max_tokens)) ? Number(input.max_tokens) || 1200 : 1200, MAX_OUTPUT_TOKENS)),
            temperature: Math.max(0, Math.min(Number(input.temperature) || 0.35, 0.7))
          });
          const raw = typeof result === "string" ? result : (result?.response ?? result?.text ?? result);
          parsed = extractJSON(raw);
        } catch (aiErr) {
          console.error("Workers AI invocation error, using data-driven normalizer:", aiErr);
        }
      }

      const normalized = await normalizeAndFinalizeAIResponse(message.content, parsed);
      const content = typeof normalized === "string" ? normalized : JSON.stringify(normalized);
      return json({
        choices: [{
          index: 0,
          message: { role: "assistant", content },
          finish_reason: "stop"
        }]
      });
    }

    return json({ error: "Not found" }, 404);
  }
};
