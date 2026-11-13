// Firebase web config is public by design; security comes from Backend/firestore.rules.
// Paste the missing values from Firebase Console > Project settings > Your apps > Web app.
import { initializeApp } from "https://www.gstatic.com/firebasejs/10.14.1/firebase-app.js";
import { getAuth } from "https://www.gstatic.com/firebasejs/10.14.1/firebase-auth.js";
import { getFirestore } from "https://www.gstatic.com/firebasejs/10.14.1/firebase-firestore.js";

const firebaseConfig = {
  apiKey: "AIzaSyCdEvulpM-5MGOTqQhcIrCaeylSMzXtoaA",
  authDomain: "blocktopia-f3341.firebaseapp.com",
  projectId: "blocktopia-f3341",
  storageBucket: "blocktopia-f3341.firebasestorage.app",
  messagingSenderId: "565610704786",
  appId: "1:565610704786:web:d800a0d873018a6b915b4b",
  measurementId: "G-EX7VCWW5KV"
};
export const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);
export const db = getFirestore(app);
