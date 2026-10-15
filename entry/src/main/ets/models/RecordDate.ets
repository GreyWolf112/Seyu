// Record dates are local calendar dates, not UTC instants.
export function localDateKey(date: Date): string {
  return `${date.getFullYear()}-${date.getMonth() + 1}-${date.getDate()}`;
}

export function normalizedRecordDate(value: string): string {
  if (!/^\d{4}-\d{1,2}-\d{1,2}$/.test(value)) return '';
  const parts: number[] = value.split('-').map((part: string) => Number(part));
  const date: Date = new Date(parts[0], parts[1] - 1, parts[2]);
  if (date.getFullYear() !== parts[0] || date.getMonth() !== parts[1] - 1 || date.getDate() !== parts[2]) return '';
  return localDateKey(date);
}
