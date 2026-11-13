# Stage 1 setup
1. Firebase Console > Authentication > Sign-in method: enable **Email/Password**.
2. Build > Firestore Database: create it, then paste `Backend/firestore.rules` into Rules and Publish.
3. Project settings > Your apps > add a Web app; copy `apiKey`, `messagingSenderId`, `appId` into `Website/js/firebase-config.js`.
4. Authentication > Settings > Authorized domains: add `<your-user>.github.io`.
5. Run locally: `cd Website && python -m http.server 8000` (ES modules need http, not file://).
6. GitHub Pages: push the repo, Settings > Pages > Source: **GitHub Actions**. The included workflow deploys `/Website`.
