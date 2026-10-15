import { EmotionRecord } from './Record';
import { localDateKey, normalizedRecordDate } from './RecordDate';

export interface ReviewCount {
  label: string;
  days: number;
}

export interface ReviewDay {
  key: string;
  label: string;
  count: number;
  moods: string[];
  tags: string[];
  joyCount: number;
}

export interface MoodReview {
  period: number;
  start: string;
  end: string;
  totalRecords: number;
  recordedDays: number;
  moodDays: number;
  joyCount: number;
  moods: ReviewCount[];
  tags: ReviewCount[];
  weeks: ReviewDay[][];
}

function countLabels(days: ReviewDay[], moods: boolean): ReviewCount[] {
  const counts: Map<string, number> = new Map();
  days.forEach((day: ReviewDay) => {
    (moods ? day.moods : day.tags).forEach((label: string) => { counts.set(label, (counts.get(label) || 0) + 1); });
  });
  const result: ReviewCount[] = [];
  counts.forEach((count: number, label: string) => { result.push({ label, days: count }); });
  return result.sort((a: ReviewCount, b: ReviewCount) => b.days - a.days || (a.label < b.label ? -1 : a.label > b.label ? 1 : 0));
}

function mergeLabels(target: string[], source: string[]): void {
  source.forEach((value: string) => {
    const label: string = value.trim();
    if (label && !target.includes(label)) target.push(label);
  });
}

export function buildMoodReview(records: EmotionRecord[], period: number, now: Date = new Date()): MoodReview {
  if ((period !== 7 && period !== 30) || !Number.isFinite(now.getTime())) throw new Error('Invalid review range');
  const days: ReviewDay[] = [];
  const byDate: Map<string, ReviewDay> = new Map();
  for (let offset: number = period - 1; offset >= 0; offset--) {
    const date: Date = new Date(now.getFullYear(), now.getMonth(), now.getDate() - offset);
    const day: ReviewDay = { key: localDateKey(date), label: `${date.getMonth() + 1}/${date.getDate()}`,
      count: 0, moods: [], tags: [], joyCount: 0 };
    days.push(day); byDate.set(day.key, day);
  }
  records.forEach((record: EmotionRecord) => {
    const day: ReviewDay | undefined = byDate.get(normalizedRecordDate(record.date));
    if (!day) return;
    day.count++;
    if (record.kind === 'joy') day.joyCount++;
    mergeLabels(day.moods, record.moods);
    mergeLabels(day.tags, record.tags);
  });
  const weeks: ReviewDay[][] = [];
  for (let start: number = 0; start < days.length; start += 7) weeks.push(days.slice(start, start + 7));
  return { period, start: days[0].key, end: days[days.length - 1].key,
    totalRecords: days.reduce((count: number, day: ReviewDay) => count + day.count, 0),
    recordedDays: days.filter((day: ReviewDay) => day.count > 0).length,
    moodDays: days.filter((day: ReviewDay) => day.moods.length > 0).length,
    joyCount: days.reduce((count: number, day: ReviewDay) => count + day.joyCount, 0),
    moods: countLabels(days, true), tags: countLabels(days, false), weeks };
}
