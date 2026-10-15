import { normalizedRecordDate } from './RecordDate';
import { EmotionRecord } from './Record';

export function filterRecords(records: EmotionRecord[], filter: string, date: string, search: string): EmotionRecord[] {
  const query: string = search.trim();
  return records.filter((record: EmotionRecord) => {
    const matchesType: boolean = filter === '全部' || (filter === '收藏' && record.favorite) ||
      (filter === '整理卡' && record.kind === 'reflection') || (filter === '微光' && record.kind === 'joy') ||
      (filter === '瓶子' && (record.bottled === true || record.kind === 'bottle'));
    return matchesType && (!date || (normalizedRecordDate(date) !== '' && normalizedRecordDate(record.date) === normalizedRecordDate(date))) && (!query || record.text.includes(query) ||
      record.title.includes(query) || record.moods.join(' ').includes(query) || record.tags.join(' ').includes(query));
  });
}
