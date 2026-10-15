export interface JournalEntry {
  id: string;
  date: string;
  mood: string;
  text: string;
}
export interface Bottle { id: string; date: string; mood: string; text: string; }
export interface Joy { id: string; date: string; title: string; }
export interface DayItem {
  key: string;
  day: number;
  label: string;
}

