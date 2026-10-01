import {randomInt} from "node:crypto";
import {initializeApp} from "firebase-admin/app";
import {getFirestore, Timestamp} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";

initializeApp();
const db = getFirestore();
// Firebase ID tokens are verified by onCall, not Cloud Run's IAM gate.
// Every handler still requires request.auth via identity().
const options = {region: "us-central1", maxInstances: 10, invoker: "public" as const};
const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
const topics = new Set(["food", "places", "hobbies"]);
type Player = {name: string; ready: boolean; joinedAt: number};
type Room = {
  code: string; hostId: string; status: string; topicId: string;
  createdAt: Timestamp; expiresAt: Timestamp; players: Record<string, Player>;
};

function text(value: unknown, label: string, max: number): string {
  if (typeof value !== "string" || !value.trim() || value.trim().length > max) {
    throw new HttpsError("invalid-argument", `${label} must be 1–${max} characters.`);
  }
  return value.trim();
}
function topic(value: unknown): string {
  if (typeof value !== "string" || !topics.has(value)) {
    throw new HttpsError("invalid-argument", "Choose a valid topic.");
  }
  return value;
}
function identity(uid?: string): string {
  if (!uid) throw new HttpsError("unauthenticated", "Please sign in again.");
  return uid;
}
function roomId(value: unknown): string {
  const id = text(value, "Room ID", 100);
  if (!/^[A-Za-z0-9]+$/.test(id)) throw new HttpsError("invalid-argument", "Invalid room ID.");
  return id;
}
function requireLobby(room?: Room): asserts room is Room {
  if (!room || room.status !== "lobby" || room.expiresAt.toMillis() <= Date.now()) {
    throw new HttpsError("failed-precondition", "This lobby has closed or expired.");
  }
}

export const createRoom = onCall(options, async (request) => {
  const uid = identity(request.auth?.uid);
  const name = text(request.data?.name, "Name", 20);
  const topicId = topic(request.data?.topicId);
  // One active room per identity makes retries safe and prevents orphan lobbies.
  const memberRef = db.doc(`lobbyMembers/${uid}`);
  for (let attempt = 0; attempt < 10; attempt++) {
    const code = Array.from({length: 6}, () => alphabet[randomInt(alphabet.length)]).join("");
    const ref = db.collection("rooms").doc();
    const codeRef = db.doc(`roomCodes/${code}`);
    const result = await db.runTransaction(async (tx) => {
      const member = await tx.get(memberRef);
      if (member.exists) {
        const old = await tx.get(db.doc(`rooms/${member.get("roomId")}`));
        const data = old.data() as Room | undefined;
        if (data?.status === "lobby" && data.expiresAt.toMillis() > Date.now() && data.players[uid]) {
          return {roomId: old.id};
        }
      }
      const reserved = await tx.get(codeRef);
      if (reserved.exists && reserved.get("expiresAt").toMillis() > Date.now()) return null;
      const now = Timestamp.now();
      const expiresAt = Timestamp.fromMillis(now.toMillis() + 6 * 60 * 60 * 1000);
      tx.set(ref, {
        code, hostId: uid, status: "lobby", topicId, createdAt: now, expiresAt,
        players: {[uid]: {name, ready: false, joinedAt: now.toMillis()}},
      });
      tx.set(codeRef, {roomId: ref.id, expiresAt});
      tx.set(memberRef, {roomId: ref.id});
      return {roomId: ref.id};
    });
    if (result) return result;
  }
  throw new HttpsError("resource-exhausted", "Could not create a code. Please retry.");
});

export const joinRoom = onCall(options, async (request) => {
  const uid = identity(request.auth?.uid);
  const name = text(request.data?.name, "Name", 20);
  const code = text(request.data?.code, "Code", 6).toUpperCase();
  if (!/^[A-HJ-NP-Z2-9]{6}$/.test(code)) throw new HttpsError("invalid-argument", "Enter a six-character game code.");
  return db.runTransaction(async (tx) => {
    const lookup = await tx.get(db.doc(`roomCodes/${code}`));
    if (!lookup.exists || lookup.get("expiresAt").toMillis() <= Date.now()) {
      throw new HttpsError("not-found", "That code was not found or has expired.");
    }
    const ref = db.doc(`rooms/${lookup.get("roomId")}`);
    const snapshot = await tx.get(ref);
    const room = snapshot.data() as Room | undefined;
    requireLobby(room);
    if (room.players[uid]) return {roomId: ref.id};
    const memberRef = db.doc(`lobbyMembers/${uid}`);
    const member = await tx.get(memberRef);
    if (member.exists && member.get("roomId") !== ref.id) {
      const old = (await tx.get(db.doc(`rooms/${member.get("roomId")}`))).data() as Room | undefined;
      if (old?.status === "lobby" && old.expiresAt.toMillis() > Date.now() && old.players[uid]) {
        throw new HttpsError("failed-precondition", "Leave your current lobby before joining another.");
      }
    }
    if (Object.keys(room.players).length >= 8) throw new HttpsError("resource-exhausted", "This lobby is full.");
    if (Object.values(room.players).some((p) => p.name.toLowerCase() === name.toLowerCase())) {
      throw new HttpsError("already-exists", "That name is already taken in this lobby.");
    }
    room.players[uid] = {name, ready: false, joinedAt: Date.now()};
    tx.update(ref, {players: room.players});
    tx.set(memberRef, {roomId: ref.id});
    return {roomId: ref.id};
  });
});

export const getMyRoom = onCall(options, async (request) => {
  const uid = identity(request.auth?.uid);
  const member = await db.doc(`lobbyMembers/${uid}`).get();
  if (!member.exists) return {roomId: null};
  const snapshot = await db.doc(`rooms/${member.get("roomId")}`).get();
  const room = snapshot.data() as Room | undefined;
  return {roomId: room?.status === "lobby" && room.expiresAt.toMillis() > Date.now() && room.players[uid] ? snapshot.id : null};
});

export const setReady = onCall(options, async (request) => {
  const uid = identity(request.auth?.uid);
  if (typeof request.data?.ready !== "boolean") throw new HttpsError("invalid-argument", "Ready must be true or false.");
  const ref = db.doc(`rooms/${roomId(request.data?.roomId)}`);
  await db.runTransaction(async (tx) => {
    const room = (await tx.get(ref)).data() as Room | undefined;
    requireLobby(room);
    if (!room.players[uid]) throw new HttpsError("permission-denied", "Join this lobby first.");
    room.players[uid].ready = request.data.ready;
    tx.update(ref, {players: room.players});
  });
  return {ok: true};
});

export const setTopic = onCall(options, async (request) => {
  const uid = identity(request.auth?.uid);
  const topicId = topic(request.data?.topicId);
  const ref = db.doc(`rooms/${roomId(request.data?.roomId)}`);
  await db.runTransaction(async (tx) => {
    const room = (await tx.get(ref)).data() as Room | undefined;
    requireLobby(room);
    if (room.hostId !== uid) throw new HttpsError("permission-denied", "Only the host can choose the topic.");
    if (room.topicId === topicId) return;
    for (const player of Object.values(room.players)) player.ready = false;
    tx.update(ref, {topicId, players: room.players});
  });
  return {ok: true};
});

export const leaveRoom = onCall(options, async (request) => {
  const uid = identity(request.auth?.uid);
  const ref = db.doc(`rooms/${roomId(request.data?.roomId)}`);
  await db.runTransaction(async (tx) => {
    const room = (await tx.get(ref)).data() as Room | undefined;
    const memberRef = db.doc(`lobbyMembers/${uid}`);
    const member = await tx.get(memberRef);
    if (!room || !room.players[uid]) return;
    if (room.status !== "lobby") throw new HttpsError("failed-precondition", "This round has already started.");
    delete room.players[uid];
    const remaining = Object.entries(room.players).sort((a, b) => a[1].joinedAt - b[1].joinedAt || a[0].localeCompare(b[0]));
    const codeRef = db.doc(`roomCodes/${room.code}`);
    const code = remaining.length === 0 ? await tx.get(codeRef) : null;
    if (remaining.length === 0) {
      tx.delete(ref);
      if (code?.get("roomId") === ref.id) tx.delete(codeRef);
    } else {
      tx.update(ref, {players: room.players, hostId: room.hostId === uid ? remaining[0][0] : room.hostId});
    }
    if (member.get("roomId") === ref.id) tx.delete(memberRef);
  });
  return {ok: true};
});
