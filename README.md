# Bena — بينا

**A Comprehensive Educational Ecosystem for Screen Time Reduction and Academic Enhancement**

Bena is a Flutter app that turns studying into a social game. Instead of fighting the phone addiction problem with restrictions and parental controls, Bena redirects that same competitive, social energy — leaderboards, points, challenges, streaks — toward studying. The result: students study more and scroll less, not because they have to, but because it's actually engaging.

> Backed by a controlled 60-day experimental study with 100 students.
> Screen time dropped up to 69.4%. Study hours increased up to 189.7%.

Research poster: [`poster.pdf`](./poster.pdf)
Full research report: [`research_report.pdf`](./research_report.pdf)

---

## The Idea

Procrastination is not a discipline problem — it's a competition problem. Students aren't lazy; they're just competing in the wrong arena (TikTok, Instagram, games). Bena moves the competition to studying.

Every study session earns points. Every procrastination session costs them. Your garden grows when you're productive. Your rank drops when you're not. Your friends can see all of it.

---

## Features

**Gamification & Progress**
- Earn points for study sessions, lose points for excess screen time
- Streak system with bonus rewards for consistency
- Personal virtual garden/city that grows with your productivity
- Achievements and badges for milestones and challenges

**Social Accountability**
- Public leaderboard — individual and group rankings visible to everyone
- Group competition: join or create study groups, compete as a team
- Friends can see your progress (the motivation of not wanting to be last is real)
- Daily announcements of top performers

**Study Tools**
- Pomodoro timer (solo or with friends)
- Screen time tracker — monitors and logs daily usage
- Study hours logger with daily/weekly stats
- Assignment and homework tracker
- Calendar view for scheduled study sessions

**Extra Features**
- Islamic tools: Azkar, Quran, prayer times, Qibla, Tasbeeh
- Group chat and announcements
- Prizes and rewards system
- Challenges — create or join study challenges with friends

---

## Research Results

Tested in a controlled 60-day study with 100 students split into 5 groups by academic performance:

| Group | Profile | Screen Time Reduction | Study Hours Increase |
|---|---|---|---|
| A1, A2 | High-performing | ~59% | ~77–100% |
| B1, B2 | Low-performing | ~65–69% | ~157–190% |
| M | Mixed ability | ~62% | ~113% |

Low-performing students showed the most dramatic improvement — test scores rose by an average of 15.5–16.3 points. The competition and peer visibility were the biggest behavioral drivers.

---

## Tech Stack

| Layer | Tech |
|---|---|
| Framework | Flutter (Dart) |
| Backend | Firebase (Auth, Firestore, Storage) |
| Auth | Firebase Auth + Google Sign-In |
| Charts | fl_chart |
| State | Shared Preferences + Firestore streams |
| UI | Google Fonts, Font Awesome |

---

## Getting Started

```bash
flutter pub get
flutter run
```

Configure Firebase by adding your own `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) from your Firebase project console. Then regenerate `lib/firebase_options.dart` with `flutterfire configure` so the client SDKs point at your own Firebase project.

---

## Security Notes

The Firebase API keys you'll see in `lib/firebase_options.dart` are **client identifiers**, not secrets — Google [documents them as safe to expose](https://firebase.google.com/docs/projects/api-keys) because they only identify the project, not authenticate it. Real security comes from the cloud side:

- **Firestore Security Rules** — make sure rules are not `allow read, write: if true`. Lock reads/writes to the authenticated user's own documents.
- **Firebase Storage rules** — same: gate by `request.auth.uid`.
- **API key restrictions** — in Google Cloud Console → APIs & Services → Credentials, restrict each Firebase API key to your Android package name + SHA-1 fingerprint and your iOS bundle ID. This blocks anyone who copies the key from using it against your project.
- **App Check** — enable in the Firebase Console to verify that requests come from your real app binary.

If you ever add a server-side secret (Cloud Function third-party API key, Stripe secret, etc.), do **not** put it in client code. Use environment variables on the Cloud Function side or a secret manager.

---

Built at GIU (German International University) as part of a research project on gamification, social accountability, and behavioral intervention in education.
