export const config = {
  port: Number(process.env.PORT || 4000),
  mongoUri: process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/lab_console',
  jwtSecret: process.env.JWT_SECRET || 'dev-only-secret',
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || '8h',
  corsOrigins: (process.env.CORS_ORIGINS || 'http://localhost:5173').split(',').map((s) => s.trim()),
  internalSecret: process.env.INTERNAL_SECRET || '',
  contentDir: process.env.CONTENT_DIR || '../assets/content',
};

export const CONTENT_TYPES = [
  'board', 'manifest', 'syllabus', 'note', 'question', 'pyq', 'concept',
  'chemical', 'reaction', 'reagent', 'guide',
];

export const REVIEW_STATUSES = ['draft', 'needsReview', 'sourceChecked', 'verified'];
export const ROLES = ['admin', 'editor', 'reviewer'];
