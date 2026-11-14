// Kiểm thử Firestore rules trên emulator.
// Chạy: npm test (trong thư mục rules_test, cần JDK 21+ và firebase-tools).
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
  doc, setDoc, updateDoc, getDoc, getDocs, deleteDoc, collection, query, where,
  arrayUnion, arrayRemove, writeBatch, serverTimestamp, increment, Timestamp, Bytes,
} from 'firebase/firestore';
import { ref, uploadBytes, getBytes, deleteObject } from 'firebase/storage';
import fs from 'fs';

const rulesPath = new URL('../firestore.rules', import.meta.url);
const storageRulesPath = new URL('../storage.rules', import.meta.url);
const env = await initializeTestEnvironment({
  projectId: 'demo-rules',
  firestore: { rules: fs.readFileSync(rulesPath, 'utf8'), host: '127.0.0.1', port: 8085 },
  storage: { rules: fs.readFileSync(storageRulesPath, 'utf8'), host: '127.0.0.1', port: 9199 },
});

let pass = 0;
let fail = 0;
async function t(name, promise) {
  try {
    await promise;
    console.log('OK  ', name);
    pass++;
  } catch (e) {
    console.log('FAIL', name, '-', String(e.message).split('\n')[0]);
    fail++;
  }
}

const ing = (n = 1) => Array.from({ length: n }, (_, i) => ({ id: `i${i}`, name: 'x' }));
const stp = (n = 1) => Array.from({ length: n }, (_, i) => ({ id: `s${i}`, order: i + 1, text: 'y' }));
const recipe = (ownerId, over = {}) => ({
  ownerId, title: 'Thịt kho', baseServings: 2, imageUrl: '', note: '', tags: [],
  ingredients: ing(), steps: stp(), schemaVersion: 1, ...over,
});

await env.withSecurityRulesDisabled(async (ctx) => {
  const db = ctx.firestore();
  await setDoc(doc(db, 'users/alice'), { role: 'blogger', isLocked: false, followers: [], email: 'alice@example.com', username: 'alice' });
  await setDoc(doc(db, 'users/bob'), { role: 'blogger', isLocked: false, followers: ['carol'] });
  await setDoc(doc(db, 'users/admin'), { role: 'admin' });
  await setDoc(doc(db, 'users/lock'), { role: 'blogger', isLocked: true });
  await setDoc(doc(db, 'recipes/ra'), recipe('alice'));
  await setDoc(doc(db, 'recipes/rb'), recipe('bob'));
  await setDoc(doc(db, 'foods/f1'), { authorId: 'alice', isApproved: true, isShared: true, isFeatured: false, likedBy: ['carol'], rating: 0, title: 'x' });
  await setDoc(doc(db, 'foods/fpriv'), { authorId: 'bob', isApproved: false, isShared: false, isFeatured: false, likedBy: [], rating: 0, title: 'riêng' });
});

const alice = env.authenticatedContext('alice').firestore();
const bob = env.authenticatedContext('bob').firestore();
const admin = env.authenticatedContext('admin').firestore();
const anon = env.unauthenticatedContext().firestore();

console.log('\n== recipes: chủ sở hữu ==');
await t('alice tạo công thức của mình', assertSucceeds(setDoc(doc(alice, 'recipes/new1'), recipe('alice'))));
await t('alice đọc (get) công thức của mình', assertSucceeds(getDoc(doc(alice, 'recipes/ra'))));
await t('alice liệt kê với where ownerId == uid', assertSucceeds(getDocs(query(collection(alice, 'recipes'), where('ownerId', '==', 'alice')))));
await t('alice sửa tiêu đề công thức của mình', assertSucceeds(updateDoc(doc(alice, 'recipes/ra'), { title: 'Mới' })));
await t('alice xoá công thức của mình', assertSucceeds(deleteDoc(doc(alice, 'recipes/new1'))));

console.log('\n== recipes: người khác bị từ chối ==');
await t('bob không đọc được công thức của alice', assertFails(getDoc(doc(bob, 'recipes/ra'))));
await t('bob không sửa được công thức của alice', assertFails(updateDoc(doc(bob, 'recipes/ra'), { title: 'hack' })));
await t('bob không xoá được công thức của alice', assertFails(deleteDoc(doc(bob, 'recipes/ra'))));
await t('admin cũng không đọc được công thức riêng tư', assertFails(getDoc(doc(admin, 'recipes/ra'))));
await t('bob không tạo công thức mang ownerId của alice', assertFails(setDoc(doc(bob, 'recipes/x1'), recipe('alice'))));
await t('alice không đổi được ownerId', assertFails(updateDoc(doc(alice, 'recipes/ra'), { ownerId: 'bob' })));
await t('alice không "đẩy" công thức sang bob qua set', assertFails(setDoc(doc(alice, 'recipes/ra'), recipe('bob'))));

console.log('\n== recipes: kiểm tra dữ liệu ==');
await t('0 nguyên liệu bị từ chối', assertFails(setDoc(doc(alice, 'recipes/v1'), recipe('alice', { ingredients: [] }))));
await t('0 bước bị từ chối', assertFails(setDoc(doc(alice, 'recipes/v2'), recipe('alice', { steps: [] }))));
await t('101 nguyên liệu bị từ chối', assertFails(setDoc(doc(alice, 'recipes/v3'), recipe('alice', { ingredients: ing(101) }))));
await t('101 bước bị từ chối', assertFails(setDoc(doc(alice, 'recipes/v4'), recipe('alice', { steps: stp(101) }))));
await t('100 nguyên liệu và 100 bước được chấp nhận', assertSucceeds(setDoc(doc(alice, 'recipes/v5'), recipe('alice', { ingredients: ing(100), steps: stp(100) }))));
await t('tên rỗng bị từ chối', assertFails(setDoc(doc(alice, 'recipes/v6'), recipe('alice', { title: '' }))));
await t('tên 121 ký tự bị từ chối', assertFails(setDoc(doc(alice, 'recipes/v7'), recipe('alice', { title: 'a'.repeat(121) }))));
await t('baseServings = 0 bị từ chối', assertFails(setDoc(doc(alice, 'recipes/v8'), recipe('alice', { baseServings: 0 }))));
await t('baseServings = 101 bị từ chối', assertFails(setDoc(doc(alice, 'recipes/v9'), recipe('alice', { baseServings: 101 }))));
await t('baseServings kiểu chuỗi bị từ chối', assertFails(setDoc(doc(alice, 'recipes/v10'), recipe('alice', { baseServings: '2' }))));
await t('21 thẻ bị từ chối', assertFails(setDoc(doc(alice, 'recipes/v11'), recipe('alice', { tags: Array.from({ length: 21 }, (_, i) => `t${i}`) }))));
await t('ghi chú 2001 ký tự bị từ chối', assertFails(setDoc(doc(alice, 'recipes/v12'), recipe('alice', { note: 'a'.repeat(2001) }))));
await t('sửa thành 0 nguyên liệu bị từ chối', assertFails(updateDoc(doc(alice, 'recipes/ra'), { ingredients: [] })));

console.log('\n== recipes: truy vấn và chưa đăng nhập ==');
await t('liệt kê không lọc ownerId bị từ chối', assertFails(getDocs(collection(alice, 'recipes'))));
await t('liệt kê với ownerId của người khác bị từ chối', assertFails(getDocs(query(collection(alice, 'recipes'), where('ownerId', '==', 'bob')))));
await t('đọc document chưa tồn tại khi đã đăng nhập không bị từ chối', assertSucceeds(getDoc(doc(alice, 'recipes/khong-ton-tai'))));
await t('chưa đăng nhập: không đọc được', assertFails(getDoc(doc(anon, 'recipes/ra'))));
await t('chưa đăng nhập: không đọc document chưa tồn tại', assertFails(getDoc(doc(anon, 'recipes/khong-ton-tai'))));
await t('chưa đăng nhập: không tạo được', assertFails(setDoc(doc(anon, 'recipes/x2'), recipe('alice'))));
await t('chưa đăng nhập: không liệt kê được', assertFails(getDocs(query(collection(anon, 'recipes'), where('ownerId', '==', 'alice')))));

console.log('\n== users và foods phục vụ việc chuyển dữ liệu ==');
await t('alice không tự đặt role = admin', assertFails(updateDoc(doc(alice, 'users/alice'), { role: 'admin' })));
await t('alice ghi được recipeMigratedAt của mình', assertSucceeds(updateDoc(doc(alice, 'users/alice'), { recipeMigratedAt: new Date() })));
await t('alice không ghi recipeMigratedAt của bob', assertFails(updateDoc(doc(alice, 'users/bob'), { recipeMigratedAt: new Date() })));
await t('alice đọc được foods của mình theo authorId', assertSucceeds(getDocs(query(collection(alice, 'foods'), where('authorId', '==', 'alice')))));
await t('alice không đọc được món riêng tư của bob', assertFails(getDoc(doc(alice, 'foods/fpriv'))));

console.log('\n== video hướng dẫn (spec 006): mẩu trong Firestore ==');
const chunk = (owner, videoId, index, size = 1000, over = {}) => ({ ownerId: owner, videoId, index, data: Bytes.fromUint8Array(new Uint8Array(size)), ...over });
const pad = (i) => String(i).padStart(2, '0');
await t('chủ công thức ghi mẩu video', assertSucceeds(setDoc(doc(alice, `recipes/ra/videoChunks/vid001_${pad(0)}`), chunk('alice', 'vid001', 0, 750000))));
await t('chủ công thức đọc mẩu video', assertSucceeds(getDoc(doc(alice, 'recipes/ra/videoChunks/vid001_00'))));
await t('bob không đọc được mẩu video của alice', assertFails(getDoc(doc(bob, 'recipes/ra/videoChunks/vid001_00'))));
await t('admin (claim) cũng không đọc được', assertFails(getDoc(doc(env.authenticatedContext('vidadmin', { admin: true }).firestore(), 'recipes/ra/videoChunks/vid001_00'))));
await t('bob không ghi mẩu vào công thức của alice', assertFails(setDoc(doc(bob, 'recipes/ra/videoChunks/vid002_00'), chunk('bob', 'vid002', 0))));
await t('mẩu quá 750 000 byte bị từ chối', assertFails(setDoc(doc(alice, 'recipes/ra/videoChunks/vid001_01'), chunk('alice', 'vid001', 1, 750001))));
await t('mẩu không phải bytes bị từ chối', assertFails(setDoc(doc(alice, 'recipes/ra/videoChunks/vid001_01'), chunk('alice', 'vid001', 1, 10, { data: 'abc' }))));
await t('chỉ số mẩu ≥ 28 bị từ chối', assertFails(setDoc(doc(alice, 'recipes/ra/videoChunks/vid001_28'), chunk('alice', 'vid001', 28))));
await t('tên mẩu không khớp videoId bị từ chối', assertFails(setDoc(doc(alice, 'recipes/ra/videoChunks/khac_00'), chunk('alice', 'vid001', 0))));
await t('trường lạ trong mẩu bị từ chối', assertFails(setDoc(doc(alice, 'recipes/ra/videoChunks/vid001_02'), chunk('alice', 'vid001', 2, 10, { note: 'x' }))));
await t('đặt thông tin video trên công thức', assertSucceeds(updateDoc(doc(alice, 'recipes/ra'), { video: { id: 'vid001', chunkCount: 1, sizeBytes: 750000, durationMs: 2333, mime: 'video/mp4' } })));
await t('chunkCount > 28 bị từ chối', assertFails(updateDoc(doc(alice, 'recipes/ra'), { video: { id: 'vid001', chunkCount: 29, sizeBytes: 1 } })));
await t('video quá 21 MB bị từ chối', assertFails(updateDoc(doc(alice, 'recipes/ra'), { video: { id: 'vid001', chunkCount: 28, sizeBytes: 21000001 } })));
await t('xoá thông tin video (null)', assertSucceeds(updateDoc(doc(alice, 'recipes/ra'), { video: null })));
await t('bob không xoá mẩu của alice', assertFails(deleteDoc(doc(bob, 'recipes/ra/videoChunks/vid001_00'))));
await t('alice xoá mẩu của mình', assertSucceeds(deleteDoc(doc(alice, 'recipes/ra/videoChunks/vid001_00'))));
await env.withSecurityRulesDisabled(async (ctx) => {
  const db = ctx.firestore();
  await setDoc(doc(db, 'users/vlock'), { role: 'blogger', isLocked: true });
  await setDoc(doc(db, 'recipes/rvl'), recipe('vlock'));
  await setDoc(doc(db, 'recipes/rvl/videoChunks/v1_00'), chunk('vlock', 'v1', 0));
});
await t('tài khoản bị khoá không đọc mẩu video', assertFails(getDoc(doc(env.authenticatedContext('vlock').firestore(), 'recipes/rvl/videoChunks/v1_00'))));

console.log('\n== chuyển dữ liệu cũ: đúng dạng mà LegacyMigrationService ghi ==');
const migrated = (ownerId, over = {}) => ({
  ...recipe(ownerId),
  title: 'Thịt kho cũ',
  baseServings: 4,
  createdAt: new Date('2025-01-02T03:04:05Z'),
  updatedAt: new Date(),
  legacy: {
    title: 'Thịt kho cũ',
    ingredients: ['500g thịt ba chỉ', 'nước mắm vừa đủ'],
    instructions: '1. Luộc trứng\n2. Kho thịt',
    sourceCollection: 'foods',
    migratedAt: new Date(),
    extra: { time: '45 phút', difficulty: 'Dễ', servings: '4 người' },
  },
  ...over,
});
await t('alice ghi recipes/{foodId} kèm legacy và extra', assertSucceeds(setDoc(doc(alice, 'recipes/old-food-1'), migrated('alice'))));
await t('bản chuyển có dòng và bước giữ chỗ được chấp nhận', assertSucceeds(setDoc(doc(alice, 'recipes/old-food-2'), migrated('alice', {
  title: '(Món chưa đặt tên)',
  ingredients: [{ id: 'f_i0', name: '(Chưa có nguyên liệu)', isPlaceholder: true }],
  steps: [{ id: 'f_s0', order: 1, text: '(Chưa có hướng dẫn)', isPlaceholder: true }],
}))));
await t('ghi theo lô 20 công thức chuyển', (async () => {
  const batch = writeBatch(alice);
  for (let i = 0; i < 20; i++) batch.set(doc(alice, `recipes/batch-${i}`), migrated('alice'));
  await assertSucceeds(batch.commit());
})());
await t('không ghi hộ công thức cho tài khoản khác', assertFails(setDoc(doc(alice, 'recipes/old-food-3'), migrated('bob'))));
await t('alice đọc danh sách recipes của mình sau khi chuyển', (async () => {
  const snap = await assertSucceeds(getDocs(query(collection(alice, 'recipes'), where('ownerId', '==', 'alice'))));
  if (snap.size < 22) throw new Error('chỉ thấy ' + snap.size + ' công thức');
})());
await t('đặt cờ recipeMigratedAt bằng merge trên hồ sơ có sẵn', assertSucceeds(setDoc(doc(alice, 'users/alice'), { recipeMigratedAt: new Date() }, { merge: true })));
await t('tạo hồ sơ mới chỉ với cờ recipeMigratedAt (không có role) được chấp nhận', assertSucceeds(setDoc(doc(env.authenticatedContext('zed').firestore(), 'users/zed'), { recipeMigratedAt: new Date() }, { merge: true })));
await t('không dùng merge để tự nâng role', assertFails(setDoc(doc(alice, 'users/alice'), { recipeMigratedAt: new Date(), role: 'admin' }, { merge: true })));
await t('bob không đặt được cờ cho alice', assertFails(setDoc(doc(bob, 'users/alice'), { recipeMigratedAt: new Date() }, { merge: true })));

console.log('\n== users: riêng tư (vá lộ hồ sơ) ==');
await t('alice đọc hồ sơ của mình', assertSucceeds(getDoc(doc(alice, 'users/alice'))));
await t('bob không đọc được hồ sơ của alice', assertFails(getDoc(doc(bob, 'users/alice'))));
await t('không ai liệt kê được collection users', assertFails(getDocs(collection(alice, 'users'))));
await t('không tra được email theo username (kiểu đăng nhập cũ)', assertFails(getDocs(query(collection(bob, 'users'), where('username', '==', 'alice')))));
await t('chưa đăng nhập: không tra được users', assertFails(getDocs(query(collection(anon, 'users'), where('username', '==', 'alice')))));
await t('chưa đăng nhập: không đọc được hồ sơ', assertFails(getDoc(doc(anon, 'users/alice'))));
await t('role=admin trong Firestore (không có claim) không đọc được hồ sơ người khác', assertFails(getDoc(doc(admin, 'users/alice'))));
await t('người mới đăng ký làm blogger', assertSucceeds(setDoc(doc(env.authenticatedContext('dan').firestore(), 'users/dan'), { role: 'blogger', isLocked: false, followers: [] })));
await t('người mới không đăng ký làm admin', assertFails(setDoc(doc(env.authenticatedContext('eve').firestore(), 'users/eve'), { role: 'admin' })));
await t('người mới không tạo hồ sơ với isLocked = true', assertFails(setDoc(doc(env.authenticatedContext('fay').firestore(), 'users/fay'), { role: 'blogger', isLocked: true })));
await t('không lưu mật khẩu khi tạo hồ sơ', assertFails(setDoc(doc(env.authenticatedContext('gus').firestore(), 'users/gus'), { role: 'blogger', password: '123456' })));
await t('không thêm mật khẩu vào hồ sơ có sẵn', assertFails(updateDoc(doc(alice, 'users/alice'), { password: '123456' })));
await t('alice sửa tên hiển thị của mình', assertSucceeds(updateDoc(doc(alice, 'users/alice'), { name: 'Alice' })));
await t('tài khoản bị khoá không tự mở khoá', assertFails(updateDoc(doc(env.authenticatedContext('lock').firestore(), 'users/lock'), { isLocked: false })));
await t('alice không follow / sửa hồ sơ của bob', assertFails(updateDoc(doc(alice, 'users/bob'), { followers: arrayUnion('alice') })));
await t('role=admin trong Firestore (không có claim) không đổi được role người khác', assertFails(updateDoc(doc(admin, 'users/bob'), { role: 'admin' })));
await t('bob không xoá hồ sơ của alice', assertFails(deleteDoc(doc(bob, 'users/alice'))));

console.log('\n== quản trị (spec 002): quyền qua custom claim ==');
const boss = env.authenticatedContext('boss', { admin: true }).firestore();
await env.withSecurityRulesDisabled(async (ctx) => {
  const db = ctx.firestore();
  await setDoc(doc(db, 'users/boss'), { role: 'blogger', isLocked: false, name: 'Boss' });
  await setDoc(doc(db, 'users/kim'), { role: 'blogger', isLocked: false, name: 'Kim', email: 'kim@example.com' });
  await setDoc(doc(db, 'recipes/rk'), recipe('kim'));
});
const kim = env.authenticatedContext('kim').firestore();
await t('admin (claim) liệt kê được users', assertSucceeds(getDocs(collection(boss, 'users'))));
await t('admin (claim) đọc được hồ sơ người khác', assertSucceeds(getDoc(doc(boss, 'users/alice'))));
await t('admin KHÔNG đọc được công thức riêng của người khác', assertFails(getDoc(doc(boss, 'recipes/ra'))));
await t('admin KHÔNG liệt kê được công thức của người khác', assertFails(getDocs(query(collection(boss, 'recipes'), where('ownerId', '==', 'alice')))));
await t('admin không sửa tên người khác', assertFails(updateDoc(doc(boss, 'users/alice'), { name: 'Hacked' })));
await t('admin không cấp role cho người khác', assertFails(updateDoc(doc(boss, 'users/alice'), { role: 'admin' })));
await t('admin không tự khoá chính mình', assertFails(updateDoc(doc(boss, 'users/boss'), { isLocked: true })));
await t('isLocked phải là bool', assertFails(updateDoc(doc(boss, 'users/kim'), { isLocked: 'yes' })));
await t('người thường không tự khoá/mở khoá người khác', assertFails(updateDoc(doc(alice, 'users/kim'), { isLocked: true })));
await t('claim admin = false không có quyền', assertFails(getDocs(collection(env.authenticatedContext('x', { admin: false }).firestore(), 'users'))));

console.log('\n== tài khoản bị khoá ==');
await t('kim (chưa khoá) đọc được công thức của mình', assertSucceeds(getDoc(doc(kim, 'recipes/rk'))));
await t('admin khoá kim', assertSucceeds(updateDoc(doc(boss, 'users/kim'), { isLocked: true, lockedAt: new Date() })));
await t('kim bị khoá: không đọc được công thức của mình', assertFails(getDoc(doc(kim, 'recipes/rk'))));
await t('kim bị khoá: không liệt kê được', assertFails(getDocs(query(collection(kim, 'recipes'), where('ownerId', '==', 'kim')))));
await t('kim bị khoá: không tạo công thức', assertFails(setDoc(doc(kim, 'recipes/rk2'), recipe('kim'))));
await t('kim bị khoá: không sửa công thức', assertFails(updateDoc(doc(kim, 'recipes/rk'), { title: 'x' })));
await t('kim bị khoá: không xoá công thức', assertFails(deleteDoc(doc(kim, 'recipes/rk'))));
await t('kim bị khoá: không tự mở khoá', assertFails(updateDoc(doc(kim, 'users/kim'), { isLocked: false })));
await t('kim bị khoá: vẫn đọc được hồ sơ của mình (để app biết mà đăng xuất)', assertSucceeds(getDoc(doc(kim, 'users/kim'))));
await t('admin mở khoá kim', assertSucceeds(updateDoc(doc(boss, 'users/kim'), { isLocked: false, lockedAt: null })));
await t('kim mở khoá: đọc lại được công thức, dữ liệu còn nguyên', (async () => {
  const snap = await assertSucceeds(getDoc(doc(kim, 'recipes/rk')));
  if (snap.data().title !== 'Thịt kho') throw new Error('dữ liệu bị đổi');
})());
await t('người không có hồ sơ users vẫn dùng recipes bình thường', assertSucceeds(setDoc(doc(env.authenticatedContext('nouser').firestore(), 'recipes/rn'), recipe('nouser'))));

console.log('\n== thực đơn tuần, đi chợ (spec 003) ==');
const plan = (owner, over = {}) => ({ ownerId: owner, weekStart: '2026-11-09', entries: [{ id: 'e', day: 1, slot: 'dinner', recipeId: 'r', title: 'Phở', servings: 2 }], ...over });
const shop = (owner, over = {}) => ({ ownerId: owner, weekStart: '2026-11-09', checked: ['trung|quả'], extras: [], ...over });
await t('alice tạo thực đơn tuần của mình', assertSucceeds(setDoc(doc(alice, 'weekPlans/alice_2026-11-09'), plan('alice'))));
await t('alice đọc thực đơn của mình', assertSucceeds(getDoc(doc(alice, 'weekPlans/alice_2026-11-09'))));
await t('alice đọc tuần chưa có (không lỗi quyền)', assertSucceeds(getDoc(doc(alice, 'weekPlans/alice_2026-11-16'))));
await t('alice sửa thực đơn của mình', assertSucceeds(setDoc(doc(alice, 'weekPlans/alice_2026-11-09'), plan('alice', { entries: [] }))));
await t('bob không đọc được thực đơn của alice', assertFails(getDoc(doc(bob, 'weekPlans/alice_2026-11-09'))));
await t('bob không ghi đè thực đơn của alice', assertFails(setDoc(doc(bob, 'weekPlans/alice_2026-11-09'), plan('alice'))));
await t('bob không tạo tài liệu mang id của alice', assertFails(setDoc(doc(bob, 'weekPlans/alice_2026-11-23'), plan('bob', { weekStart: '2026-11-23' }))));
await t('id phải khớp weekStart', assertFails(setDoc(doc(alice, 'weekPlans/alice_2026-11-09'), plan('alice', { weekStart: '2026-11-16' }))));
await t('id sai định dạng bị từ chối', assertFails(setDoc(doc(alice, 'weekPlans/alice_tuan-nay'), plan('alice', { weekStart: 'tuan-nay' }))));
await t('quá 63 món một tuần bị từ chối', assertFails(setDoc(doc(alice, 'weekPlans/alice_2026-11-09'), plan('alice', { entries: Array.from({ length: 64 }, (_, i) => ({ id: `e${i}` })) }))));
await t('không liệt kê được weekPlans', assertFails(getDocs(collection(alice, 'weekPlans'))));
await t('admin (claim) không đọc được thực đơn của người khác', assertFails(getDoc(doc(boss, 'weekPlans/alice_2026-11-09'))));
await t('chưa đăng nhập: không đọc', assertFails(getDoc(doc(anon, 'weekPlans/alice_2026-11-09'))));
await t('alice lưu trạng thái đi chợ', assertSucceeds(setDoc(doc(alice, 'shoppingLists/alice_2026-11-09'), shop('alice'))));
await t('bob không đọc danh sách đi chợ của alice', assertFails(getDoc(doc(bob, 'shoppingLists/alice_2026-11-09'))));
await t('quá 100 món lẻ bị từ chối', assertFails(setDoc(doc(alice, 'shoppingLists/alice_2026-11-09'), shop('alice', { extras: Array.from({ length: 101 }, (_, i) => ({ id: `x${i}` })) }))));
await t('checked phải là danh sách', assertFails(setDoc(doc(alice, 'shoppingLists/alice_2026-11-09'), shop('alice', { checked: 'all' }))));
await env.withSecurityRulesDisabled(async (ctx) => { await setDoc(doc(ctx.firestore(), 'users/lock'), { role: 'blogger', isLocked: true }); });
const locked = env.authenticatedContext('lock').firestore();
await t('tài khoản bị khoá không ghi thực đơn', assertFails(setDoc(doc(locked, 'weekPlans/lock_2026-11-09'), plan('lock'))));
await t('tài khoản bị khoá không đọc danh sách đi chợ', assertFails(getDoc(doc(locked, 'shoppingLists/lock_2026-11-09'))));

console.log('\n== cộng đồng (spec 004): kiểm duyệt tự động ==');
const goodPost = (uid, recipeId, over = {}) => ({
  authorId: uid, authorName: 'Bếp nhà ' + uid, sourceRecipeId: recipeId,
  title: 'Thịt kho trứng', note: 'Kho lửa nhỏ cho thấm.', baseServings: 4, tags: ['cơm nhà'],
  ingredients: [{ id: 'a', name: 'thịt ba chỉ', quantity: 500, unit: 'g' }, { id: 'b', name: 'trứng vịt', quantity: 6, unit: 'quả' }],
  steps: [{ id: 's1', order: 1, text: 'Luộc trứng 10 phút rồi bóc vỏ.' }, { id: 's2', order: 2, text: 'Kho thịt với nước dừa 45 phút.' }],
  status: 'visible', reportCount: 0, createdAt: serverTimestamp(), updatedAt: serverTimestamp(), ...over,
});
// Đăng bài đúng cách: cùng batch đặt users/{uid}.lastPostAt = thời gian máy chủ.
const publish = (db, uid, recipeId, over = {}) => {
  const b = writeBatch(db);
  b.set(doc(db, `users/${uid}`), { lastPostAt: serverTimestamp() }, { merge: true });
  b.set(doc(db, `communityPosts/${uid}_${recipeId}`), goodPost(uid, recipeId, over));
  return b.commit();
};
const cA = env.authenticatedContext('ca').firestore();
const cB = env.authenticatedContext('cb').firestore();
const cC = env.authenticatedContext('cc').firestore();
const cD = env.authenticatedContext('cd').firestore();
const cE = env.authenticatedContext('ce').firestore();
await t('bài hợp lệ được đăng', assertSucceeds(publish(cA, 'ca', 'r1')));
await t('người khác đọc được bài đang hiện', assertSucceeds(getDoc(doc(cB, 'communityPosts/ca_r1'))));
await t('liệt kê bài đang hiện', assertSucceeds(getDocs(query(collection(cB, 'communityPosts'), where('status', '==', 'visible')))));
await t('chưa đăng nhập không đọc được', assertFails(getDoc(doc(anon, 'communityPosts/ca_r1'))));
await t('chống spam: bài thứ 2 trong vòng 2 phút bị chặn', assertFails(publish(cA, 'ca', 'r2')));
await t('không đặt lastPostAt thì không đăng được', assertFails(setDoc(doc(cB, 'communityPosts/cb_r9'), goodPost('cb', 'r9'))));
await t('không tự lùi lastPostAt về quá khứ để lách', assertFails(setDoc(doc(cB, 'users/cb'), { lastPostAt: Timestamp.fromDate(new Date('2020-01-01')) }, { merge: true })));
const bad = async (name, over, who = 'cb') => {
  await t('chặn: ' + name, assertFails(publish(env.authenticatedContext(who).firestore(), who, 'x' + Math.random().toString(36).slice(2, 7), over)));
};
await bad('tên quá ngắn', { title: 'ab' });
await bad('tên không có chữ', { title: '12345 !!!' });
await bad('tên gõ bừa lặp ký tự', { title: 'ngonnnnnn quá' });
await bad('tên có link', { title: 'Mua ngay tại shop.vn nhé' });
await bad('link trong ghi chú', { note: 'Xem thêm https://spam.example' });
await bad('link xuống dòng trong ghi chú', { note: 'Ngon lắm.\nChi tiết: www.quangcao.xyz' });
await bad('từ cấm trong tên', { title: 'Nhận vay tiền nhanh' });
await bad('từ cấm viết hoa', { title: 'CASINO uy tín' });
await bad('từ cấm trong bước nấu', { steps: [{ id: 's1', order: 1, text: 'Liên hệ zalo: 0909 để mua' }, { id: 's2', order: 2, text: 'Kho thịt với nước dừa.' }] });
await bad('chỉ 1 nguyên liệu', { ingredients: [{ id: 'a', name: 'thịt ba chỉ' }] });
await bad('chỉ 1 bước', { steps: [{ id: 's1', order: 1, text: 'Luộc trứng 10 phút rồi bóc vỏ.' }] });
await bad('bước nấu quá ngắn', { steps: [{ id: 's1', order: 1, text: 'nấu' }, { id: 's2', order: 2, text: 'Kho thịt với nước dừa.' }] });
await bad('nguyên liệu 1 ký tự', { ingredients: [{ id: 'a', name: 'x' }, { id: 'b', name: 'trứng' }] });
await bad('ghi chú quá dài', { note: 'a b '.repeat(300) });
await bad('tự đặt trạng thái khác "visible"', { status: 'hidden' });
await bad('tự đặt số báo cáo', { reportCount: -5 });
await bad('đăng hộ người khác', { authorId: 'ca' });
await t('không bị chặn nhầm: "lồng đèn", "đụng", "sexy"? (chỉ "lồng")', assertSucceeds(publish(cC, 'cc', 'r1', { title: 'Bánh trung thu lồng đèn' })));
await t('bài vào sai id (không khớp sourceRecipeId) bị chặn', assertFails((async () => {
  const b = writeBatch(cD); b.set(doc(cD, 'users/cd'), { lastPostAt: serverTimestamp() }, { merge: true });
  b.set(doc(cD, 'communityPosts/cd_khac'), goodPost('cd', 'r1')); await b.commit();
})()));
await t('tác giả chia sẻ lại (cập nhật nội dung)', assertSucceeds(updateDoc(doc(cA, 'communityPosts/ca_r1'), { title: 'Thịt kho trứng vịt', updatedAt: serverTimestamp() })));
await t('tác giả không sửa thành nội dung bẩn', assertFails(updateDoc(doc(cA, 'communityPosts/ca_r1'), { title: 'casino', updatedAt: serverTimestamp() })));
await t('người khác không sửa bài', assertFails(updateDoc(doc(cB, 'communityPosts/ca_r1'), { title: 'Của tôi', updatedAt: serverTimestamp() })));

console.log('\n== cộng đồng: báo cáo ==');
const report = (db, uid, postId, reason = 'spam', bump = 1, status) => {
  const b = writeBatch(db);
  b.set(doc(db, `communityPosts/${postId}/reports/${uid}`), { reason, createdAt: serverTimestamp() });
  const upd = { reportCount: increment(bump) };
  if (status) upd.status = status;
  b.update(doc(db, `communityPosts/${postId}`), upd);
  return b.commit();
};
await t('tác giả không tự báo cáo bài mình', assertFails(report(cA, 'ca', 'ca_r1')));
await t('báo cáo không tăng bộ đếm thì bị chặn', assertFails(setDoc(doc(cB, 'communityPosts/ca_r1/reports/cb'), { reason: 'spam', createdAt: serverTimestamp() })));
await t('tăng bộ đếm 2 đơn vị bị chặn', assertFails(report(cB, 'cb', 'ca_r1', 'spam', 2)));
await t('lý do lạ bị chặn', assertFails(report(cB, 'cb', 'ca_r1', 'ghét')));
await t('báo cáo hợp lệ (1/3)', assertSucceeds(report(cB, 'cb', 'ca_r1')));
await t('mỗi người chỉ báo cáo một lần', assertFails(report(cB, 'cb', 'ca_r1')));
await t('báo cáo thứ 2 (2/3)', assertSucceeds(report(cC, 'cc', 'ca_r1', 'not_recipe')));
await t('báo cáo thứ 3 mà không ẩn bài bị chặn', assertFails(report(cD, 'cd', 'ca_r1', 'offensive')));
await t('báo cáo thứ 3 ẩn bài', assertSucceeds(report(cD, 'cd', 'ca_r1', 'offensive', 1, 'hidden')));
await t('bài ẩn: người khác không đọc được', assertFails(getDoc(doc(cE, 'communityPosts/ca_r1'))));
await t('bài ẩn: tác giả vẫn đọc được', assertSucceeds(getDoc(doc(cA, 'communityPosts/ca_r1'))));
await t('tác giả không tự mở lại bài bị ẩn / xoá báo cáo', assertFails(updateDoc(doc(cA, 'communityPosts/ca_r1'), { reportCount: 0, status: 'visible', updatedAt: serverTimestamp() })));
await t('người thường không đọc báo cáo', assertFails(getDocs(collection(cE, 'communityPosts/ca_r1/reports'))));

console.log('\n== cộng đồng: quản trị viên ==');
await t('admin đọc bài ẩn', assertSucceeds(getDoc(doc(boss, 'communityPosts/ca_r1'))));
await t('admin liệt kê mọi bài (thống kê)', assertSucceeds(getDocs(collection(boss, 'communityPosts'))));
await t('admin đọc báo cáo', assertSucceeds(getDocs(collection(boss, 'communityPosts/ca_r1/reports'))));
await t('admin khôi phục bài, đặt lại báo cáo', assertSucceeds(updateDoc(doc(boss, 'communityPosts/ca_r1'), { status: 'visible', reportCount: 0, updatedAt: serverTimestamp() })));
await t('admin không sửa nội dung bài', assertFails(updateDoc(doc(boss, 'communityPosts/ca_r1'), { title: 'Sửa bởi admin' })));
await t('admin gỡ bài', assertSucceeds(updateDoc(doc(boss, 'communityPosts/cc_r1'), { status: 'removed', updatedAt: serverTimestamp() })));
await t('người thường không đổi trạng thái bài', assertFails(updateDoc(doc(cE, 'communityPosts/ca_r1'), { status: 'removed' })));
await t('tác giả gỡ bài của mình', assertSucceeds(deleteDoc(doc(cA, 'communityPosts/ca_r1'))));
await t('tài khoản bị khoá không đăng bài', assertFails(publish(locked, 'lock', 'r1')));
await t('tài khoản bị khoá không đọc cộng đồng', assertFails(getDocs(query(collection(locked, 'communityPosts'), where('status', '==', 'visible')))));

console.log('\n== cộng đồng (spec 007): thích, nổi bật, huy hiệu admin, thông báo ==');
const lA = env.authenticatedContext('la').firestore();
const lB = env.authenticatedContext('lb').firestore();
const lC = env.authenticatedContext('lc').firestore();
const lAdmin = env.authenticatedContext('ladmin', { admin: true }).firestore();
await t('bài mới đăng được (bắt đầu 0 lượt thích)', assertSucceeds(publish(lA, 'la', 'r1')));
await t('tự đặt featured khi đăng bị chặn', assertFails(publish(lB, 'lb', 'r1', { featured: true })));
await t('tự đặt sẵn lượt thích khi đăng bị chặn', assertFails(publish(lB, 'lb', 'r2', { likedBy: ['x', 'y'] })));
await t('người thường tự gắn huy hiệu admin bị chặn', assertFails(publish(lB, 'lb', 'r3', { byAdmin: true })));
await t('admin đăng bài phải có huy hiệu admin', assertFails(publish(lAdmin, 'ladmin', 'r1')));
await t('admin đăng bài kèm huy hiệu admin', assertSucceeds(publish(lAdmin, 'ladmin', 'r2', { byAdmin: true })));
const pA = doc(lB, 'communityPosts/la_r1');
await t('người khác thích bài', assertSucceeds(updateDoc(pA, { likedBy: arrayUnion('lb') })));
await t('thích lần 2 (không đổi gì) không lách được', assertFails(updateDoc(pA, { likedBy: ['lb', 'lb'] })));
await t('thích hộ người khác bị chặn', assertFails(updateDoc(doc(lC, 'communityPosts/la_r1'), { likedBy: arrayUnion('zz') })));
await t('xoá lượt thích của người khác bị chặn', assertFails(updateDoc(doc(lC, 'communityPosts/la_r1'), { likedBy: arrayRemove('lb') })));
await t('người thứ hai thích bài', assertSucceeds(updateDoc(doc(lC, 'communityPosts/la_r1'), { likedBy: arrayUnion('lc') })));
await t('thích kèm sửa trường khác bị chặn', assertFails(updateDoc(doc(lC, 'communityPosts/la_r1'), { likedBy: arrayRemove('lc'), title: 'Đổi tên' })));
await t('bỏ thích', assertSucceeds(updateDoc(pA, { likedBy: arrayRemove('lb') })));
await t('tác giả không tự thích bài mình', assertFails(updateDoc(doc(lA, 'communityPosts/la_r1'), { likedBy: arrayUnion('la') })));
await t('tác giả chia sẻ lại không xoá được lượt thích', assertFails(updateDoc(doc(lA, 'communityPosts/la_r1'), { likedBy: [], updatedAt: serverTimestamp() })));
await t('tác giả không tự ghim nổi bật', assertFails(updateDoc(doc(lA, 'communityPosts/la_r1'), { featured: true, updatedAt: serverTimestamp() })));
await t('tác giả chia sẻ lại (giữ nguyên lượt thích)', assertSucceeds(updateDoc(doc(lA, 'communityPosts/la_r1'), { note: 'Thêm trứng cút cũng ngon.', updatedAt: serverTimestamp() })));
await t('người thường không ghim nổi bật', assertFails(updateDoc(pA, { featured: true })));
await t('admin ghim nổi bật', assertSucceeds(updateDoc(doc(lAdmin, 'communityPosts/la_r1'), { featured: true, updatedAt: serverTimestamp() })));
await t('admin đặt featured không phải bool bị chặn', assertFails(updateDoc(doc(lAdmin, 'communityPosts/la_r1'), { featured: 'yes', updatedAt: serverTimestamp() })));
await t('admin không sửa lượt thích', assertFails(updateDoc(doc(lAdmin, 'communityPosts/la_r1'), { likedBy: [], updatedAt: serverTimestamp() })));
await t('admin bỏ ghim', assertSucceeds(updateDoc(doc(lAdmin, 'communityPosts/la_r1'), { featured: false, updatedAt: serverTimestamp() })));
await t('admin ẩn bài', assertSucceeds(updateDoc(doc(lAdmin, 'communityPosts/la_r1'), { status: 'hidden', updatedAt: serverTimestamp() })));
await t('không thích được bài đang ẩn', assertFails(updateDoc(doc(lB, 'communityPosts/la_r1'), { likedBy: arrayUnion('lb') })));

const ann = (db) => doc(db, 'appConfig/announcement');
await t('người thường không viết thông báo', assertFails(setDoc(ann(lB), { text: 'Xin chào', updatedAt: serverTimestamp() })));
await t('admin viết thông báo', assertSucceeds(setDoc(ann(lAdmin), { text: 'Tuần này chủ đề: món chay!', updatedAt: serverTimestamp() })));
await t('mọi người đọc thông báo', assertSucceeds(getDoc(ann(lB))));
await t('chưa đăng nhập không đọc thông báo', assertFails(getDoc(ann(anon))));
await t('tài khoản bị khoá không đọc thông báo', assertFails(getDoc(ann(locked))));
await t('thông báo có link bị chặn', assertFails(setDoc(ann(lAdmin), { text: 'Ghé shop.vn nhé', updatedAt: serverTimestamp() })));
await t('thông báo quá 200 ký tự bị chặn', assertFails(setDoc(ann(lAdmin), { text: 'a b '.repeat(60), updatedAt: serverTimestamp() })));
await t('thông báo có trường lạ bị chặn', assertFails(setDoc(ann(lAdmin), { text: 'Hi', updatedAt: serverTimestamp(), pinned: true })));
await t('admin xoá nội dung thông báo (chuỗi rỗng)', assertSucceeds(setDoc(ann(lAdmin), { text: '', updatedAt: serverTimestamp() })));
await t('không ghi tài liệu cấu hình khác', assertFails(setDoc(doc(lAdmin, 'appConfig/other'), { text: 'x' })));

console.log('\n== collection của bản cũ: khoá ghi ==');
await t('alice không sửa được món cũ của mình', assertFails(updateDoc(doc(alice, 'foods/f1'), { title: 'mới' })));
await t('alice không xoá được món cũ của mình', assertFails(deleteDoc(doc(alice, 'foods/f1'))));
await t('alice không tạo món mới trong foods', assertFails(setDoc(doc(alice, 'foods/f9'), { authorId: 'alice', title: 'x' })));
await t('bob không thích (like) món của alice', assertFails(updateDoc(doc(bob, 'foods/f1'), { likedBy: arrayUnion('bob') })));
await t('bob không đọc món đã duyệt/chia sẻ của alice', assertFails(getDoc(doc(bob, 'foods/f1'))));
await t('admin không ghi vào foods', assertFails(updateDoc(doc(admin, 'foods/f1'), { isFeatured: true })));
await t('không đọc bình luận của món cũ', assertFails(getDocs(collection(alice, 'foods/f1/comments'))));
await t('không ghi đánh giá cho món cũ', assertFails(setDoc(doc(bob, 'foods/f1/ratings/bob'), { userId: 'bob', rating: 5 })));
await t('không tạo meal_plans', assertFails(setDoc(doc(alice, 'meal_plans/p1'), { userId: 'alice', name: 'p' })));
await t('không đọc meal_plans', assertFails(getDocs(query(collection(alice, 'meal_plans'), where('userId', '==', 'alice')))));
await t('không ghi vào collection followers', assertFails(setDoc(doc(bob, 'followers/x'), { a: 1 })));
await t('không đọc collection followers', assertFails(getDocs(collection(alice, 'followers'))));
await t('collection lạ bị từ chối mặc định', assertFails(setDoc(doc(alice, 'random/x'), { a: 1 })));

console.log('\n== hồ sơ: tên hiển thị, ảnh đại diện (spec 005) ==');
await t('alice đổi tên hiển thị', assertSucceeds(updateDoc(doc(alice, 'users/alice'), { name: 'An Nguyễn' })));
await t('tên rỗng bị từ chối', assertFails(updateDoc(doc(alice, 'users/alice'), { name: '   ' })));
await t('tên quá 40 ký tự bị từ chối', assertFails(updateDoc(doc(alice, 'users/alice'), { name: 'a'.repeat(41) })));
await t('tên có link bị từ chối', assertFails(updateDoc(doc(alice, 'users/alice'), { name: 'shop.vn giá rẻ' })));
await t('tên có từ cấm bị từ chối', assertFails(updateDoc(doc(alice, 'users/alice'), { name: 'casino 88' })));
await t('ảnh đại diện là link Firebase Storage', assertSucceeds(updateDoc(doc(alice, 'users/alice'), { avatarUrl: 'https://firebasestorage.googleapis.com/v0/b/x/o/avatars%2Falice%2F1.jpg?alt=media&token=t' })));
await t('xoá ảnh đại diện (null)', assertSucceeds(updateDoc(doc(alice, 'users/alice'), { avatarUrl: null })));
await t('link ảnh tuỳ ý bị từ chối', assertFails(updateDoc(doc(alice, 'users/alice'), { avatarUrl: 'https://tracker.example/pixel.gif' })));
await t('bob không đổi tên của alice', assertFails(updateDoc(doc(bob, 'users/alice'), { name: 'Hacked' })));
const smallJpeg = 'data:image/jpeg;base64,' + 'A'.repeat(40000);
await t('ảnh đại diện lưu trong hồ sơ (data URI ~30 KB)', assertSucceeds(updateDoc(doc(alice, 'users/alice'), { avatarData: smallJpeg })));
await t('xoá ảnh đại diện trong hồ sơ (null)', assertSucceeds(updateDoc(doc(alice, 'users/alice'), { avatarData: null })));
await t('ảnh quá 150 000 ký tự bị từ chối', assertFails(updateDoc(doc(alice, 'users/alice'), { avatarData: 'data:image/jpeg;base64,' + 'A'.repeat(150001) })));
await t('không phải ảnh (svg/html) bị từ chối', assertFails(updateDoc(doc(alice, 'users/alice'), { avatarData: 'data:image/svg+xml;base64,PHN2Zz4=' })));
await t('chuỗi tuỳ ý không phải base64 bị từ chối', assertFails(updateDoc(doc(alice, 'users/alice'), { avatarData: 'data:image/png;base64,<script>' })));
await t('bob không đặt ảnh đại diện cho alice', assertFails(updateDoc(doc(bob, 'users/alice'), { avatarData: smallJpeg })));

console.log('\n== Storage: ảnh công thức ==');
const img = new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 1, 2, 3]);
const jpeg = { contentType: 'image/jpeg' };
const sAlice = env.authenticatedContext('alice').storage();
const sBob = env.authenticatedContext('bob').storage();
const sAnon = env.unauthenticatedContext().storage();
const own = 'foods/alice/recipes/r1/1.jpg';
await t('alice tải ảnh lên thư mục công thức của mình', assertSucceeds(uploadBytes(ref(sAlice, own), img, jpeg)));
await t('alice đọc ảnh của mình', assertSucceeds(getBytes(ref(sAlice, own))));
await t('bob không đọc ảnh của alice qua rules', assertFails(getBytes(ref(sBob, own))));
await t('chưa đăng nhập: không đọc qua rules', assertFails(getBytes(ref(sAnon, own))));
await t('bob không ghi vào thư mục của alice', assertFails(uploadBytes(ref(sBob, 'foods/alice/recipes/r1/2.jpg'), img, jpeg)));
await t('chưa đăng nhập: không tải lên được', assertFails(uploadBytes(ref(sAnon, 'foods/alice/recipes/r1/3.jpg'), img, jpeg)));
await t('không tải video', assertFails(uploadBytes(ref(sAlice, 'foods/alice/recipes/r1/v.mp4'), img, { contentType: 'video/mp4' })));
await t('không tải file không phải ảnh', assertFails(uploadBytes(ref(sAlice, 'foods/alice/recipes/r1/a.html'), img, { contentType: 'text/html' })));
await t('ảnh png được chấp nhận', assertSucceeds(uploadBytes(ref(sAlice, 'foods/alice/recipes/r1/p.png'), img, { contentType: 'image/png' })));
await t('ảnh trên 5 MB bị từ chối', assertFails(uploadBytes(ref(sAlice, 'foods/alice/recipes/r1/big.jpg'), new Uint8Array(5 * 1024 * 1024 + 1), jpeg)));
await t('không ghi vào food_images (thư mục cũ, trước đây ai cũng ghi được)', assertFails(uploadBytes(ref(sAlice, 'food_images/x.jpg'), img, jpeg)));
await t('không ghi vào avatars', assertFails(uploadBytes(ref(sAlice, 'avatars/alice.jpg'), img, jpeg)));
await t('không ghi video vào foods/{uid} (đường dẫn cũ)', assertFails(uploadBytes(ref(sAlice, 'foods/alice/video.mp4'), img, { contentType: 'video/mp4' })));
await t('bob không xoá ảnh của alice', assertFails(deleteObject(ref(sBob, own))));
await t('alice tải ảnh đại diện', assertSucceeds(uploadBytes(ref(sAlice, 'avatars/alice/1.jpg'), img, jpeg)));
await t('người đã đăng nhập khác đọc được ảnh đại diện', assertSucceeds(getBytes(ref(sBob, 'avatars/alice/1.jpg'))));
await t('chưa đăng nhập không đọc ảnh đại diện', assertFails(getBytes(ref(sAnon, 'avatars/alice/1.jpg'))));
await t('bob không ghi ảnh đại diện vào thư mục alice', assertFails(uploadBytes(ref(sBob, 'avatars/alice/2.jpg'), img, jpeg)));
await t('ảnh đại diện trên 2 MB bị từ chối', assertFails(uploadBytes(ref(sAlice, 'avatars/alice/big.jpg'), new Uint8Array(2 * 1024 * 1024 + 1), jpeg)));
await t('ảnh đại diện phải là ảnh', assertFails(uploadBytes(ref(sAlice, 'avatars/alice/a.gif'), img, { contentType: 'image/gif' })));
await t('bob không xoá ảnh đại diện của alice', assertFails(deleteObject(ref(sBob, 'avatars/alice/1.jpg'))));
await t('alice xoá ảnh đại diện của mình', assertSucceeds(deleteObject(ref(sAlice, 'avatars/alice/1.jpg'))));
await t('alice xoá ảnh của mình', assertSucceeds(deleteObject(ref(sAlice, own))));

console.log(`\n${pass} đạt, ${fail} lỗi`);
await env.cleanup();
process.exit(fail ? 1 : 0);
