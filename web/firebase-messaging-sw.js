// Firebase Cloud Messaging default service worker.
// Required on web so firebase_messaging can register a push worker;
// without it the dev/prod server returns index.html (MIME text/html error).
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyAGMa3r-43RBFrJ4vGPiRo5it_-0_VPx0A',
  appId: '1:248265494952:web:74de429d20d67792400d9d',
  messagingSenderId: '248265494952',
  projectId: 'fandomverse-cfe67',
  authDomain: 'fandomverse-cfe67.firebaseapp.com',
  storageBucket: 'fandomverse-cfe67.firebasestorage.app',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const title = (payload && payload.notification && payload.notification.title) ||
    'FandomVerse';
  const body = (payload && payload.notification && payload.notification.body) || '';
  self.registration.showNotification(title, {
    body,
    icon: '/icons/icon-192.png',
  });
});
