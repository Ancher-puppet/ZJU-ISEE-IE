// API — 调用 CapAgent 后端识别接口

export async function recognizeCaptcha(imageFile) {
  const formData = new FormData();
  formData.append('file', imageFile);

  const res = await fetch('/api/recognize', {
    method: 'POST',
    body: formData,
  });

  if (!res.ok) {
    const err = await res.json().catch(() => ({ error: '网络错误' }));
    throw new Error(err.error || `请求失败 (${res.status})`);
  }

  return res.json();
}

// ---- 验证码生成 ----

export async function generateTextCaptcha(text) {
  const res = await fetch('/api/generate/text', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ text }),
  });

  if (!res.ok) {
    const err = await res.json().catch(() => ({ error: '生成失败' }));
    throw new Error(err.error || `请求失败 (${res.status})`);
  }

  return res.json();
}

export async function generateClickCaptcha(targets, difficulty = 'normal', useBackground = true) {
  const res = await fetch('/api/generate/click', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ targets, difficulty, use_background: useBackground }),
  });

  if (!res.ok) {
    const err = await res.json().catch(() => ({ error: '生成失败' }));
    throw new Error(err.error || `请求失败 (${res.status})`);
  }

  return res.json();
}

// ---- 工具函数 ----

export function base64ToFile(base64, filename = 'captcha.png') {
  const byteString = atob(base64);
  const ab = new ArrayBuffer(byteString.length);
  const ia = new Uint8Array(ab);
  for (let i = 0; i < byteString.length; i++) {
    ia[i] = byteString.charCodeAt(i);
  }
  return new File([ab], filename, { type: 'image/png' });
}
