package com.grantly.android

/**
 * Localized Home labels. This is deliberately a Home-only preview, not a claim
 * that authentication, scholarship details, or the rest of the app is translated.
 * Keep language codes aligned with the iOS AppLanguage options.
 */
internal enum class HomeLanguage(val code: String, val title: String, val flag: String) {
    ENGLISH("en", "English", "🇬🇧"),
    RUSSIAN("ru", "Русский", "🇷🇺"),
    VIETNAMESE("vi", "Tiếng Việt", "🇻🇳"),
    ARABIC("ar", "العربية", "🇸🇦"),
    CHINESE("zh-Hans", "中文", "🇨🇳"),
    FRENCH("fr", "Français", "🇫🇷"),
    SPANISH("es", "Español", "🇪🇸"),
    GERMAN("de", "Deutsch", "🇩🇪");

    companion object {
        fun fromCode(code: String?): HomeLanguage =
            entries.firstOrNull { it.code == code } ?: ENGLISH
    }

    val labels: HomeLabels
        get() = when (this) {
            ENGLISH -> HomeLabels("Good morning", "Good afternoon", "Good evening",
                "Scholarships picked\nfor your next chapter.", "Search scholarships, countries, majors",
                "For you", "Applications", "Advisors", "Profile", "Picked for you", "Closing soon")
            RUSSIAN -> HomeLabels("Доброе утро", "Добрый день", "Добрый вечер",
                "Стипендии для\nвашего следующего шага.", "Поиск стипендий, стран и специальностей",
                "Для вас", "Заявки", "Консультанты", "Профиль", "Подобрано для вас", "Скоро закрываются")
            VIETNAMESE -> HomeLabels("Chào buổi sáng", "Chào buổi chiều", "Chào buổi tối",
                "Học bổng cho\nchặng đường tiếp theo.", "Tìm học bổng, quốc gia, ngành học",
                "Dành cho bạn", "Hồ sơ", "Cố vấn", "Cá nhân", "Gợi ý cho bạn", "Sắp hết hạn")
            ARABIC -> HomeLabels("صباح الخير", "مساء الخير", "مساء الخير",
                "منح دراسية\nلخطوتك القادمة.", "ابحث عن المنح والدول والتخصصات",
                "لك", "الطلبات", "المستشارون", "الملف الشخصي", "مختارة لك", "تنتهي قريبا")
            CHINESE -> HomeLabels("早上好", "下午好", "晚上好",
                "为你的下一段旅程\n精选奖学金。", "搜索奖学金、国家和专业",
                "为你推荐", "申请", "顾问", "个人资料", "为你精选", "即将截止")
            FRENCH -> HomeLabels("Bonjour", "Bon après-midi", "Bonsoir",
                "Des bourses pour\nvotre prochaine étape.", "Rechercher des bourses, pays, filières",
                "Pour vous", "Candidatures", "Conseillers", "Profil", "Pour vous", "Bientôt closes")
            SPANISH -> HomeLabels("Buenos días", "Buenas tardes", "Buenas noches",
                "Becas para\ntu próximo capítulo.", "Buscar becas, países y carreras",
                "Para ti", "Solicitudes", "Asesores", "Perfil", "Elegidas para ti", "Próximos cierres")
            GERMAN -> HomeLabels("Guten Morgen", "Guten Tag", "Guten Abend",
                "Stipendien für\ndeinen nächsten Schritt.", "Stipendien, Länder und Fächer suchen",
                "Für dich", "Bewerbungen", "Beratung", "Profil", "Für dich ausgewählt", "Baldiger Bewerbungsschluss")
        }

    /** Home-only guidance and Community cards; other screens remain untranslated. */
    val secondaryLabels: HomeSecondaryLabels
        get() = when (this) {
            ENGLISH -> HomeSecondaryLabels(
                "Need a little guidance?", "Browse verified educational advisors (sign-in required).",
                "Browse advisors →", "Community",
                "Explore Community posts, Stories and Shorts. Publishing requires a visible profile; video features are still in testing.",
                "Explore community →")
            RUSSIAN -> HomeSecondaryLabels(
                "Нужна помощь?", "Найдите проверенных консультантов по образованию (нужен вход в аккаунт).",
                "Найти консультантов →", "Сообщество",
                "Читайте публикации, истории и короткие видео. Для публикации нужен открытый профиль; видеофункции еще тестируются.",
                "Открыть сообщество →")
            VIETNAMESE -> HomeSecondaryLabels(
                "Bạn cần tư vấn?", "Tìm cố vấn giáo dục đã được xác minh (cần đăng nhập).",
                "Xem cố vấn →", "Cộng đồng",
                "Khám phá bài viết, tin và video ngắn. Cần hồ sơ công khai để đăng bài; tính năng video vẫn đang thử nghiệm.",
                "Khám phá cộng đồng →")
            ARABIC -> HomeSecondaryLabels(
                "هل تحتاج إلى إرشاد؟", "تصفح المستشارين التعليميين المعتمدين (يتطلب تسجيل الدخول).",
                "تصفح المستشارين ←", "المجتمع",
                "استكشف المنشورات والقصص والمقاطع القصيرة. يتطلب النشر ملفا شخصيا ظاهرا؛ ميزات الفيديو قيد الاختبار.",
                "استكشف المجتمع ←")
            CHINESE -> HomeSecondaryLabels(
                "需要一些指导吗？", "浏览已认证的教育顾问（需要登录）。",
                "浏览顾问 →", "社区",
                "浏览社区帖子、动态和短视频。发布内容需要公开个人资料；视频功能仍在测试中。",
                "探索社区 →")
            FRENCH -> HomeSecondaryLabels(
                "Besoin de conseils ?", "Consultez des conseillers en éducation vérifiés (connexion requise).",
                "Voir les conseillers →", "Communauté",
                "Découvrez les publications, stories et vidéos courtes. Un profil visible est requis pour publier ; la vidéo est encore en test.",
                "Explorer la communauté →")
            SPANISH -> HomeSecondaryLabels(
                "¿Necesitas orientación?", "Consulta asesores educativos verificados (requiere iniciar sesión).",
                "Ver asesores →", "Comunidad",
                "Explora publicaciones, historias y videos cortos. Para publicar necesitas un perfil visible; el video sigue en pruebas.",
                "Explorar la comunidad →")
            GERMAN -> HomeSecondaryLabels(
                "Brauchst du Unterstützung?", "Entdecke geprüfte Bildungsberater (Anmeldung erforderlich).",
                "Berater ansehen →", "Community",
                "Entdecke Beiträge, Stories und Kurzvideos. Zum Veröffentlichen brauchst du ein sichtbares Profil; Videos werden noch getestet.",
                "Community entdecken →")
        }
}

internal data class HomeLabels(
    val goodMorning: String,
    val goodAfternoon: String,
    val goodEvening: String,
    val hero: String,
    val search: String,
    val forYou: String,
    val applications: String,
    val advisors: String,
    val profile: String,
    val pickedForYou: String,
    val closingSoon: String
)


internal data class HomeSecondaryLabels(
    val guidanceTitle: String,
    val guidanceDescription: String,
    val guidanceAction: String,
    val communityTitle: String,
    val communityDescription: String,
    val communityAction: String
)
