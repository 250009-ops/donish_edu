export const SITE = {

  name: "Gotcha",

  url: "https://donish.live",

  /** Marketing / Lemon Squeezy business page */

  marketingUrl: "https://donish.live/home",

  description:

    "Gotcha is an English-to-Uzbek learning app. Upload English PDFs, save vocabulary with instant Uzbek translations, and practice with flashcards and quizzes.",

  tagline: "Learn English Through Reading",

  telegramBot: "Donish_edu_bot",

  telegramUrl: "https://t.me/Donish_edu_bot",

  supportEmail: "support@donish.live",

  apiUrl: "https://api.donish.live"

} as const;



export const NAV = [

  { href: "/home#features", label: "Features" },

  { href: "/home#how-it-works", label: "How it works" },

  { href: "/home#pricing", label: "Pricing" },

  { href: "/home#faq", label: "FAQ" },

  { href: "/home#contact", label: "Contact" }

] as const;



export const FAQ_ITEMS = [

  {

    question: "What is Gotcha?",

    answer:

      "Gotcha is an English-to-Uzbek language learning app for Uzbek speakers. Upload English study materials (PDFs), tap words to save them with Uzbek translations, and practice with flashcards and quizzes built from your own reading."

  },

  {

    question: "How do I create an account?",

    answer:

      "Open our Telegram bot, send /start, and follow the prompts to register. You will receive a numeric ID and password to sign in on the Gotcha Android app."

  },

  {

    question: "Which PDFs work?",

    answer:

      "Digital PDFs from Word, Google Docs, or websites work best. Clear scanned pages are supported via server-side OCR. Limits: PDF only, up to about 30 pages and 10 MB per file. Extraction may take 1–2 minutes."

  },

  {

    question: "Is there a mobile app?",

    answer:

      "Yes. Gotcha is available on Android. Sign in with the ID and password from the Telegram bot. An iOS version may follow."

  },

  {

    question: "How does billing work?",

    answer:

      "Start free with core features. Premium subscriptions are billed monthly or yearly through Lemon Squeezy. You can cancel anytime from your Lemon Squeezy customer portal."

  },

  {

    question: "How do I get support?",

    answer:

      "Message us on Telegram or email support@donish.live. We typically respond within 1–2 business days."

  },

  {

    question: "What is your refund policy?",

    answer:

      "Premium subscriptions are billed through Lemon Squeezy. You can cancel renewals anytime from your Lemon Squeezy customer portal. If you were charged in error or cannot use Premium due to a verified technical issue, contact us within 14 days. See our full Refund Policy on this website."

  }

] as const;

