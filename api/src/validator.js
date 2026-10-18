// Port of the app's ContentValidator rules (lib/content/content_validator.dart)
// that can be checked on a single item. Cross references are checked with `refs`.
const DEVANAGARI = /[ऀ-ॿ]/;
const PLACEHOLDER = /\b(TODO|TBD|FIXME|lorem ipsum)\b|\?\?\?/i;
const PURE_SYMBOLS = /^[\s\d\p{P}\p{S}A-Za-z₀-₉⁰-⁹→⇌↑↓()+\-=.,/·°%]*$/u;

function* walkBilingual(value, path = '') {
  if (!value || typeof value !== 'object') return;
  if (Array.isArray(value)) {
    for (let i = 0; i < value.length; i++) yield* walkBilingual(value[i], `${path}[${i}]`);
    return;
  }
  if ('en' in value && ('hi' in value || typeof value.en === 'string') && typeof value.en === 'string') {
    yield [path, value];
    return;
  }
  for (const [k, v] of Object.entries(value)) yield* walkBilingual(v, path ? `${path}.${k}` : k);
}

export function validateItem(type, data) {
  const issues = [];
  const add = (level, path, message) => issues.push({ level, path, message });

  if (!data || typeof data !== 'object') return [{ level: 'error', path: '', message: 'Item must be an object' }];
  if (!data.id || typeof data.id !== 'string') add('error', 'id', 'id is required');

  for (const [path, t] of walkBilingual(data)) {
    if (PLACEHOLDER.test(t.en) || (t.hi && PLACEHOLDER.test(t.hi))) add('error', path, 'Placeholder text found');
    if (t.hi !== undefined && t.hi.trim() !== '') {
      // Hindi must contain Devanagari unless it is purely a formula/symbol string.
      if (!DEVANAGARI.test(t.hi) && !PURE_SYMBOLS.test(t.hi)) add('error', `${path}.hi`, 'Hindi text must be in Devanagari');
    } else if (t.en && /[A-Za-z]{4,}/.test(t.en)) {
      add('warning', `${path}.hi`, 'Hindi translation missing');
    }
  }

  if (type === 'question' || type === 'pyq') {
    const opts = data.options;
    if (data.type === 'mcq') {
      if (!Array.isArray(opts) || opts.length < 2) add('error', 'options', 'MCQ needs at least 2 options');
      else if (!Number.isInteger(data.correctOption) || data.correctOption < 0 || data.correctOption >= opts.length) {
        add('error', 'correctOption', 'correctOption must index into options');
      }
    }
    if (!(data.marks > 0)) add('error', 'marks', 'marks must be a positive number');
    if (type === 'question' && data.type === 'mcq' && data.marks !== 1) add('warning', 'marks', 'MCQ is normally 1 mark');
    if (!data.chapterId) add('warning', 'chapterId', 'chapterId missing');
  }
  if (type === 'note' && !data.targetId) add('error', 'targetId', 'targetId is required');
  if (type === 'reaction') {
    if (!Array.isArray(data.steps) || !data.steps.length) add('error', 'steps', 'At least one step is required');
    if (!data.equation) add('warning', 'equation', 'equation missing');
  }
  if (type === 'guide' && (!Array.isArray(data.steps) || !data.steps.length)) add('error', 'steps', 'At least one step is required');
  if (!data.review?.status) add('warning', 'review.status', 'review.status missing');
  return issues;
}

export const asArray = (v) => (v == null ? [] : Array.isArray(v) ? v : [v]);

export function titleOf(data) {
  const pick = (v) => (typeof v === 'string' ? v : v?.en);
  return (
    pick(data.title) || pick(data.name) || pick(data.question) || pick(data.summary) ||
    pick(data.aim) || pick(data.definition) || pick(data.officialName) || data.id
  );
}

export function metaOf(type, data, extra = {}) {
  return {
    title: String(titleOf(data) || data.id).slice(0, 300),
    boardId: data.boardId || extra.boardId,
    classLevel: data.classLevel ?? extra.classLevel,
    chapterId: data.chapterId || (type === 'note' ? String(data.targetId || '').split('-t')[0] : undefined),
    topicId: data.topicId || (type === 'note' ? data.targetId : undefined),
    review: data.review?.status || 'draft',
  };
}
