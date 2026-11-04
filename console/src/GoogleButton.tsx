import { useEffect, useRef, useState } from 'react';

declare global {
  interface Window { google?: any }
}

const SRC = 'https://accounts.google.com/gsi/client';
let loading: Promise<void> | null = null;

function loadGoogle(): Promise<void> {
  if (window.google?.accounts?.id) return Promise.resolve();
  loading ??= new Promise<void>((resolve, reject) => {
    const s = document.createElement('script');
    s.src = SRC; s.async = true;
    s.onload = () => resolve();
    s.onerror = () => { loading = null; reject(new Error('Could not load Google sign-in')); };
    document.head.appendChild(s);
  });
  return loading;
}

// Google's own "Continue with Google" button. It returns an ID token which the
// API verifies; the console never sees the user's Google password.
export default function GoogleButton({ clientId, onCredential }: { clientId: string; onCredential: (credential: string) => void }) {
  const box = useRef<HTMLDivElement>(null);
  const cb = useRef(onCredential);
  cb.current = onCredential;
  const [failed, setFailed] = useState(false);

  useEffect(() => {
    let cancelled = false;
    loadGoogle().then(() => {
      if (cancelled || !box.current) return;
      window.google.accounts.id.initialize({
        client_id: clientId,
        callback: (r: { credential: string }) => cb.current(r.credential),
        // Always offer the account chooser instead of silently reusing the last one.
        auto_select: false,
      });
      window.google.accounts.id.renderButton(box.current, {
        type: 'standard',
        theme: document.documentElement.classList.contains('dark') ? 'filled_black' : 'outline',
        size: 'large',
        text: 'continue_with',
        shape: 'rectangular',
        logo_alignment: 'left',
        width: Math.min(320, box.current.clientWidth || 320),
      });
    }).catch(() => setFailed(true));
    return () => { cancelled = true; };
  }, [clientId]);

  if (failed) return <p className="text-center text-sm text-slate-500">Google sign-in could not be loaded. Use email and password instead.</p>;
  return <div ref={box} className="flex min-h-10 justify-center" />;
}
