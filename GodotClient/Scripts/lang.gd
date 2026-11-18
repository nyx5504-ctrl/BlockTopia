class_name Lang
## App language. The website's translations (Assets/translations.json, generated from Website/js/lang/*.js) are loaded as Godot translations,
## so any app text that matches a website phrase ("Settings", "Friends", "Log out", ...) is translated automatically.
## Phrases that only exist in the app are in EXTRA below. Anything without a translation stays English.
const CODES := ["en", "ar", "es", "fr", "de", "pt", "ru", "tr", "zh", "ja", "ko", "hi"]
const NAMES := {"en": "English", "ar": "العربية", "es": "Español", "fr": "Français", "de": "Deutsch", "pt": "Português", "ru": "Русский", "tr": "Türkçe", "zh": "简体中文", "ja": "日本語", "ko": "한국어", "hi": "हिन्दी"}
# order of each list: ar, es, fr, de, pt, ru, tr, zh, ja, ko, hi
const EXTRA_LANGS := ["ar", "es", "fr", "de", "pt", "ru", "tr", "zh", "ja", "ko", "hi"]
const EXTRA := {
	"Performance": ["الأداء", "Rendimiento", "Performances", "Leistung", "Desempenho", "Производительность", "Performans", "性能", "パフォーマンス", "성능", "प्रदर्शन"],
	"Shift Lock": ["قفل Shift", "Bloqueo Shift", "Verrouillage Shift", "Shift-Lock", "Shift Lock", "Shift Lock", "Shift Kilidi", "Shift 锁定", "シフトロック", "시프트 락", "शिफ्ट लॉक"],
	"Memory": ["الذاكرة", "Memoria", "Mémoire", "Speicher", "Memória", "Память", "Bellek", "内存", "メモリ", "메모리", "मेमोरी"],
	"Network": ["الشبكة", "Red", "Réseau", "Netzwerk", "Rede", "Сеть", "Ağ", "网络", "ネットワーク", "네트워크", "नेटवर्क"],
	"Average": ["المتوسط", "Promedio", "Moyenne", "Durchschnitt", "Média", "Среднее", "Ortalama", "平均", "平均", "평균", "औसत"],
	"Current": ["الحالي", "Actual", "Actuel", "Aktuell", "Atual", "Сейчас", "Şu an", "当前", "現在", "현재", "वर्तमान"],
	"Settings": ["الإعدادات", "Ajustes", "Paramètres", "Einstellungen", "Configurações", "Настройки", "Ayarlar", "设置", "設定", "설정", "सेटिंग्स"],
	"Players": ["اللاعبون", "Jugadores", "Joueurs", "Spieler", "Jogadores", "Игроки", "Oyuncular", "玩家", "プレイヤー", "플레이어", "खिलाड़ी"],
	"Report": ["إبلاغ", "Denunciar", "Signaler", "Melden", "Denunciar", "Пожаловаться", "Bildir", "举报", "通報", "신고", "रिपोर्ट"],
	"Help": ["مساعدة", "Ayuda", "Aide", "Hilfe", "Ajuda", "Помощь", "Yardım", "帮助", "ヘルプ", "도움말", "सहायता"],
	"Resume": ["متابعة", "Reanudar", "Reprendre", "Fortsetzen", "Continuar", "Продолжить", "Devam et", "继续", "再開", "계속", "जारी रखें"],
	"Fullscreen": ["ملء الشاشة", "Pantalla completa", "Plein écran", "Vollbild", "Tela cheia", "Полный экран", "Tam ekran", "全屏", "フルスクリーン", "전체 화면", "फ़ुलस्क्रीन"],
	"Volume": ["مستوى الصوت", "Volumen", "Volume", "Lautstärke", "Volume", "Громкость", "Ses", "音量", "音量", "볼륨", "वॉल्यूम"],
	"Background": ["الخلفية", "Fondo", "Arrière-plan", "Hintergrund", "Fundo", "Фон", "Arka plan", "背景", "背景", "배경", "पृष्ठभूमि"],
	"Black": ["أسود", "Negro", "Noir", "Schwarz", "Preto", "Чёрный", "Siyah", "黑色", "ブラック", "블랙", "काला"],
	"White": ["أبيض", "Blanco", "Blanc", "Weiß", "Branco", "Белый", "Beyaz", "白色", "ホワイト", "화이트", "सफ़ेद"],
	"App language": ["لغة التطبيق", "Idioma de la app", "Langue de l'app", "App-Sprache", "Idioma do app", "Язык приложения", "Uygulama dili", "应用语言", "アプリの言語", "앱 언어", "ऐप की भाषा"],
}
static var _data: Dictionary = {}
static var _loaded := false

static func _load() -> void:
	if _loaded: return
	_loaded = true
	var f := FileAccess.open("res://Assets/translations.json", FileAccess.READ)
	if f != null:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary: _data = parsed
	for msg in EXTRA:
		for i in EXTRA_LANGS.size():
			var code: String = EXTRA_LANGS[i]
			if not _data.has(code): _data[code] = {}
			_data[code][msg] = EXTRA[msg][i]

static func apply(code: String) -> void:
	if not CODES.has(code): code = "en"
	_load()
	for loc in TranslationServer.get_loaded_locales():
		var t := TranslationServer.get_translation_object(loc)
		if t != null and t.has_meta("bt_lang"): TranslationServer.remove_translation(t)
	if code != "en" and _data.has(code):
		var tr_obj := Translation.new(); tr_obj.locale = code; tr_obj.set_meta("bt_lang", true)
		for msg in _data[code]: tr_obj.add_message(msg, _data[code][msg])
		TranslationServer.add_translation(tr_obj)
	TranslationServer.set_locale(code)
