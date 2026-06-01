// Firebase Messaging Service Worker
// This file MUST be named firebase-messaging-sw.js and placed in /web/

importScripts("https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyA2FSZ2TzCDdA1F1yjC53EaXgZxY-Ze5uo",
  authDomain: "egx-10666.firebaseapp.com",
  projectId: "egx-10666",
  storageBucket: "egx-10666.firebasestorage.app",
  messagingSenderId: "950929147311",
  appId: "1:950929147311:web:4da686399c527c62ecdb5a",
  measurementId: "G-5MBCJ61BP3"
});

const messaging = firebase.messaging();

// Handle background messages (app closed or in background tab)
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message:', payload);

  const notificationTitle = payload.notification?.title || 'إشعار جديد';
  const notificationOptions = {
    body: payload.notification?.body || '',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    dir: 'rtl', // Right-to-left for Arabic
    lang: 'ar',
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
