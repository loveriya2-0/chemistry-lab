// Walkman-Chanakya / KrutiDev (legacy Hindi font) -> Unicode Devanagari.
// Input: text extracted with `pdftotext -enc Latin1`. Read as latin1.
const fs = require('fs');

// Ordered: longer / more specific sequences first.
const MAP = [
  ['oQ', 'क'], ['iQ', 'फ'], ['¶+', 'फ़्'], ['Q+', 'फ़'], ['d+', 'क़'], ['[+k', 'ख़'], ['[+', 'ख़्'],
  ['x+', 'ग़'], ['T+', 'ज़्'], ['t+', 'ज़'], ['M+', 'ड़'], ['<+', 'ढ़'], [';+', 'य़'], ['j+', 'ऱ'], ['u+', 'ऩ'],
  ['Ùk', 'त'], ['Ù', 'त्'], ['ä', 'क्त'], ['–', 'दृ'], ['—', 'कृ'], ['Ñ', 'कृ'], ['é', 'न्न'], ['™', 'न्न्'],
  ['à', 'ह्न'], ['á', 'ह्य'], ['â', 'हृ'], ['ã', 'ह्म'], ['ºz', 'ह्र'], ['º', 'ह्'], ['í', 'द्द'], ['{k', 'क्ष'], ['{', 'क्ष्'],
  ['«', 'त्र्'], ['=k', 'त्र'], ['=', 'त्र'], ['Nî', 'छ्य'], ['Vî', 'ट्य'], ['Bî', 'ठ्य'], ['Mî', 'ड्य'], ['<î', 'ढ्य'],
  ['|', 'द्य'], ['K', 'ज्ञ'], ['}', 'द्व'], ['J', 'श्र'], ['Vª', 'ट्र'], ['Mª', 'ड्र'], ['<ª', 'ढ्र'], ['Nª', 'छ्र'], ['ª', '्र'],
  ['Ø', 'क्र'], ['Ý', 'फ्र'], ['nzZ', 'र्द्र'], ['æ', 'द्र'], ['ç', 'प्र'], ['Á', 'प्र'], ['xz', 'ग्र'], ['#', 'रु'], [':', 'रू'],
  ['¼', 'द्ध'], ['è', 'ध्'], ['Ë', 'ध्'], [']', ','],
  ['vkS', 'औ'], ['vks', 'ओ'], ['vk', 'आ'], ['v', 'अ'], ['bZ', 'ई'], ['Ã', 'ई'], ['b', 'इ'], ['m', 'उ'], ['Å', 'ऊ'],
  [',s', 'ऐ'], [',', 'ए'], ['_', 'ऋ'],
  ['ô', 'क्क'], ['Dk', 'क'], ['d', 'क'], ['D', 'क्'], ['[k', 'ख'], ['[', 'ख्'], ['Xk', 'ग'], ['x', 'ग'], ['X', 'ग्'],
  ['?k', 'घ'], ['Ä', 'घ'], ['?', 'घ्'], ['³', 'ङ'], ['Pk', 'च'], ['p', 'च'], ['P', 'च्'], ['N', 'छ'],
  ['Tk', 'ज'], ['t', 'ज'], ['T', 'ज्'], ['>', 'झ'], ['÷', 'झ्'], ['¥', 'ञ'], ['ê', 'ट्ट'], ['ë', 'ट्ठ'],
  ['V', 'ट'], ['B', 'ठ'], ['ì', 'ड्ड'], ['ï', 'ड्ढ'], ['M', 'ड'], ['<', 'ढ'], ['.k', 'ण'], ['.', 'ण्'],
  ['Rk', 'त'], ['r', 'त'], ['R', 'त्'], ['Fk', 'थ'], ['F', 'थ्'], [')', 'द्ध'], ['n', 'द'], ['/', 'ध'],
  ['Uk', 'न'], ['u', 'न'], ['U', 'न्'], ['Ik', 'प'], ['i', 'प'], ['I', 'प्'], ['Q', 'फ'], ['¶', 'फ्'],
  ['Ck', 'ब'], ['c', 'ब'], ['C', 'ब्'], ['Hk', 'भ'], ['H', 'भ्'], ['Ek', 'म'], ['e', 'म'], ['E', 'म्'],
  [';', 'य'], ['¸', 'य्'], ['j', 'र'], ['Yk', 'ल'], ['y', 'ल'], ['Y', 'ल्'], ['G', 'ळ'],
  ['Ok', 'व'], ['o', 'व'], ['O', 'व्'], ["'k", 'श'], ["'", 'श्'], ['"k', 'ष'], ['"', 'ष्'],
  ['Lk', 'स'], ['l', 'स'], ['L', 'स्'], ['g', 'ह'],
  ['È', 'ीं'], ['z', '्र'], ['Ó', '्य'],
  ['‚', 'ॉ'], ['kW', 'ॉ'], ['ks', 'ो'], ['kS', 'ौ'], ['k', 'ा'], ['h', 'ी'], ['q', 'ु'], ['w', 'ू'], ['`', 'ृ'],
  ['s', 'े'], ['S', 'ै'], ['a', 'ं'], ['¡', 'ँ'], ['W', 'ॅ'], ['~', '्'], ['+', '़'], ['A', '।'], ['%', ':'],
  ['&', '-'], ['μ', 'ऽ'],
];

const VIRAMA = '्';
const isCons = (c) => c >= 'क' && c <= 'ह' || c === 'ळ' || c === 'क़' || c === 'ज़' || c === 'ड़' || c === 'ढ़' || c === 'फ़';
const isMark = (c) => /[ा-्ँ-ः़ॢॣ]/.test(c);

function convert(src) {
  // Pre-expand composite reph forms before mapping.
  let s = src.replace(/d- ,oa f-/g, '').replace(/Ik+Q/g, 'Q+').replace(/o([qwsSa`¡W]*)Q/g, 'd$1').replace(/i([qwsSa`¡W]*)Q/g, 'Q$1').replace(/£(.)/g, 'f$1Z').replace(/±/g, 'Za').replace(/Ê/g, 'hZ');
  // Map tokens (greedy, longest first) but keep 'f' (short i) and 'Z' (reph) as markers.
  let out = '';
  const keys = MAP.slice().sort((a, b) => b[0].length - a[0].length);
  for (let i = 0; i < s.length;) {
    const ch = s[i];
    if (ch === 'f') { out += '\u0001'; i++; continue; }   // short-i marker
    if (ch === 'Z') { out += '\u0002'; i++; continue; }   // reph marker
    let hit = null;
    for (const [k, v] of keys) if (s.startsWith(k, i)) { hit = [k, v]; break; }
    if (hit) { out += hit[1]; i += hit[0].length; } else { out += ch; i++; }
  }
  // Short i: marker precedes the consonant cluster it belongs to -> move after the cluster.
  out = out.replace(/\u0001((?:[क-हळ]़?्)*[क-हळ]़?)/g, '$1ि');
  out = out.replace(/\u0001/g, 'ि');
  // Reph: marker follows the syllable it belongs to -> insert 'र्' before that syllable's cluster.
  for (let guard = 0; out.includes('\u0002') && guard < 1000; guard++) {
    const p = out.indexOf('\u0002');
    let j = p - 1;
    while (j >= 0 && isMark(out[j]) && out[j] !== VIRAMA) j--;        // skip matras/anusvara
    while (j > 0 && out[j - 1] === VIRAMA && isCons(out[j - 2])) j -= 2; // back over conjuncts
    if (j > 0 && out[j - 1] === '़') j--;
    out = out.slice(0, Math.max(j, 0)) + 'र्' + out.slice(Math.max(j, 0), p) + out.slice(p + 1);
  }
  return out
    .replace(//g, 'd- एवं f-')
    .replace(/्ा/g, '')          // half-form + aa -> full consonant
    .replace(/ाे/g, 'ो').replace(/ाै/g, 'ौ')
    .replace(/अो/g, 'ओ').replace(/अौ/g, 'औ').replace(/आॅ/g, 'ऑ')
    .replace(/ंु/g, 'ुं').replace(/ंू/g, 'ूं').replace(/ंे/g, 'ें').replace(/ंै/g, 'ैं')
    .replace(/ेा/g, 'ो');
}

module.exports = { convert };

if (require.main === module) {
  const txt = fs.readFileSync(process.argv[2], 'latin1');
  process.stdout.write(convert(txt));
}
