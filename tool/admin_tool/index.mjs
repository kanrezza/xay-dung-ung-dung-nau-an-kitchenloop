// Công cụ quản trị KitchenLoop (spec 002). Chạy TRÊN MÁY CHỦ DỰ ÁN, không nằm trong app.
//
// Cần khoá tài khoản dịch vụ (service account) của project Firebase:
//   Firebase Console → Project settings → Service accounts → Generate new private key
// Lưu thành tool/admin_tool/service-account.json (đã có trong .gitignore, KHÔNG commit)
// hoặc trỏ biến môi trường GOOGLE_APPLICATION_CREDENTIALS tới file đó.
//
// Cách dùng (trong thư mục tool/admin_tool, chạy `npm install` một lần):
//   node index.mjs grant <email>       cấp quyền quản trị (custom claim admin = true)
//   node index.mjs revoke <email>      thu quyền quản trị
//   node index.mjs list                liệt kê các tài khoản đang có quyền quản trị
//   node index.mjs seed-demo <email>   thêm 6 công thức mẫu cho tài khoản (để demo)
//
// Với Firestore emulator: đặt FIRESTORE_EMULATOR_HOST / FIREBASE_AUTH_EMULATOR_HOST trước khi chạy.
import { initializeApp, cert, applicationDefault } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import fs from 'fs';

const keyPath = new URL('./service-account.json', import.meta.url);
const usingEmulator = Boolean(process.env.FIRESTORE_EMULATOR_HOST || process.env.FIREBASE_AUTH_EMULATOR_HOST);
let credential;
if (fs.existsSync(keyPath)) {
  credential = cert(JSON.parse(fs.readFileSync(keyPath, 'utf8')));
} else if (process.env.GOOGLE_APPLICATION_CREDENTIALS || usingEmulator) {
  credential = usingEmulator ? undefined : applicationDefault();
} else {
  console.error('Thiếu khoá quản trị: đặt file tool/admin_tool/service-account.json (xem đầu file index.mjs).');
  process.exit(2);
}
initializeApp({ ...(credential ? { credential } : {}), ...(process.env.GCLOUD_PROJECT ? { projectId: process.env.GCLOUD_PROJECT } : {}) });
const auth = getAuth();
const db = getFirestore();

const [command, email, ...flags] = process.argv.slice(2);

async function userByEmail(e) {
  if (!e) {
    console.error('Thiếu email. Ví dụ: node index.mjs grant ban@example.com');
    process.exit(2);
  }
  try {
    return await auth.getUserByEmail(e);
  } catch {
    console.error(`Không tìm thấy tài khoản ${e}. Hãy đăng ký tài khoản này trong app trước.`);
    process.exit(1);
  }
}

// ----------------------------------------------------------------- dữ liệu demo
// Cùng dạng dữ liệu với lib/features/recipes/models (và cùng ràng buộc trong firestore.rules).
const ing = (id, name, quantity = null, unit = null, price = null, kcal = null) =>
  ({ id, name, quantity, unit, price, kcal, isPlaceholder: false });
const step = (id, order, text, durationSec = null) =>
  ({ id, order, text, imageUrl: null, durationSec, isPlaceholder: false });

const demoRecipes = {
  'demo-thit-kho': {
    title: 'Thịt kho trứng', baseServings: 4, tags: ['cơm nhà', 'món mặn'],
    note: 'Kho lửa nhỏ để thịt mềm và thấm. Ngon hơn khi để qua đêm.',
    ingredients: [
      ing('a1', 'thịt ba chỉ', 500, 'g', 75000, 2600), ing('a2', 'trứng vịt', 6, 'quả', 24000, 780),
      ing('a3', 'nước dừa', 400, 'ml', 15000, 76), ing('a4', 'nước mắm', 3, 'muỗng canh'),
      ing('a5', 'đường', 2, 'muỗng canh'), ing('a6', 'tỏi băm', 3, 'tép'), ing('a7', 'tiêu xay vừa đủ'),
    ],
    steps: [
      step('b1', 1, 'Luộc trứng khoảng 10 phút, ngâm nước lạnh rồi bóc vỏ.', 600),
      step('b2', 2, 'Thịt cắt miếng vừa ăn, ướp với nước mắm, đường và tỏi trong 20 phút.', 1200),
      step('b3', 3, 'Thắng đường lấy màu, cho thịt vào đảo đến khi săn lại.'),
      step('b4', 4, 'Đổ nước dừa, cho trứng vào, kho lửa nhỏ khoảng 45 phút.', 2700),
      step('b5', 5, 'Nêm lại cho vừa ăn, rắc tiêu rồi tắt bếp.'),
    ],
  },
  'demo-ga-ran': {
    title: 'Gà rán giòn', baseServings: 2, tags: ['món sinh viên', 'nhanh'], note: '',
    ingredients: [ing('c1', 'đùi gà', 4, 'cái', 60000), ing('c2', 'bột chiên giòn', 150, 'g', 12000), ing('c3', 'dầu ăn', 500, 'ml')],
    steps: [step('d1', 1, 'Ướp gà với muối tiêu.', 900), step('d2', 2, 'Lăn bột rồi chiên ngập dầu đến khi vàng giòn.', 720)],
  },
  'demo-canh-chua': {
    title: 'Canh chua cá lóc', baseServings: 4, tags: ['ăn kiêng', 'cơm nhà'], note: '',
    ingredients: [ing('e1', 'cá lóc', 1, 'con'), ing('e2', 'me chua', 50, 'g'), ing('e3', 'cà chua', 2, 'quả'), ing('e4', 'giá đỗ', 100, 'g')],
    steps: [step('f1', 1, 'Nấu nước me, lọc lấy nước chua.'), step('f2', 2, 'Cho cá vào nấu chín, thêm cà chua và giá.', 600)],
  },
  'demo-trung-chien': {
    title: 'Trứng chiên hành', baseServings: 1, tags: ['món sinh viên', 'nhanh'], note: '',
    ingredients: [ing('g1', 'trứng gà', 2, 'quả', 7000, 150), ing('g2', 'hành lá', 1, 'nhánh')],
    steps: [step('h1', 1, 'Đánh trứng với hành rồi chiên vàng hai mặt.', 300)],
  },
  'demo-pho-bo': {
    title: 'Phở bò', baseServings: 6, tags: ['cuối tuần'], note: 'Hầm xương càng lâu nước càng ngọt.',
    ingredients: [ing('i1', 'xương ống bò', 2, 'kg'), ing('i2', 'bánh phở', 1, 'kg'), ing('i3', 'thịt bò tái', 500, 'g'), ing('i4', 'quế, hồi, thảo quả vừa đủ')],
    steps: [step('j1', 1, 'Hầm xương lấy nước dùng.', 10800), step('j2', 2, 'Trụng bánh phở, xếp thịt, chan nước dùng thật nóng.')],
  },
  'demo-salad': {
    title: 'Salad ức gà', baseServings: 2, tags: ['ăn kiêng', 'nhanh'], note: '',
    ingredients: [ing('k1', 'ức gà', 300, 'g', 30000, 495), ing('k2', 'xà lách', 1, 'cây'), ing('k3', 'dầu ô liu', 2, 'muỗng canh')],
    steps: [step('l1', 1, 'Luộc ức gà rồi xé nhỏ.', 900), step('l2', 2, 'Trộn với rau và sốt.')],
  },
};

// ----------------------------------------------------------------- lệnh
switch (command) {
  case 'grant':
  case 'revoke': {
    const user = await userByEmail(email);
    const claims = { ...(user.customClaims ?? {}) };
    if (command === 'grant') claims.admin = true;
    else delete claims.admin;
    await auth.setCustomUserClaims(user.uid, claims);
    console.log(`${command === 'grant' ? 'Đã cấp' : 'Đã thu'} quyền quản trị: ${email} (${user.uid}).`);
    console.log('Mở lại màn hình Tài khoản trong app để thấy thay đổi.');
    break;
  }
  case 'list': {
    let page;
    let count = 0;
    do {
      page = await auth.listUsers(1000, page?.pageToken);
      for (const u of page.users) {
        if (u.customClaims?.admin === true) {
          console.log(`- ${u.email ?? '(không email)'}  ${u.uid}`);
          count++;
        }
      }
    } while (page.pageToken);
    console.log(count ? `${count} quản trị viên.` : 'Chưa có quản trị viên nào.');
    break;
  }
  case 'seed-demo': {
    const user = await userByEmail(email);
    const existing = await db.collection('recipes').where('ownerId', '==', user.uid).limit(1).get();
    if (!existing.empty && !flags.includes('--force')) {
      console.error(`${email} đã có công thức. Thêm --force để vẫn thêm công thức mẫu (ghi đè các bản demo-* nếu có).`);
      process.exit(1);
    }
    const batch = db.batch();
    for (const [id, r] of Object.entries(demoRecipes)) {
      batch.set(db.collection('recipes').doc(id.replace('demo-', `demo-${user.uid.slice(0, 6)}-`)), {
        ...r,
        ownerId: user.uid,
        imageUrl: '',
        schemaVersion: 1,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
    // Đánh dấu đã chuyển dữ liệu cũ để app không chạy bước chuyển cho tài khoản demo.
    batch.set(db.collection('users').doc(user.uid), { recipeMigratedAt: FieldValue.serverTimestamp() }, { merge: true });
    await batch.commit();
    console.log(`Đã thêm ${Object.keys(demoRecipes).length} công thức mẫu cho ${email}.`);
    break;
  }
  default:
    console.log('Lệnh: grant <email> | revoke <email> | list | seed-demo <email> [--force]');
    process.exit(command ? 2 : 0);
}
process.exit(0);
