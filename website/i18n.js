/**
 * Sortyd — i18n translation engine
 * Languages: en (default), es (Spanish), ar (Arabic/RTL)
 */

const SORTYD_I18N = {
  en: {
    dir: 'ltr',
    lang: 'en',
    hreflang: 'en',
    nav: {
      features: 'Features',
      blog: 'Blog',
      process: 'Process',
      download: 'Download',
      langLabel: 'EN',
    },
    hero: {
      eyebrow: 'Free on iOS · AI Habit Coach',
      title1: 'Build the life',
      title2: 'you keep',
      titleEm: 'promising yourself.',
      quote: 'Track. Analyse. Get coached on exactly what\'s holding you back.',
      cta: 'App Store',
      ctaMore: 'See how it works →',
    },
    widget: {
      hint: 'Interactive — tap to check off tasks',
      goal: '🏋️ Get Fit',
      sub: 'Tap a task to check it off',
      tasks: [
        'Do 10 push-ups',
        'Stretch 5 minutes',
        'Track calorie intake',
        'Drink 8 glasses water',
        'Walk 30 minutes',
        'Sleep 8 hours',
      ],
      doneToday: 'Done today',
      streak: 'Streak',
      complete: 'Complete',
      more: '+ {n} more — open app to see all',
      msgs: ["Let's go!", 'Great start!', 'Keep going!', 'More than halfway!', 'Almost there!', 'You crushed it! 🎉'],
    },
    ticker: [
      'Track daily habits','AI-powered coaching','Behavioural analytics',
      'Smart reminders','Performance grades','30-day trend reports',
      'Build better streaks','Life pillar breakdown',
    ],
    numbers: [
      { val: '12d', label: 'Average streak across all users' },
      { val: '83%', label: 'Complete 4+ tasks daily after week one' },
      { val: 'Free', label: 'Always. No hidden fees, no premium lock.' },
    ],
    marquee: {
      row1: ['🏋️ GET FIT','🧘 MEDITATE','📚 READ DAILY','💧 DRINK WATER','🗣️ SPEAK SPANISH','😴 SLEEP 8 HRS'],
      row2: ['✍️ JOURNAL','🏃 MORNING RUN','💪 STRENGTH','🎯 DEEP WORK','🌱 GROW DAILY','🍎 EAT CLEAN'],
    },
    features: {
      label: "What's inside",
      title1: 'Four tools. One system.',
      titleEm: 'Real results.',
      tagline: 'features that work together to keep you consistent',
      cards: {
        analytics: { tag: 'Analytics', title: 'See where you\'re winning — and where you\'re not.', stat: 'Hover to simulate a week update', vsLabel: 'vs Last', bestLabel: 'Best Day', worstLabel: 'Weakest' },
        tasks: { tag: 'Daily Checklist', title: 'One tap to log. Smart reminders. Always know your score.', stat: 'Tap tasks above to check them off', pctLabel: 'done today', taskNames: ['Review vocabulary','Practice speaking','Listen native audio','Write journal entry','Language app 30m'] },
        coach: { tag: 'AI Coach', title: 'Reads your data. Finds your patterns. Tells you exactly what to fix.', stat: 'Hover to ask another question',
          bubbles: [
            { type: 'ai', html: '<strong>Language · 62%</strong> — Speaking is high, but writing has dropped off this week.' },
            { type: 'user', text: 'Why do I keep skipping writing?' },
            { type: 'ai', html: 'Likely an <strong>activation energy problem.</strong> Anchor it right after listening.', id: 'fcCoachReply' },
          ],
          conversations: [
            { q: 'Why do I keep skipping writing?', a: 'Likely an <strong>activation energy problem.</strong> Anchor it right after listening.' },
            { q: 'When is my best day?', a: 'Monday — you complete <strong>94% of tasks.</strong> Your energy peaks early week.' },
            { q: 'How do I improve my streak?', a: 'Set a hard cutoff: <strong>log by 9pm.</strong> Missing completion, not doing tasks, breaks streaks.' },
            { q: 'What should I focus on?', a: 'Writing at 31% is your <strong>biggest drag.</strong> One focused week lifts your overall grade.' },
          ],
        },
        pillars: { tag: 'Life Pillars', title: 'Every habit, grouped by life area. See the full picture.', stat: 'Hover to see week-over-week shift' },
      },
    },
    how: {
      title1: 'From zero to',
      titleEm: 'self-aware',
      title2: ' in four steps.',
      sub: 'Set up in minutes. Results compound over weeks.',
      steps: [
        { n: 'Step 01', h: 'Describe your goal', b: 'AI builds a custom checklist around it. Not a template.' },
        { n: 'Step 02', h: 'Set your schedule', b: 'One reminder per task. Fires exactly when you need it.' },
        { n: 'Step 03', h: 'Log daily', b: 'One tap per task. Watch your streak build day by day.' },
        { n: 'Step 04', h: 'Get coached', b: 'AI reads your pillar data and tells you exactly what to fix.' },
      ],
    },
    cta: {
      headline1: 'Start today.',
      headlineEm: "It's free.",
      btn: 'Download on App Store',
      note: 'iOS only · Always free · Available now on the App Store',
    },
    modal: {
      eyebrow: 'Free on iOS',
      headline: 'Your better self',
      headlineEm: 'starts now.',
      body: 'Build your first habit list in 60 seconds.<br>Your streak starts today.',
      storeSm: 'Download on the',
      storeLg: 'App Store',
      note: 'iOS only · Always free · Available now',
    },
    toast: { title: 'Opening App Store…', sub: 'redirecting now' },
    footer: {
      tagline: 'AI Habit Tracker',
      links: [
        { label: 'Privacy', href: '/privacy' },
        { label: 'Terms', href: '#' },
        { label: 'Support', href: '/support' },
        { label: 'Contact', href: 'mailto:info@sortyd.com' },
      ],
      copy: '© 2026 Sortyd',
    },
  },

  es: {
    dir: 'ltr',
    lang: 'es',
    hreflang: 'es',
    nav: {
      features: 'Funciones',
      blog: 'Blog',
      process: 'Proceso',
      download: 'Descargar',
      langLabel: 'ES',
    },
    hero: {
      eyebrow: 'Gratis en iOS · Coach de Hábitos IA',
      title1: 'Construye la vida',
      title2: 'que siempre',
      titleEm: 'te prometiste.',
      quote: 'Registra. Analiza. Recibe coaching exacto sobre lo que te frena.',
      cta: 'App Store',
      ctaMore: 'Cómo funciona →',
    },
    widget: {
      hint: 'Interactivo — toca para marcar tareas',
      goal: '🏋️ Ponerse en Forma',
      sub: 'Toca una tarea para completarla',
      tasks: [
        'Hacer 10 flexiones',
        'Estirar 5 minutos',
        'Registrar calorías',
        'Beber 8 vasos de agua',
        'Caminar 30 minutos',
        'Dormir 8 horas',
      ],
      doneToday: 'Hechas hoy',
      streak: 'Racha',
      complete: 'Completado',
      more: '+ {n} más — abre la app para ver todo',
      msgs: ['¡Vamos!', '¡Buen comienzo!', '¡Sigue así!', '¡Más de la mitad!', '¡Casi lo logras!', '¡Lo lograste! 🎉'],
    },
    ticker: [
      'Registra hábitos diarios','Coaching impulsado por IA','Análisis de comportamiento',
      'Recordatorios inteligentes','Calificaciones de rendimiento','Informes de 30 días',
      'Construye mejores rachas','Desglose por pilares de vida',
    ],
    numbers: [
      { val: '12d', label: 'Racha promedio entre todos los usuarios' },
      { val: '83%', label: 'Completan 4+ tareas diarias tras la primera semana' },
      { val: 'Gratis', label: 'Siempre. Sin cargos ocultos ni funciones bloqueadas.' },
    ],
    marquee: {
      row1: ['🏋️ PONERSE EN FORMA','🧘 MEDITAR','📚 LEER A DIARIO','💧 BEBER AGUA','🗣️ HABLAR INGLÉS','😴 DORMIR 8 HRS'],
      row2: ['✍️ DIARIO PERSONAL','🏃 CORRER DE MAÑANA','💪 FUERZA','🎯 TRABAJO PROFUNDO','🌱 CRECER CADA DÍA','🍎 COMER SANO'],
    },
    features: {
      label: 'Qué incluye',
      title1: 'Cuatro herramientas. Un sistema.',
      titleEm: 'Resultados reales.',
      tagline: 'funciones que trabajan juntas para mantenerte constante',
      cards: {
        analytics: { tag: 'Analíticas', title: 'Descubre en qué estás ganando — y en qué no.', stat: 'Pasa el cursor para simular una semana', vsLabel: 'vs Anterior', bestLabel: 'Mejor día', worstLabel: 'Día débil' },
        tasks: { tag: 'Lista Diaria', title: 'Un toque para registrar. Recordatorios inteligentes. Siempre conoce tu puntuación.', stat: 'Toca las tareas para marcarlas', pctLabel: 'completado hoy', taskNames: ['Repasar vocabulario','Practicar conversación','Escuchar audio nativo','Escribir en el diario','App de idiomas 30 min'] },
        coach: { tag: 'Coach IA', title: 'Lee tus datos. Encuentra tus patrones. Te dice exactamente qué mejorar.', stat: 'Pasa el cursor para otra pregunta',
          bubbles: [
            { type: 'ai', html: '<strong>Idiomas · 62%</strong> — Hablar va bien, pero la escritura bajó esta semana.' },
            { type: 'user', text: '¿Por qué sigo saltándome la escritura?' },
            { type: 'ai', html: 'Probablemente un <strong>problema de energía de activación.</strong> Ancla la escritura justo después de escuchar.', id: 'fcCoachReply' },
          ],
          conversations: [
            { q: '¿Por qué sigo saltándome la escritura?', a: 'Probablemente un <strong>problema de energía de activación.</strong> Ancla la escritura justo después de escuchar.' },
            { q: '¿Cuándo es mi mejor día?', a: 'El lunes — completas <strong>el 94% de tareas.</strong> Tu energía es máxima a principio de semana.' },
            { q: '¿Cómo mejoro mi racha?', a: 'Establece un límite: <strong>registra antes de las 21h.</strong> Lo que rompe la racha es no registrar, no omitir tareas.' },
            { q: '¿En qué debo concentrarme?', a: 'La escritura al 31% es tu <strong>mayor lastre.</strong> Una semana enfocada sube tu nota general.' },
          ],
        },
        pillars: { tag: 'Pilares de Vida', title: 'Cada hábito, agrupado por área vital. Ve el panorama completo.', stat: 'Pasa el cursor para ver el cambio semanal' },
      },
    },
    how: {
      title1: 'De cero a',
      titleEm: 'autoconocimiento',
      title2: ' en cuatro pasos.',
      sub: 'Configúralo en minutos. Los resultados se acumulan semana a semana.',
      steps: [
        { n: 'Paso 01', h: 'Describe tu objetivo', b: 'La IA crea una lista personalizada para ti. No una plantilla.' },
        { n: 'Paso 02', h: 'Define tu horario', b: 'Un recordatorio por tarea. Se activa justo cuando lo necesitas.' },
        { n: 'Paso 03', h: 'Registra a diario', b: 'Un toque por tarea. Observa cómo crece tu racha día a día.' },
        { n: 'Paso 04', h: 'Recibe coaching', b: 'La IA analiza tus pilares y te dice exactamente qué mejorar.' },
      ],
    },
    cta: {
      headline1: 'Empieza hoy.',
      headlineEm: 'Es gratis.',
      btn: 'Descargar en App Store',
      note: 'Solo iOS · Siempre gratis · Disponible en App Store',
    },
    modal: {
      eyebrow: 'Gratis en iOS',
      headline: 'Tu mejor versión',
      headlineEm: 'comienza ahora.',
      body: 'Crea tu primera lista de hábitos en 60 segundos.<br>Tu racha empieza hoy.',
      storeSm: 'Descargar en',
      storeLg: 'App Store',
      note: 'Solo iOS · Siempre gratis · Disponible ahora',
    },
    toast: { title: 'Abriendo App Store…', sub: 'redirigiendo ahora' },
    footer: {
      tagline: 'Rastreador de Hábitos IA',
      links: [
        { label: 'Privacidad', href: '/privacy' },
        { label: 'Términos', href: '#' },
        { label: 'Soporte', href: '/support' },
        { label: 'Contacto', href: 'mailto:info@sortyd.com' },
      ],
      copy: '© 2026 Sortyd',
    },
  },

  ar: {
    dir: 'rtl',
    lang: 'ar',
    hreflang: 'ar',
    nav: {
      features: 'الميزات',
      blog: 'المدونة',
      process: 'كيف يعمل',
      download: 'تحميل',
      langLabel: 'ع',
    },
    hero: {
      eyebrow: 'مجاني على iOS · مدرب العادات بالذكاء الاصطناعي',
      title1: 'ابنِ الحياة',
      title2: 'التي دائمًا',
      titleEm: 'وعدتَ نفسك بها.',
      quote: 'تتبّع. حلّل. احصل على تدريب دقيق حول ما يعيقك تحديدًا.',
      cta: 'App Store',
      ctaMore: 'اكتشف كيف يعمل ←',
    },
    widget: {
      hint: 'تفاعلي — اضغط لإنجاز المهام',
      goal: '🏋️ الوصول للياقة',
      sub: 'اضغط على مهمة لإتمامها',
      tasks: [
        'أداء ١٠ تمارين ضغط',
        'تمدد ٥ دقائق',
        'تتبّع السعرات الحرارية',
        'شرب ٨ أكواب ماء',
        'المشي ٣٠ دقيقة',
        'النوم ٨ ساعات',
      ],
      doneToday: 'مُنجز اليوم',
      streak: 'السلسلة',
      complete: 'مكتمل',
      more: '+ {n} أكثر — افتح التطبيق لرؤية الكل',
      msgs: ['هيا بنا!', 'بداية رائعة!', 'واصل!', 'تجاوزت النصف!', 'تقريبًا وصلت!', 'أنجزتَ كل شيء! 🎉'],
    },
    ticker: [
      'تتبّع العادات اليومية','تدريب بالذكاء الاصطناعي','تحليل السلوك',
      'تذكيرات ذكية','تقييمات الأداء','تقارير ٣٠ يومًا',
      'بناء سلاسل أطول','تصنيف أعمدة الحياة',
    ],
    numbers: [
      { val: '١٢ي', label: 'متوسط السلسلة عبر جميع المستخدمين' },
      { val: '٨٣٪', label: 'يُكملون ٤+ مهام يوميًا بعد الأسبوع الأول' },
      { val: 'مجاني', label: 'دائمًا. بدون رسوم خفية أو ميزات محجوبة.' },
    ],
    marquee: {
      row1: ['🏋️ اللياقة البدنية','🧘 التأمل','📚 القراءة اليومية','💧 شرب الماء','🗣️ تعلم لغة','😴 النوم ٨ ساعات'],
      row2: ['✍️ كتابة يومية','🏃 الجري الصباحي','💪 تدريب القوة','🎯 عمل عميق','🌱 النمو اليومي','🍎 الأكل الصحي'],
    },
    features: {
      label: 'ما بداخل التطبيق',
      title1: 'أربعة أدوات. نظام واحد.',
      titleEm: 'نتائج حقيقية.',
      tagline: 'ميزات تعمل معًا لتبقيك ثابتًا',
      cards: {
        analytics: { tag: 'التحليلات', title: 'اكتشف أين تتفوق — وأين لا.', stat: 'مرّر المؤشر لمحاكاة أسبوع', vsLabel: 'مقابل السابق', bestLabel: 'أفضل يوم', worstLabel: 'أضعف يوم' },
        tasks: { tag: 'القائمة اليومية', title: 'نقرة واحدة للتسجيل. تذكيرات ذكية. اعرف تقييمك دائمًا.', stat: 'اضغط على المهام لإنجازها', pctLabel: 'مُنجز اليوم', taskNames: ['مراجعة المفردات','ممارسة التحدث','الاستماع للصوت الأصلي','كتابة في المذكرة','تطبيق اللغة ٣٠ دقيقة'] },
        coach: { tag: 'المدرب بالذكاء الاصطناعي', title: 'يقرأ بياناتك. يكتشف أنماطك. يخبرك بالضبط ما يجب تحسينه.', stat: 'مرّر المؤشر لسؤال آخر',
          bubbles: [
            { type: 'ai', html: '<strong>اللغات · ٦٢٪</strong> — التحدث ممتاز، لكن الكتابة تراجعت هذا الأسبوع.' },
            { type: 'user', text: 'لماذا أتخطى الكتابة باستمرار؟' },
            { type: 'ai', html: 'على الأرجح <strong>مشكلة في طاقة التفعيل.</strong> اربطها مباشرة بعد الاستماع.', id: 'fcCoachReply' },
          ],
          conversations: [
            { q: 'لماذا أتخطى الكتابة باستمرار؟', a: 'على الأرجح <strong>مشكلة في طاقة التفعيل.</strong> اربطها مباشرة بعد الاستماع.' },
            { q: 'متى يكون أفضل يوم لي؟', a: 'الاثنين — تُكمل <strong>٩٤٪ من المهام.</strong> طاقتك تبلغ ذروتها مطلع الأسبوع.' },
            { q: 'كيف أحسّن سلسلتي؟', a: 'ضع حدًا صارمًا: <strong>سجّل قبل ٩ مساءً.</strong> ما يكسر السلسلة هو عدم التسجيل، لا تخطّي المهام.' },
            { q: 'على ماذا يجب أن أركّز؟', a: 'الكتابة بنسبة ٣١٪ هي <strong>أكبر عائق لديك.</strong> أسبوع واحد مركّز يرفع تقييمك العام.' },
          ],
        },
        pillars: { tag: 'أعمدة الحياة', title: 'كل عادة، مصنّفة حسب مجال الحياة. انظر الصورة الكاملة.', stat: 'مرّر المؤشر لرؤية التغيير الأسبوعي' },
      },
    },
    how: {
      title1: 'من الصفر إلى',
      titleEm: 'الوعي الذاتي',
      title2: ' في أربع خطوات.',
      sub: 'ابدأ خلال دقائق. النتائج تتراكم عبر الأسابيع.',
      steps: [
        { n: 'الخطوة ١', h: 'صِف هدفك', b: 'الذكاء الاصطناعي يبني قائمة مخصصة. ليست قالبًا جاهزًا.' },
        { n: 'الخطوة ٢', h: 'حدد جدولك', b: 'تذكير واحد لكل مهمة. يُطلق في الوقت المناسب تمامًا.' },
        { n: 'الخطوة ٣', h: 'سجّل يوميًا', b: 'نقرة واحدة لكل مهمة. شاهد سلسلتك تنمو يومًا بيوم.' },
        { n: 'الخطوة ٤', h: 'احصل على التدريب', b: 'الذكاء الاصطناعي يحلل أعمدتك ويخبرك بما يجب تحسينه.' },
      ],
    },
    cta: {
      headline1: 'ابدأ اليوم.',
      headlineEm: 'إنه مجاني.',
      btn: 'تحميل من App Store',
      note: 'iOS فقط · مجاني دائمًا · متاح الآن في App Store',
    },
    modal: {
      eyebrow: 'مجاني على iOS',
      headline: 'نسختك الأفضل',
      headlineEm: 'تبدأ الآن.',
      body: 'أنشئ قائمة عاداتك الأولى في ٦٠ ثانية.<br>سلسلتك تبدأ اليوم.',
      storeSm: 'تحميل من',
      storeLg: 'App Store',
      note: 'iOS فقط · مجاني دائمًا · متاح الآن',
    },
    toast: { title: '…جارٍ فتح App Store', sub: 'إعادة التوجيه الآن' },
    footer: {
      tagline: 'تطبيق تتبع العادات بالذكاء الاصطناعي',
      links: [
        { label: 'الخصوصية', href: '/privacy' },
        { label: 'الشروط', href: '#' },
        { label: 'الدعم', href: '/support' },
        { label: 'اتصل بنا', href: 'mailto:info@sortyd.com' },
      ],
      copy: '© ٢٠٢٦ Sortyd',
    },
  },
  zh: {
    dir: 'ltr',
    lang: 'zh',
    hreflang: 'zh-Hans',
    nav: {
      features: '功能',
      blog: '博客',
      process: '使用流程',
      download: '下载',
      langLabel: '中文',
    },
    hero: {
      eyebrow: '免费 · AI习惯教练 · iOS',
      title1: '建立你一直',
      title2: '答应自己',
      titleEm: '要过的生活。',
      quote: '追踪。分析。获得关于阻碍你的精准建议。',
      cta: 'App Store',
      ctaMore: '了解使用方式 →',
    },
    widget: {
      hint: '可交互 — 点击完成任务',
      goal: '🏋️ 健身计划',
      sub: '点击任务以完成它',
      tasks: [
        '做10个俯卧撑',
        '拉伸5分钟',
        '记录卡路里摄入',
        '喝8杯水',
        '步行30分钟',
        '睡8小时',
      ],
      doneToday: '今日完成',
      streak: '连续天数',
      complete: '已完成',
      more: '+ {n} 更多 — 打开App查看全部',
      msgs: ['出发！', '好的开始！', '继续！', '超过一半了！', '快到了！', '全部完成！🎉'],
    },
    ticker: [
      '追踪每日习惯', 'AI驱动的教练', '行为数据分析',
      '智能提醒', '表现评级', '30天趋势报告',
      '建立更长连续记录', '生活支柱分析',
    ],
    numbers: [
      { val: '12天', label: '全体用户的平均连续天数' },
      { val: '83%', label: '第一周后每天完成4+个任务' },
      { val: '免费', label: '永久免费。无隐藏收费，无功能锁定。' },
    ],
    marquee: {
      row1: ['🏋️ 健身', '🧘 冥想', '📚 每日阅读', '💧 喝水', '🗣️ 学语言', '😴 睡8小时'],
      row2: ['✍️ 写日记', '🏃 晨跑', '💪 力量训练', '🎯 专注工作', '🌱 每日成长', '🍎 健康饮食'],
    },
    features: {
      label: '功能特色',
      title1: '四个工具。一套系统。',
      titleEm: '真实成果。',
      tagline: '协同运作的功能，让你保持持续性',
      cards: {
        analytics: { tag: '数据分析', title: '看清你的优势在哪里——以及弱点在哪里。', stat: '悬停以模拟一周更新', vsLabel: '对比上周', bestLabel: '最佳日', worstLabel: '最弱日' },
        tasks: { tag: '每日清单', title: '一键记录。智能提醒。随时了解你的得分。', stat: '点击任务以完成', pctLabel: '今日完成', taskNames: ['复习词汇', '练习口语', '听原声音频', '写日记', '语言App 30分钟'] },
        coach: { tag: 'AI教练', title: '读取你的数据。发现你的规律。告诉你具体要改进什么。', stat: '悬停以问另一个问题',
          bubbles: [
            { type: 'ai', html: '<strong>语言 · 62%</strong> — 口语表现良好，但写作本周有所下降。' },
            { type: 'user', text: '我为什么总是跳过写作？' },
            { type: 'ai', html: '可能是<strong>启动能量问题。</strong>把写作安排在听力练习之后。', id: 'fcCoachReply' },
          ],
          conversations: [
            { q: '我为什么总是跳过写作？', a: '可能是<strong>启动能量问题。</strong>把写作安排在听力练习之后。' },
            { q: '我什么时候状态最好？', a: '周一——你完成了<strong>94%的任务。</strong>你的精力在一周初期最旺盛。' },
            { q: '如何提升我的连续记录？', a: '设定一个硬性截止：<strong>晚9点前记录。</strong>打破连续的是没有记录，而不是没做任务。' },
            { q: '我应该专注在哪里？', a: '写作只有31%，是<strong>你最大的拖累。</strong>专注一周就能提升整体评级。' },
          ],
        },
        pillars: { tag: '生活支柱', title: '每个习惯，按生活领域分类。看到完整全貌。', stat: '悬停以查看周对比变化' },
      },
    },
    how: {
      title1: '从零到',
      titleEm: '自我认知',
      title2: '，四步完成。',
      sub: '几分钟内完成设置。成果在数周内复利积累。',
      steps: [
        { n: '第一步', h: '描述你的目标', b: 'AI为你定制专属清单，不是模板。' },
        { n: '第二步', h: '设定你的时间表', b: '每个任务一个提醒，在你最需要时触发。' },
        { n: '第三步', h: '每日记录', b: '一个任务一次点击，看着你的连续天数每天增长。' },
        { n: '第四步', h: '接受教练指导', b: 'AI分析你的支柱数据，告诉你具体要改进什么。' },
      ],
    },
    cta: {
      headline1: '今天就开始。',
      headlineEm: '完全免费。',
      btn: '在 App Store 下载',
      note: '仅限iOS · 永久免费 · 现已在 App Store 上线',
    },
    modal: {
      eyebrow: '免费 · iOS',
      headline: '更好的自己',
      headlineEm: '从现在开始。',
      body: '60秒内创建你的第一个习惯清单。<br>你的连续记录从今天开始。',
      storeSm: '下载于',
      storeLg: 'App Store',
      note: '仅限iOS · 永久免费 · 现已上线',
    },
    toast: { title: '正在打开 App Store…', sub: '即将跳转' },
    footer: {
      tagline: 'AI 习惯追踪器',
      links: [
        { label: '隐私政策', href: '/privacy' },
        { label: '条款', href: '#' },
        { label: '支持', href: '/support' },
        { label: '联系我们', href: 'mailto:info@sortyd.com' },
      ],
      copy: '© 2026 Sortyd',
    },
  },

};

/**
 * Detect current language from <html lang> attribute or URL path.
 * Falls back to 'en'.
 */
function detectLang() {
  const htmlLang = document.documentElement.lang;
  if (htmlLang && SORTYD_I18N[htmlLang]) return htmlLang;
  const path = window.location.pathname;
  if (path.startsWith('/es/') || path.startsWith('/es')) return 'es';
  if (path.startsWith('/ar/') || path.startsWith('/ar')) return 'ar';
  if (path.startsWith('/zh/') || path.startsWith('/zh')) return 'zh';
  return 'en';
}

/**
 * Switch language: navigate to the equivalent page in the target language.
 */
function switchLang(targetLang) {
  if (targetLang === detectLang()) return;
  localStorage.setItem('sortyd_lang', targetLang);
  const currentPath = window.location.pathname;
  let newPath;
  // Strip existing locale prefix
  const stripped = currentPath.replace(/^\/(es|ar|zh)/, '') || '/';
  if (targetLang === 'en') {
    newPath = stripped;
  } else {
    newPath = '/' + targetLang + stripped;
  }
  window.location.href = newPath;
}

window.SORTYD_I18N = SORTYD_I18N;
window.detectLang = detectLang;
window.switchLang = switchLang;

// Auto-redirect and link rewriting
(function() {
  const currentLang = detectLang();
  const savedLang = localStorage.getItem('sortyd_lang');

  // Auto-redirect to saved language if different from current page
  if (savedLang && savedLang !== currentLang && SORTYD_I18N[savedLang]) {
    switchLang(savedLang);
    return;
  }

  // Save current language if not English and no saved language exists
  if (!savedLang && currentLang !== 'en') {
    localStorage.setItem('sortyd_lang', currentLang);
  }

  document.addEventListener('DOMContentLoaded', () => {
    // Sync language selector dropdown
    const langSelect = document.getElementById('langSelect');
    if (langSelect) {
      langSelect.value = currentLang;
    }

    // Rewrite internal links so they match the current language and avoid redirect flashes
    if (currentLang !== 'en') {
      document.querySelectorAll('a[href]').forEach(a => {
        let href = a.getAttribute('href');
        if (href.startsWith('/') || href.startsWith('https://www.sortyd.com')) {
          try {
            let url = new URL(href, window.location.origin);
            if (url.hostname === window.location.hostname || url.hostname === 'www.sortyd.com') {
              let path = url.pathname;
              if (!path.startsWith('/' + currentLang + '/') && path !== '/' + currentLang) {
                path = path.replace(/^\/(es|ar|zh)\//, '/').replace(/^\/(es|ar|zh)$/, '');
                // Ensure double slashes don't occur
                let newPath = '/' + currentLang + (path.startsWith('/') ? path : '/' + path);
                newPath = newPath.replace(/\/\//g, '/');
                
                url.pathname = newPath;
                // Preserve href format (relative or absolute)
                if (href.startsWith('https://www.sortyd.com')) {
                  a.href = url.toString();
                } else {
                  a.href = url.pathname + url.search + url.hash;
                }
              }
            }
          } catch(e) {
            // Ignore invalid URLs
          }
        }
      });
    }
  });
})();
