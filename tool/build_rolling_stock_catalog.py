#!/usr/bin/env python3
"""Build the compact label-to-rolling-stock catalog bundled by the app."""

from __future__ import annotations

import argparse
import csv
import json
from collections import Counter, defaultdict
from pathlib import Path


DEFAULT_DATASET_ROOT = Path('/Users/sakiko/Documents/wakareeru')
DEFAULT_OUTPUT = Path('assets/rolling_stock_catalog.json')


def parse_json_list(value: str) -> list[str]:
    if not value:
        return []
    try:
        decoded = json.loads(value)
    except json.JSONDecodeError:
        return [value]
    if isinstance(decoded, list):
        return [str(item) for item in decoded if str(item)]
    return [str(decoded)] if decoded else []


def join_operator(values: list[str], separator: str) -> str | None:
    seen: list[str] = []
    for value in values:
        if value and value not in seen:
            seen.append(value)
    return separator.join(seen) if seen else None


def load_power_by_series(metadata_path: Path) -> dict[str, str]:
    power_counts: dict[str, Counter[str]] = defaultdict(Counter)
    with metadata_path.open(encoding='utf-8', newline='') as file:
        for row in csv.DictReader(file):
            power = (row.get('power_type') or '').strip()
            if not power:
                continue
            keys = {
                (row.get('label') or '').strip(),
                (row.get('series') or '').strip(),
                (row.get('fine_grained_series') or '').strip(),
            }
            for key in keys:
                if key:
                    power_counts[key][power] += 1
    return {key: counts.most_common(1)[0][0] for key, counts in power_counts.items()}


def build_catalog(dataset_root: Path) -> dict[str, dict[str, str]]:
    series_path = dataset_root / 'data/jr_east_freight_series.csv'
    metadata_path = dataset_root / 'data/dataset/metadata.csv'
    power_by_series = load_power_by_series(metadata_path)

    catalog: dict[str, dict[str, str]] = {}
    with series_path.open(encoding='utf-8', newline='') as file:
        for row in csv.DictReader(file):
            label = (row.get('series') or '').strip()
            if not label:
                continue
            operator_jp = join_operator(parse_json_list(row.get('operator_jp') or ''), '・')
            operator_en = join_operator(parse_json_list(row.get('operator_en') or ''), ' / ')
            entry = {
                'full': (row.get('full_name') or '').strip(),
                'op_en': operator_en,
                'op_jp': operator_jp,
                'power': power_by_series.get(label),
                'type': (row.get('type') or '').strip(),
                'wiki': (row.get('wiki_title') or '').strip(),
            }
            catalog[label] = {key: value for key, value in entry.items() if value}
    return catalog


def print_coverage(catalog: dict[str, dict[str, str]]) -> None:
    labels = len(catalog)
    print(f'labels {labels}')
    for field in ('wiki', 'type', 'power', 'op_jp', 'op_en', 'full'):
        count = sum(1 for entry in catalog.values() if entry.get(field))
        pct = (count / labels * 100) if labels else 0
        print(f'{field} {count}/{labels} {pct:.1f}%')


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument('--dataset-root', type=Path, default=DEFAULT_DATASET_ROOT)
    parser.add_argument('--output', type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()

    catalog = build_catalog(args.dataset_root)
    encoded = json.dumps(catalog, ensure_ascii=False, separators=(',', ':')) + '\n'
    print_coverage(catalog)

    if args.check:
        current = args.output.read_text(encoding='utf-8') if args.output.exists() else ''
        if current != encoded:
            raise SystemExit(f'{args.output} is not up to date')
        return

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(encoded, encoding='utf-8')


if __name__ == '__main__':
    main()
