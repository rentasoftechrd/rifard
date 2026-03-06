/**
 * Prueba el endpoint de loterías antes de generar el APK.
 * Uso (desde la raíz del repo):
 *   node apps/backend/scripts/test-lotteries-endpoint.js
 *   API_URL=http://187.124.81.201:3000 TEST_EMAIL=usuario@ejemplo.com TEST_PASSWORD=xxx node apps/backend/scripts/test-lotteries-endpoint.js
 *
 * Si no se pasan TEST_EMAIL/TEST_PASSWORD, solo se prueba health y se muestran instrucciones.
 */
const baseUrl = process.env.API_URL || 'http://localhost:3000';
const email = process.env.TEST_EMAIL;
const password = process.env.TEST_PASSWORD;

const url = (path) => `${baseUrl.replace(/\/$/, '')}/api/v1${path}`;

async function request(method, path, body = null, token = null) {
  const opts = {
    method,
    headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
  };
  if (token) opts.headers.Authorization = `Bearer ${token}`;
  if (body) opts.body = JSON.stringify(body);
  const res = await fetch(url(path), opts);
  const text = await res.text();
  let data;
  try {
    data = text ? JSON.parse(text) : null;
  } catch {
    data = text;
  }
  return { status: res.status, data, ok: res.ok };
}

async function main() {
  console.log('=== Prueba endpoint de loterías ===');
  console.log('Base URL:', baseUrl);
  console.log('GET lotteries:', url('/lotteries'));
  console.log('');

  // 1) Health (sin auth)
  try {
    const health = await request('GET', '/health/pos-connect');
    console.log('1) Health /api/v1/health/pos-connect:', health.status, health.ok ? 'OK' : 'FAIL');
    if (health.data && typeof health.data === 'object') console.log('   ', JSON.stringify(health.data).slice(0, 120) + '...');
  } catch (e) {
    console.log('1) Health: ERROR', e.message);
    console.log('   ¿Está el backend encendido? ¿URL correcta?');
    process.exitCode = 1;
    return;
  }

  if (!email || !password) {
    console.log('');
    console.log('Para probar el endpoint de loterías (requiere login):');
    console.log('  TEST_EMAIL=tu@email.com TEST_PASSWORD=xxx node apps/backend/scripts/test-lotteries-endpoint.js');
    console.log('  O en PowerShell: $env:API_URL="http://187.124.81.201:3000"; $env:TEST_EMAIL="tu@email.com"; $env:TEST_PASSWORD="xxx"; node apps/backend/scripts/test-lotteries-endpoint.js');
    return;
  }

  // 2) Login
  let token;
  try {
    const login = await request('POST', '/auth/login', { email, password });
    console.log('2) POST /api/v1/auth/login:', login.status, login.ok ? 'OK' : 'FAIL');
    if (!login.ok) {
      console.log('   ', login.data?.message || login.data);
      process.exitCode = 1;
      return;
    }
    token = login.data?.accessToken;
    if (!token) {
      console.log('   Respuesta sin accessToken:', JSON.stringify(login.data).slice(0, 200));
      process.exitCode = 1;
      return;
    }
    console.log('   Token recibido (primeros 20 chars):', token.slice(0, 20) + '...');
  } catch (e) {
    console.log('2) Login: ERROR', e.message);
    process.exitCode = 1;
    return;
  }

  // 3) GET Lotteries
  try {
    const lotteries = await request('GET', '/lotteries', null, token);
    console.log('3) GET /api/v1/lotteries:', lotteries.status, lotteries.ok ? 'OK' : 'FAIL');
    if (lotteries.status === 401) {
      console.log('   Token inválido o expirado.');
      process.exit(1);
    }
    if (!lotteries.ok) {
      console.log('   ', lotteries.data?.message || lotteries.data);
      process.exit(1);
    }
    const list = Array.isArray(lotteries.data) ? lotteries.data : (lotteries.data?.data || []);
    console.log('   Loterías devueltas:', list.length);
    if (list.length > 0) {
      console.log('   Primera:', list[0].name || list[0].id || JSON.stringify(list[0]).slice(0, 60));
    }
    console.log('');
    console.log('Endpoint de loterías OK. Puedes generar el APK.');
  } catch (e) {
    console.log('3) GET lotteries: ERROR', e.message);
    process.exitCode = 1;
  }
}

main();
