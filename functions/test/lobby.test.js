const {test} = require('node:test');
const assert = require('node:assert/strict');
const {readFileSync} = require('node:fs');
const {initializeTestEnvironment, assertFails, assertSucceeds} = require('@firebase/rules-unit-testing');
const {doc, getDoc, setDoc, getDocs, collection} = require('firebase/firestore');

const project = 'demo-chameleon';
async function guest() {
  const response = await fetch('http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signUp?key=demo-key', {
    method: 'POST', headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({returnSecureToken: true}),
  });
  const data = await response.json();
  assert.ok(data.idToken, JSON.stringify(data));
  return {id: data.localId, token: data.idToken};
}
async function call(user, action, data = {}) {
  const response = await fetch(`http://127.0.0.1:5001/${project}/us-central1/${action}`, {
    method: 'POST', headers: {'Content-Type': 'application/json', ...(user ? {Authorization: `Bearer ${user.token}`} : {})},
    body: JSON.stringify({data}),
  });
  const body = await response.json();
  if (body.error) throw Object.assign(new Error(body.error.message), {code: body.error.status});
  return body.result;
}

test('real callable lobby flow, concurrent capacity and private access rules', {timeout: 120000}, async () => {
  const env = await initializeTestEnvironment({projectId: project, firestore: {
    host: '127.0.0.1', port: 8080, rules: readFileSync('../firestore.rules', 'utf8'),
  }});
  try {
    await env.clearFirestore();
    const users = await Promise.all(Array.from({length: 10}, guest));
    const host = users[0];
    await assert.rejects(call(null, 'createRoom', {name: 'Alex', topicId: 'food'}), {code: 'UNAUTHENTICATED'});
    await assert.rejects(call(host, 'createRoom', {name: '', topicId: 'food'}), {code: 'INVALID_ARGUMENT'});
    const {roomId} = await call(host, 'createRoom', {name: ' Alex ', topicId: 'food'});
    assert.deepEqual(await call(host, 'createRoom', {name: 'Alex', topicId: 'food'}), {roomId});
    const hostDb = env.authenticatedContext(host.id).firestore();
    const roomRef = doc(hostDb, 'rooms', roomId);
    const read = async () => (await getDoc(roomRef)).data();
    let room = await read();
    assert.match(room.code, /^[A-HJ-NP-Z2-9]{6}$/);
    assert.equal(room.players[host.id].name, 'Alex');
    await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'rooms', roomId)));
    await assertFails(getDoc(doc(env.authenticatedContext(users[1].id).firestore(), 'rooms', roomId)));
    await assertFails(getDocs(collection(hostDb, 'rooms')));
    await assertFails(setDoc(roomRef, {hostId: users[1].id}, {merge: true}));
    await assertFails(getDoc(doc(hostDb, 'roomCodes', room.code)));
    await assert.rejects(call(users[1], 'joinRoom', {code: room.code, name: 'aLEX'}), {code: 'ALREADY_EXISTS'});
    await call(users[1], 'joinRoom', {code: room.code.toLowerCase(), name: 'Blair'});
    await call(users[1], 'joinRoom', {code: room.code, name: 'Blair'});
    assert.equal(Object.keys((await read()).players).length, 2);
    assert.deepEqual(await call(users[1], 'getMyRoom'), {roomId});
    await assertSucceeds(getDoc(doc(env.authenticatedContext(users[1].id).firestore(), 'rooms', roomId)));
    await assert.rejects(call(users[1], 'setTopic', {roomId, topicId: 'places'}), {code: 'PERMISSION_DENIED'});
    await assert.rejects(call(users[9], 'setReady', {roomId, ready: true}), {code: 'PERMISSION_DENIED'});
    await call(users[1], 'setReady', {roomId, ready: true});
    assert.equal((await read()).players[users[1].id].ready, true);
    await call(host, 'setTopic', {roomId, topicId: 'places'});
    assert.equal((await read()).players[users[1].id].ready, false);
    const joins = await Promise.allSettled(users.slice(2).map((user, i) => call(user, 'joinRoom', {code: room.code, name: `Guest ${i}`})));
    assert.equal(joins.filter(r => r.status === 'fulfilled').length, 6);
    assert.equal(joins.filter(r => r.status === 'rejected' && r.reason.code === 'RESOURCE_EXHAUSTED').length, 2);
    assert.equal(Object.keys((await read()).players).length, 8);
    await call(host, 'leaveRoom', {roomId});
    await call(host, 'leaveRoom', {roomId});
    await assertFails(getDoc(roomRef));
    const nextDb = env.authenticatedContext(users[1].id).firestore();
    room = (await getDoc(doc(nextDb, 'rooms', roomId))).data();
    assert.equal(room.hostId, users[1].id);
    for (const user of users.slice(1).filter(u => room.players[u.id])) await call(user, 'leaveRoom', {roomId});
    await assert.rejects(call(host, 'joinRoom', {code: room.code, name: 'Alex'}), {code: 'NOT_FOUND'});
    assert.deepEqual(await call(host, 'getMyRoom'), {roomId: null});

    const expired = await call(host, 'createRoom', {name: 'Alex', topicId: 'food'});
    await env.withSecurityRulesDisabled(async context => {
      await setDoc(doc(context.firestore(), 'rooms', expired.roomId), {expiresAt: new Date(0)}, {merge: true});
    });
    await assert.rejects(call(host, 'setReady', {...expired, ready: true}), {code: 'FAILED_PRECONDITION'});
    await assertFails(getDoc(doc(hostDb, 'rooms', expired.roomId)));
    assert.deepEqual(await call(host, 'getMyRoom'), {roomId: null});
  } finally {
    await env.cleanup();
  }
});
