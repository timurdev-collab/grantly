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
