import { EmotionRecord } from './Record';
import { newJournal } from './EditorModel';

export interface WritingTemplate { id: string; title: string; questions: string[]; }
export const WRITING_TEMPLATES: WritingTemplate[] = [
  { id: 'today', title: '今天的心情', questions: ['今天最影响我的一件事是什么？', '我现在需要什么？'] },
  { id: 'night', title: '睡前放一放', questions: ['今天还有什么挂在心里？', '哪件事可以留到明天？'] },
  { id: 'letter', title: '给自己的一封信', questions: ['最近哪里辛苦了？', '我想对自己说什么？'] },
  { id: 'joy', title: '今天的一点微光', questions: ['哪个瞬间让我舒服一点？', '我想怎样记住它？'] },
  { id: 'courage', title: '我的小小勇敢', questions: ['今天有没有表达自己的需要？', '即使没做到，我发现了什么？'] }
];
export function templateRecord(id: string): EmotionRecord {
  const template = WRITING_TEMPLATES.find((item: WritingTemplate) => item.id === id);
  if (!template) throw new Error('Unknown template');
  const record = newJournal(template.questions.join('\n\n') + '\n\n');
  record.title = template.title;
  if (id === 'joy') record.kind = 'joy';
  return record;
}
export function newJoy(): EmotionRecord {
  const record = newJournal();
  record.kind = 'joy';
  return record;
}
