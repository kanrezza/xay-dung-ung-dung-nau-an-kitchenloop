// Kiểm thử Firestore rules trên emulator.
// Chạy: npm test (trong thư mục rules_test, cần JDK 21+ và firebase-tools).
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
  doc, setDoc, updateDoc, getDoc, getDocs, deleteDoc, collection, query, where,
  arrayUnion, arrayRemove, writeBatch,
} from 'firebase/firestore';
import { ref, uploadBytes, getBytes, deleteObject } from 'firebase/storage';
import fs from 'fs';

const rulesPath = new URL('../firestore.rules', import.meta.url);
const storageRulesPath = new URL('../storage.rules', import.meta.url);
const env = await initializeTestEnvironment({
  projectId: 'demo-rules',
  firestore: { rules: fs.readFileSync(rulesPath, 'utf8'), host: '127.0.0.1', port: 8080 },
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
await t('admin cũng không đọc hồ sơ người khác từ app', assertFails(getDoc(doc(admin, 'users/alice'))));
await t('người mới đăng ký làm blogger', assertSucceeds(setDoc(doc(env.authenticatedContext('dan').firestore(), 'users/dan'), { role: 'blogger', isLocked: false, followers: [] })));
await t('người mới không đăng ký làm admin', assertFails(setDoc(doc(env.authenticatedContext('eve').firestore(), 'users/eve'), { role: 'admin' })));
await t('người mới không tạo hồ sơ với isLocked = true', assertFails(setDoc(doc(env.authenticatedContext('fay').firestore(), 'users/fay'), { role: 'blogger', isLocked: true })));
await t('không lưu mật khẩu khi tạo hồ sơ', assertFails(setDoc(doc(env.authenticatedContext('gus').firestore(), 'users/gus'), { role: 'blogger', password: '123456' })));
await t('không thêm mật khẩu vào hồ sơ có sẵn', assertFails(updateDoc(doc(alice, 'users/alice'), { password: '123456' })));
await t('alice sửa tên hiển thị của mình', assertSucceeds(updateDoc(doc(alice, 'users/alice'), { name: 'Alice' })));
await t('tài khoản bị khoá không tự mở khoá', assertFails(updateDoc(doc(env.authenticatedContext('lock').firestore(), 'users/lock'), { isLocked: false })));
await t('alice không follow / sửa hồ sơ của bob', assertFails(updateDoc(doc(alice, 'users/bob'), { followers: arrayUnion('alice') })));
await t('admin không đổi role của người khác từ app (chỉ qua Console)', assertFails(updateDoc(doc(admin, 'users/bob'), { role: 'admin' })));
await t('bob không xoá hồ sơ của alice', assertFails(deleteDoc(doc(bob, 'users/alice'))));

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
await t('alice xoá ảnh của mình', assertSucceeds(deleteObject(ref(sAlice, own))));

console.log(`\n${pass} đạt, ${fail} lỗi`);
await env.cleanup();
process.exit(fail ? 1 : 0);
