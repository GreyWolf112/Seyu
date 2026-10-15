import { EmotionRecord } from './Record';
import { newJournal } from './EditorModel';

export interface ReflectionScene {
  id: string;
  title: string;
  description: string;
  factQuestion: string;
  needQuestion: string;
  actionQuestion: string;
  needs: string[];
  actions: string[];
}

export const REFLECTION_SCENES: ReflectionScene[] = [
  { id: 'words', title: '有句话让我很在意', description: '把听到的话和自己的理解，慢慢分开。',
    factQuestion: '对方说了什么？哪些是原话，哪些是你自己的理解？',
    needQuestion: '这件事里，你希望怎样被对待？', actionQuestion: '接下来，你愿意怎样照顾自己？',
    needs: ['被尊重', '被认真听见', '一点独处时间', '暂时说不清'], actions: ['先休息，不急着回应', '写下我想澄清的事情', '找信任的人聊聊'] },
  { id: 'boundary', title: '我又勉强自己答应了', description: '给自己的时间和需要，留一点位置。',
    factQuestion: '你答应了什么？当时有哪些顾虑？', needQuestion: '你希望保护自己的哪一部分？',
    actionQuestion: '下次或这一次，你想怎样表达？', needs: ['休息时间', '考虑后再决定', '公平分担', '保留拒绝的选择'],
    actions: ['我先看看安排，再回复你。', '这次我能做的部分是……', '我需要调整刚才的安排。'] },
  { id: 'relationship', title: '和亲近的人有点难受', description: '先听见自己的感受，再决定要不要沟通。',
    factQuestion: '发生了哪件具体的事？可以只写你愿意说的部分。', needQuestion: '你期待得到什么？',
    actionQuestion: '什么选择让你此刻更舒服、更有安全感？', needs: ['被理解', '被尊重的边界', '安静和距离', '实际的支持'],
    actions: ['先暂停这次交流', '整理好后再决定是否沟通', '向信任的人寻求支持'] },
  { id: 'overloaded', title: '今天真的有点撑不住', description: '看看负担在哪里，允许一件事先放下。',
    factQuestion: '最近哪些事情叠在了一起？', needQuestion: '此刻最缺少的支持是什么？',
    actionQuestion: '有没有一件事，可以暂缓或请人分担？', needs: ['睡眠和休息', '有人分担', '降低一点要求', '一段自己的时间'],
    actions: ['把一件非紧急的事留到明天', '向一个可信的人提出具体请求', '先照顾吃饭、喝水和休息'] },
  { id: 'selfkindness', title: '我对自己有点苛刻', description: '对自己，也试着使用更公平的语言。',
    factQuestion: '你正在怎样评价自己？有哪些具体事实？', needQuestion: '如果不急着给自己打分，你需要什么？',
    actionQuestion: '你愿意用怎样一句更公平的话回应自己？', needs: ['停止比较一会儿', '允许不完美', '承认自己的努力', '一点实际帮助'],
    actions: ['这次的结果不能代表我的全部。', '我可以承认困难，也看见已经做的努力。', '我暂时不需要给自己下结论。'] }
];

export function reflectionScene(id: string): ReflectionScene {
  const scene = REFLECTION_SCENES.find((item: ReflectionScene) => item.id === id);
  if (!scene) throw new Error('Unknown reflection scene');
  return scene;
}

export function newReflection(id: string): EmotionRecord {
  const scene = reflectionScene(id);
  const record = newJournal();
  record.kind = 'reflection';
  record.title = scene.title;
  record.reflection = { sceneId: id, facts: '', needs: '', nextStep: '', step: 0 };
  return record;
}

export function updateReflection(seed: EmotionRecord, facts: string, moods: string[], needs: string, nextStep: string, step: number): EmotionRecord {
  if (!seed.reflection || !Number.isInteger(step) || step < 0 || step > 4 || moods.length > 3 ||
    facts.length > 1500 || needs.length > 1500 || nextStep.length > 1500) throw new Error('Invalid reflection input');
  const scene = reflectionScene(seed.reflection.sceneId);
  return {
    id: seed.id, kind: 'reflection', title: scene.title, date: seed.date, createdAt: seed.createdAt,
    updatedAt: Date.now(), timePrecision: seed.timePrecision, moods: moods.slice(), intensity: seed.intensity,
    tags: seed.tags.slice(), photos: seed.photos.slice(), favorite: seed.favorite, bottled: seed.bottled ?? false, legacyId: seed.legacyId,
    reflection: { sceneId: scene.id, facts, needs, nextStep, step },
    text: `发生的事：${facts || '暂未填写'}\n我的感受：${moods.join('、') || '暂未填写'}\n我的需要：${needs || '暂未填写'}\n下一步：${nextStep || '暂未决定'}`
  };
}

export function reflectionHasContent(record: EmotionRecord): boolean {
  return !!record.reflection && (record.moods.length > 0 || record.reflection.facts.trim().length > 0 ||
    record.reflection.needs.trim().length > 0 || record.reflection.nextStep.trim().length > 0);
}
