// =====================================================================
//  작업자 앱 UI 문구 — 11개 언어
//  (표준 '내용'의 번역은 컨트롤타워에서 생성되어 DB에 저장됨. 여기는 화면 고정 문구만)
// =====================================================================
window.LANGS = [
  { code:'ko', name:'한국어' },      { code:'en', name:'English' },   { code:'zh', name:'中文' },
  { code:'ja', name:'日本語' },      { code:'vi', name:'Tiếng Việt' }, { code:'uz', name:'Oʻzbekcha' },
  { code:'ru', name:'Русский' },     { code:'ne', name:'नेपाली' },     { code:'kk', name:'Қазақша' },
  { code:'bn', name:'বাংলা' },       { code:'fr', name:'Français' },
];

// 각 키: [ko, en, zh, ja, vi, uz, ru, ne, kk, bn, fr]
const _T = {
  tab_safety:     ['안전','Safety','安全','安全','An toàn','Xavfsizlik','Безопасность','सुरक्षा','Қауіпсіздік','নিরাপত্তা','Sécurité'],
  tab_sop:        ['표준작업','Standard Work','标准作业','標準作業','Thao tác chuẩn','Standart ish','Стандарт работы','मानक कार्य','Стандартты жұмыс','মানক কাজ','Travail standard'],
  tab_inspection: ['자주검사','Self-Check','自主检查','自主検査','Tự kiểm tra','O‘z tekshiruvi','Самопроверка','स्व-जाँच','Өзін-өзі тексеру','স্ব-পরিদর্শন','Auto-contrôle'],
  tab_quality:    ['품질','Quality','质量','品質','Chất lượng','Sifat','Качество','गुणस्तर','Сапа','গুণমান','Qualité'],
  tab_abnormal:   ['이상조치','Abnormality','异常处理','異常処置','Bất thường','Nosozlik','Отклонения','असामान्यता','Ақаулық','অস্বাভাবিকতা','Anomalie'],

  sec_safety:     ['안전 유의사항','Safety Precautions','安全注意事项','安全注意事項','Lưu ý an toàn','Xavfsizlik qoidalari','Меры безопасности','सुरक्षा सावधानी','Қауіпсіздік шаралары','নিরাপত্তা সতর্কতা','Consignes de sécurité'],
  sec_sop:        ['표준작업','Standard Work','标准作业','標準作業','Thao tác chuẩn','Standart ish','Стандарт работы','मानक कार्य','Стандартты жұмыс','মানক কাজ','Travail standard'],
  sec_inspection: ['자주검사','Self-Check','自主检查','自主検査','Tự kiểm tra','O‘z tekshiruvi','Самопроверка','स्व-जाँच','Өзін-өзі тексеру','স্ব-পরিদর্শন','Auto-contrôle'],
  sec_quality:    ['품질 포인트','Quality Points','质量要点','品質ポイント','Điểm chất lượng','Sifat nuqtalari','Контроль качества','गुणस्तर बुँदा','Сапа нүктелері','গুণমান পয়েন্ট','Points qualité'],
  sec_abnormal:   ['이상발생 시 조치','Response to Abnormality','异常发生时的处理','異常発生時の処置','Xử lý khi bất thường','Nosozlikda choralar','Действия при отклонении','असामान्यता हुँदा','Ақаулық кезіндегі әрекет','অস্বাভাবিকতায় করণীয়','En cas d’anomalie'],

  full_video:     ['전체 공정 작업 영상 (처음~끝)','Full process video (start to finish)','全工序作业视频（从头到尾）','工程全体の作業動画（最初から最後まで）','Video toàn bộ công đoạn (từ đầu đến cuối)','To‘liq jarayon videosi (boshidan oxirigacha)','Видео всей операции (от начала до конца)','पूरा प्रक्रियाको भिडियो (सुरुदेखि अन्त्यसम्म)','Толық операция бейнесі (басынан соңына дейін)','সম্পূর্ণ প্রক্রিয়ার ভিডিও (শুরু থেকে শেষ)','Vidéo complète du poste (du début à la fin)'],
  steps:          ['작업 순서','Work Steps','作业步骤','作業手順','Các bước thao tác','Ish tartibi','Порядок работы','कार्य चरणहरू','Жұмыс тәртібі','কাজের ধাপ','Étapes de travail'],
  key_point:      ['급소','Key Point','要点','急所','Điểm then chốt','Asosiy nuqta','Ключевой момент','मुख्य बुँदा','Негізгі сәт','মূল বিষয়','Point clé'],
  notes:          ['참고','Notes','备注','参考','Ghi chú','Izoh','Примечание','टिप्पणी','Ескертпе','মন্তব্য','Remarques'],
  ppe:            ['개인보호구 (PPE)','Personal Protective Equipment','个人防护用品 (PPE)','保護具 (PPE)','Trang bị bảo hộ (PPE)','Shaxsiy himoya vositalari','Средства защиты (СИЗ)','व्यक्तिगत सुरक्षा उपकरण','Жеке қорғаныс құралдары','ব্যক্তিগত সুরক্ষা সরঞ্জাম','Équipements de protection (EPI)'],
  hazards:        ['위험 요인','Hazards','危险因素','危険要因','Mối nguy hiểm','Xavf omillari','Опасности','खतराहरू','Қауіп факторлары','বিপদসমূহ','Dangers'],
  rules:          ['안전 수칙','Safety Rules','安全规则','安全ルール','Quy tắc an toàn','Xavfsizlik qoidalari','Правила безопасности','सुरक्षा नियमहरू','Қауіпсіздік ережелері','নিরাপত্তা নিয়ম','Règles de sécurité'],
  quality_points: ['품질 관리 포인트','Quality Control Points','质量管理要点','品質管理ポイント','Điểm kiểm soát chất lượng','Sifat nazorati nuqtalari','Контрольные точки качества','गुणस्तर नियन्त्रण बुँदाहरू','Сапаны бақылау нүктелері','গুণমান নিয়ন্ত্রণ পয়েন্ট','Points de contrôle qualité'],
  spec:           ['기준','Spec','标准','基準','Tiêu chuẩn','Me’yor','Норма','मापदण्ड','Норма','মানদণ্ড','Norme'],
  defects:        ['주요 불량 유형','Major Defect Types','主要不良类型','主な不良タイプ','Các loại lỗi chính','Asosiy nuqson turlari','Основные дефекты','मुख्य त्रुटि प्रकार','Негізгі ақау түрлері','প্রধান ত্রুটির ধরন','Principaux défauts'],
  cause:          ['원인','Cause','原因','原因','Nguyên nhân','Sabab','Причина','कारण','Себебі','কারণ','Cause'],
  action:         ['조치','Action','措施','処置','Biện pháp','Chora','Действие','कारबाही','Әрекет','ব্যবস্থা','Action'],
  abnormal_cases: ['이상 발생 시 조치','Response to Abnormality','异常发生时的处理','異常発生時の処置','Xử lý khi có bất thường','Nosozlik yuz berganda','Действия при отклонении','असामान्यता हुँदा गर्नुपर्ने','Ақаулық кезіндегі әрекеттер','অস্বাভাবিকতায় করণীয়','Conduite en cas d’anomalie'],
  stop_line:      ['라인 정지','Stop Line','停线','ライン停止','Dừng dây chuyền','Liniyani to‘xtatish','Остановить линию','लाइन रोक्नुहोस्','Желіні тоқтату','লাইন বন্ধ করুন','Arrêt de ligne'],
  contact:        ['연락','Contact','联系','連絡','Liên hệ','Aloqa','Связаться','सम्पर्क','Байланыс','যোগাযোগ','Contact'],
  contacts:       ['비상 연락처','Emergency Contacts','紧急联系人','緊急連絡先','Liên hệ khẩn cấp','Favqulodda aloqa','Экстренные контакты','आपतकालीन सम्पर्क','Жедел байланыс','জরুরি যোগাযোগ','Contacts d’urgence'],
  call:           ['전화','Call','拨打','電話','Gọi','Qo‘ng‘iroq','Позвонить','फोन गर्नुहोस्','Қоңырау шалу','কল করুন','Appeler'],
  interval:       ['주기','Frequency','频率','頻度','Tần suất','Davriylik','Периодичность','आवृत्ति','Жиілік','পর্যায়কাল','Fréquence'],
  nok_action:     ['NOK 시','If NOK','NOK时','NOK時','Khi NOK','NOK bo‘lsa','При NOK','NOK भएमा','NOK болса','NOK হলে','Si NOK'],
  no_content:     ['아직 등록된 내용이 없습니다','No content registered yet','尚未登记内容','まだ登録された内容がありません','Chưa có nội dung','Hali ma’lumot kiritilmagan','Содержимое ещё не добавлено','अहिलेसम्म कुनै सामग्री छैन','Мазмұн әлі енгізілмеген','এখনও কোনো বিষয়বস্তু নেই','Aucun contenu enregistré'],
  valid:          ['유효','Valid','有效','有効','Còn hiệu lực','Amal qiladi','Действует','मान्य','Жарамды','বৈধ','Valide'],
  hour:           ['시간','h','小时','時間','giờ','soat','ч','घण्टा','сағ','ঘ.','h'],
  min:            ['분','min','分','分','phút','daq','мин','मिनेट','мин','মি.','min'],
  expired:        ['세션 만료','Session expired','会话已过期','セッション期限切れ','Phiên hết hạn','Sessiya tugadi','Сессия истекла','सत्र समाप्त','Сессия мерзімі өтті','সেশন শেষ','Session expirée'],
  expired_msg:    ['보안을 위해 12시간마다 QR코드를 다시 촬영해야 합니다.','For security, scan the QR code again every 12 hours.','为了安全，请每12小时重新扫描二维码。','セキュリティのため12時間ごとにQRコードを再度読み取ってください。','Vì bảo mật, hãy quét lại mã QR sau mỗi 12 giờ.','Xavfsizlik uchun har 12 soatda QR kodni qayta skanerlang.','В целях безопасности сканируйте QR-код каждые 12 часов.','सुरक्षाका लागि हरेक १२ घण्टामा QR कोड फेरि स्क्यान गर्नुहोस्।','Қауіпсіздік үшін әр 12 сағат сайын QR кодты қайта сканерлеңіз.','নিরাপত্তার জন্য প্রতি ১২ ঘণ্টায় QR কোড আবার স্ক্যান করুন।','Pour la sécurité, scannez à nouveau le QR code toutes les 12 heures.'],
  scan_title:     ['QR코드를 촬영해 주세요','Please scan the QR code','请扫描二维码','QRコードを読み取ってください','Vui lòng quét mã QR','QR kodni skanerlang','Отсканируйте QR-код','कृपया QR कोड स्क्यान गर्नुहोस्','QR кодты сканерлеңіз','অনুগ্রহ করে QR কোড স্ক্যান করুন','Veuillez scanner le QR code'],
  scan_msg:       ['설비에 부착된 QR코드를 카메라로 촬영하면 해당 공정의 표준이 열립니다.','Scan the QR code on the equipment with your camera to open its standard.','用相机扫描设备上的二维码即可打开该工序的标准。','設備に貼られたQRコードをカメラで読み取ると、その工程の標準が開きます。','Dùng camera quét mã QR trên thiết bị để mở tiêu chuẩn của công đoạn đó.','Uskunadagi QR kodni kamera bilan skanerlang — jarayon standarti ochiladi.','Отсканируйте QR-код на оборудовании, чтобы открыть стандарт операции.','उपकरणमा टाँसिएको QR कोड क्यामेराले स्क्यान गर्नुहोस्, उक्त प्रक्रियाको मानक खुल्छ।','Жабдықтағы QR кодты камерамен сканерлеңіз — операция стандарты ашылады.','যন্ত্রে লাগানো QR কোড ক্যামেরা দিয়ে স্ক্যান করলে সেই প্রক্রিয়ার মানক খুলবে।','Scannez le QR code sur l’équipement pour ouvrir le standard du poste.'],
  code_title:     ['최초 접속 등록','First-time Registration','首次登录注册','初回アクセス登録','Đăng ký lần đầu','Birinchi kirish','Первичная регистрация','पहिलो पटक दर्ता','Алғашқы тіркеу','প্রথমবার নিবন্ধন','Première inscription'],
  code_msg:       ['라인 관리자에게 받은 접속코드를 입력하세요. 이 휴대폰에서 한 번만 입력하면 됩니다.','Enter the access code from your line manager. Only once on this phone.','请输入线长提供的访问码。此手机只需输入一次。','ライン管理者から受け取ったアクセスコードを入力してください。このスマホでは一度だけです。','Nhập mã truy cập do quản lý dây chuyền cấp. Chỉ cần một lần trên điện thoại này.','Liniya boshlig‘idan olgan kirish kodini kiriting. Bu telefonda faqat bir marta.','Введите код доступа от руководителя линии. На этом телефоне — один раз.','लाइन प्रबन्धकबाट पाएको पहुँच कोड हाल्नुहोस्। यो फोनमा एक पटक मात्र।','Желі басшысынан алған кіру кодын енгізіңіз. Бұл телефонда бір рет қана.','লাইন ম্যানেজারের দেওয়া অ্যাক্সেস কোড লিখুন। এই ফোনে একবারই।','Saisissez le code d’accès remis par votre chef de ligne. Une seule fois sur ce téléphone.'],
  code_ph:        ['8자리 코드','8-digit code','8位代码','8桁コード','Mã 8 ký tự','8 belgili kod','Код из 8 символов','८ अंकको कोड','8 таңбалы код','৮ অক্ষরের কোড','Code à 8 caractères'],
  register:       ['등록하기','Register','注册','登録','Đăng ký','Ro‘yxatdan o‘tish','Зарегистрировать','दर्ता गर्नुहोस्','Тіркелу','নিবন্ধন করুন','S’inscrire'],
  err_check:      ['코드를 확인해 주세요','Please check the code','请检查代码','コードを確認してください','Vui lòng kiểm tra mã','Kodni tekshiring','Проверьте код','कोड जाँच गर्नुहोस्','Кодты тексеріңіз','কোড পরীক্ষা করুন','Vérifiez le code'],
  err_invalid:    ['존재하지 않는 코드입니다','Invalid code','代码不存在','存在しないコードです','Mã không tồn tại','Bunday kod yo‘q','Код не найден','कोड अवस्थित छैन','Код табылмады','কোডটি বিদ্যমান নেই','Code inexistant'],
  err_used:       ['이미 사용된 코드입니다','Code already used','代码已被使用','使用済みのコードです','Mã đã được sử dụng','Kod allaqachon ishlatilgan','Код уже использован','कोड पहिले नै प्रयोग भइसक्यो','Код бұрын қолданылған','কোডটি ইতিমধ্যে ব্যবহৃত','Code déjà utilisé'],
  err_expired:    ['기한이 지난 코드입니다. 재발급 받으세요','Code expired. Request a new one','代码已过期，请重新申领','期限切れのコードです。再発行を受けてください','Mã đã hết hạn. Hãy xin cấp lại','Kod muddati tugagan. Yangisini oling','Срок кода истёк. Получите новый','कोडको म्याद सकियो। नयाँ लिनुहोस्','Код мерзімі өтті. Жаңасын алыңыз','কোডের মেয়াদ শেষ। নতুন নিন','Code expiré. Demandez-en un nouveau'],
  err_server:     ['서버 오류. 다시 시도해 주세요.','Server error. Please try again.','服务器错误，请重试。','サーバーエラー。もう一度お試しください。','Lỗi máy chủ. Vui lòng thử lại.','Server xatosi. Qayta urinib ko‘ring.','Ошибка сервера. Попробуйте снова.','सर्भर त्रुटि। फेरि प्रयास गर्नुहोस्।','Сервер қатесі. Қайталап көріңіз.','সার্ভার ত্রুটি। আবার চেষ্টা করুন।','Erreur serveur. Veuillez réessayer.'],
  registered:     ['등록 완료','Registered','注册完成','登録完了','Đăng ký thành công','Ro‘yxatdan o‘tdi','Регистрация завершена','दर्ता सम्पन्न','Тіркелді','নিবন্ধন সম্পন্ন','Inscription terminée'],
  lang:           ['언어','Language','语言','言語','Ngôn ngữ','Til','Язык','भाषा','Тіл','ভাষা','Langue'],
  published:      ['게시','Published','发布','公開','Đăng','E’lon','Опубл.','प्रकाशित','Жарияланды','প্রকাশিত','Publié'],
  phone_of:       ['등록된 휴대폰','Registered phone','已注册手机','登録済みのスマホ','Điện thoại đã đăng ký','Ro‘yxatdagi telefon','Зарегистрированный телефон','दर्ता गरिएको फोन','Тіркелген телефон','নিবন্ধিত ফোন','Téléphone enregistré'],
  unknown_eq:     ['등록되지 않은 QR코드','Unregistered QR code','未登记的二维码','未登録のQRコード','Mã QR chưa đăng ký','Ro‘yxatdan o‘tmagan QR kod','Незарегистрированный QR-код','दर्ता नभएको QR कोड','Тіркелмеген QR код','অনিবন্ধিত QR কোড','QR code non enregistré'],
  blocked:        ['접속이 차단되었습니다','Access blocked','访问已被阻止','アクセスがブロックされました','Truy cập bị chặn','Kirish bloklangan','Доступ заблокирован','पहुँच रोकिएको छ','Кіру бұғатталған','অ্যাক্সেস ব্লক করা হয়েছে','Accès bloqué'],
  ask_manager:    ['관리자에게 문의하세요.','Contact your manager.','请联系管理员。','管理者にお問い合わせください。','Hãy liên hệ quản lý.','Rahbaringizga murojaat qiling.','Обратитесь к руководителю.','प्रबन्धकलाई सम्पर्क गर्नुहोस्।','Басшыңызға хабарласыңыз.','ম্যানেজারের সাথে যোগাযোগ করুন।','Contactez votre responsable.'],
  conn_fail:      ['연결 실패','Connection failed','连接失败','接続失敗','Kết nối thất bại','Ulanish xatosi','Ошибка подключения','जडान असफल','Қосылу сәтсіз','সংযোগ ব্যর্থ','Échec de connexion'],
  conn_msg:       ['네트워크를 확인한 뒤 QR코드를 다시 촬영해 주세요.','Check your network and scan the QR code again.','请检查网络后重新扫描二维码。','ネットワークを確認してQRコードを再度読み取ってください。','Kiểm tra mạng và quét lại mã QR.','Tarmoqni tekshirib, QR kodni qayta skanerlang.','Проверьте сеть и отсканируйте QR-код снова.','नेटवर्क जाँच गरी QR कोड फेरि स्क्यान गर्नुहोस्।','Желіні тексеріп, QR кодты қайта сканерлеңіз.','নেটওয়ার্ক পরীক্ষা করে QR কোড আবার স্ক্যান করুন।','Vérifiez le réseau et scannez à nouveau le QR code.'],
  loading:        ['불러오는 중…','Loading…','加载中…','読み込み中…','Đang tải…','Yuklanmoqda…','Загрузка…','लोड हुँदैछ…','Жүктелуде…','লোড হচ্ছে…','Chargement…'],
  not_translated: ['이 언어 번역이 아직 없어 한국어로 표시합니다','Not translated yet — showing Korean','暂无此语言翻译，显示韩语','この言語の翻訳がまだないため韓国語で表示します','Chưa có bản dịch — hiển thị tiếng Hàn','Tarjima hali yo‘q — koreyscha ko‘rsatilmoqda','Перевода пока нет — показан корейский','अनुवाद छैन — कोरियाली देखाइँदै','Аударма әлі жоқ — корейше көрсетілуде','অনুবাদ নেই — কোরিয়ান দেখানো হচ্ছে','Pas encore traduit — affichage en coréen'],
  setup_needed:   ['설정 필요','Setup required','需要设置','設定が必要','Cần cài đặt','Sozlash kerak','Требуется настройка','सेटअप आवश्यक','Баптау қажет','সেটআপ প্রয়োজন','Configuration requise'],
};
const _IDX = Object.fromEntries(window.LANGS.map((l,i) => [l.code, i]));
const _OV = {};   // DB(app_texts)에서 내려온 덮어쓰기: { key: { lang: text } }
window.I18N_DEFAULTS = _T;
window.I18N_KEYS = Object.keys(_T);
window.applyTextOverrides = (rows) => { (rows||[]).forEach(r => { (_OV[r.key] ??= {})[r.lang] = r.text; }); };
window.t = (key, lang) => {
  const ov = _OV[key]?.[lang]; if(ov) return ov;
  const row = _T[key]; if(!row) return key;
  const i = _IDX[lang] ?? 0; return row[i] || _OV[key]?.ko || row[0];
};
