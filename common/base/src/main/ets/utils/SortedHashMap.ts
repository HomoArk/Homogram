import { HashMap } from '@kit.ArkTS';

export interface IComparable<T> {
  compareTo(other: T): number;
}

export class SortedHashMap<K, V extends IComparable<V>> {
  private map: HashMap<K, V>;
  private sortedKeys: K[];
  private sortedValues: V[];
  private indexByKey: Map<K, number>;

  constructor() {
    this.map = new HashMap<K, V>();
    this.sortedKeys = [];
    this.sortedValues = [];
    this.indexByKey = new Map<K, number>();
  }

  set(key: K, value: V): { index: number; previousIndex: number } {
    let previousIndex = -1;
    if (this.map.hasKey(key)) {
      previousIndex = this.removeByKey(key);
    }
    this.map.set(key, value);
    const inserted = this.insertSortedValue(key, value);
    return {
      index: inserted.index,
      previousIndex,
    };
  }

  setAll(map: HashMap<K, V>): void {
    this.map.setAll(map);
  }

  get(key: K): V | undefined {
    return this.map.get(key);
  }

  has(key: K): boolean {
    return this.map.hasKey(key);
  }

  delete(key: K): number {
    if (this.map.hasKey(key)) {
      const index = this.removeByKey(key);
      this.map.remove(key);
      return index;
    }
    return -1;
  }

  clear(): void {
    this.map.clear();
    this.sortedKeys = [];
    this.sortedValues = [];
    this.indexByKey.clear();
  }

  getSortedValues(): V[] {
    return this.sortedValues;
  }

  length(): number {
    return this.sortedValues.length;
  }

  indexOf(key: K): number {
    return this.indexByKey.get(key) ?? -1;
  }

  getValueAt(index: number): V | undefined {
    if (index < 0 || index >= this.sortedValues.length) {
      return undefined;
    }
    return this.sortedValues[index];
  }

  hasValueAt(index: number): boolean {
    return index >= 0 && index < this.sortedValues.length;
  }

  // TODO: for those two methods returning IterableIterator, we should pay attention if new values are added during iteration

  valuesIterator(): IterableIterator<V> {
    return this.map.values();
  }

  sortedValuesIterator(): IterableIterator<V> {
    return this.sortedValues.values();
  }

  keysArray(): K[] {
    return [...this.sortedKeys];
  }

  private binarySearchInsertIndex(value: V): number {
    let low = 0;
    let high = this.sortedValues.length - 1;

    while (low <= high) {
      const mid = Math.floor((low + high) / 2);
      if (this.sortedValues[mid].compareTo(value) < 0) {
        high = mid - 1;
      } else {
        low = mid + 1;
      }
    }

    return low;
  }

  private insertSortedValue(key: K, value: V): { index: number; previousIndex: number } {
    const index = this.binarySearchInsertIndex(value);
    this.sortedKeys.splice(index, 0, key);
    this.sortedValues.splice(index, 0, value);
    this.rebuildIndexes(index);
    return { index, previousIndex: -1 };
  }

  private removeByKey(key: K): number {
    const index = this.indexByKey.get(key) ?? -1;
    if (index < 0) {
      return -1;
    }
    this.sortedKeys.splice(index, 1);
    this.sortedValues.splice(index, 1);
    this.indexByKey.delete(key);
    this.rebuildIndexes(index);
    return index;
  }

  private rebuildIndexes(startIndex: number = 0): void {
    for (let i = startIndex; i < this.sortedKeys.length; i++) {
      this.indexByKey.set(this.sortedKeys[i], i);
    }
  }
}
