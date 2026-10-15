import { EmotionRecord } from './Record';

export const EDITOR_MOODS: string[] = ['开心', '满足', '平静', '期待', '疲惫', '委屈', '烦躁', '紧张', '孤单', '失落', '说不清'];
export const LIFE_TAGS: string[] = ['工作/学习', '亲密关系', '家人', '朋友', '身体状态', '独处', '生活琐事'];

export function newJournal(text: string = '', mood: string = ''): EmotionRecord {
  const now: Date = new Date();
  return {
    id: `journal:${now.getTime()}-${Math.random().toString(36).slice(2, 10)}`,
    kind: 'journal', date: `${now.getFullYear()}-${now.getMonth() + 1}-${now.getDate()}`,
    createdAt: now.getTime(), updatedAt: now.getTime(), timePrecision: 'millisecond',
    moods: mood ? [mood] : [], intensity: null, tags: [], title: '', text,
    photos: [], reflection: null, favorite: false, legacyId: ''
  };
}

export function hasContent(record: EmotionRecord): boolean {
  return record.moods.length > 0 || record.title.trim().length > 0 || record.text.trim().length > 0 || record.photos.length > 0;
}

export function validateEditorRecord(record: EmotionRecord): void {
  if (!hasContent(record)) throw new Error('Empty record');
  if (record.moods.length > 3 || new Set(record.moods).size !== record.moods.length || record.photos.length > 3 ||
    record.title.length > 60 || record.text.length > 5000 || record.tags.length > 12 || record.tags.some((tag: string) => !tag.trim() || tag.length > 20)) {
    throw new Error('Editor limits exceeded');
  }
}
