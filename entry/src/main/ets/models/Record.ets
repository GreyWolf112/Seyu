export type RecordKind = 'mood' | 'journal' | 'bottle' | 'joy' | 'reflection';

export interface PhotoReference {
  id: string;
  relativePath: string; // App-owned relative path; never a temporary picker URI.
}

export interface ReflectionResult {
  sceneId: string;
  step?: number; // 0—3 guided steps; 4 is the editable summary.
  facts: string;
  needs: string;
  nextStep: string;
}

export interface EmotionRecord {
  id: string;
  kind: RecordKind;
  date: string;
  createdAt: number;
  updatedAt: number;
  timePrecision: 'day' | 'millisecond';
  moods: string[];
  intensity: number | null;
  tags: string[];
  title: string;
  text: string;
  photos: PhotoReference[];
  reflection: ReflectionResult | null;
  favorite: boolean;
  bottled?: boolean; // Ritual marker on the original record, never a second copy.
  legacyId: string;
}

export interface RecordDocument {
  schemaVersion: number;
  records: EmotionRecord[];
}
