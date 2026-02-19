'use strict';

const fs = require('fs');
const path = require('path');

function loadLabelContract(contractPath) {
  if (!contractPath || String(contractPath).trim() === '') {
    throw new Error('contractPath is required.');
  }

  const resolvedPath = path.resolve(contractPath);
  if (!fs.existsSync(resolvedPath)) {
    throw new Error(`Label contract not found: ${resolvedPath}`);
  }

  let payload;
  try {
    payload = JSON.parse(fs.readFileSync(resolvedPath, 'utf8'));
  } catch (error) {
    throw new Error(`Failed to parse label contract JSON '${resolvedPath}': ${error.message}`);
  }

  if (!payload || typeof payload !== 'object') {
    throw new Error(`Invalid label contract payload: ${resolvedPath}`);
  }

  payload.labels = Array.isArray(payload.labels) ? payload.labels : [];
  payload.aliases = Array.isArray(payload.aliases) ? payload.aliases : [];
  return payload;
}

function buildReleaseLabelMap(contract) {
  return buildNormalizedLabelMap(contract, 'release_increment', 'bump_type');
}

function buildIssueTypeLabelMap(contract) {
  return buildNormalizedLabelMap(contract, 'issue_type', 'issue_type');
}

function buildNormalizedLabelMap(contract, category, normalizedField) {
  const map = Object.create(null);
  const labels = Array.isArray(contract?.labels) ? contract.labels : [];
  const aliases = Array.isArray(contract?.aliases) ? contract.aliases : [];

  for (const entry of labels) {
    if (!entry || String(entry.category || '') !== category) {
      continue;
    }

    const normalizedValue = normalizeValue(entry[normalizedField]);
    if (!normalizedValue) {
      continue;
    }

    addMapEntry(map, entry.name, normalizedValue);
    const entryAliases = Array.isArray(entry.aliases) ? entry.aliases : [];
    for (const alias of entryAliases) {
      addMapEntry(map, alias, normalizedValue);
    }
  }

  for (const entry of aliases) {
    if (!entry || String(entry.category || '') !== category) {
      continue;
    }

    const normalizedValue = normalizeValue(entry[normalizedField]);
    if (!normalizedValue) {
      continue;
    }

    addMapEntry(map, entry.name, normalizedValue);
  }

  return map;
}

function normalizeLabels(labels, labelMap) {
  const normalized = [];
  const matchedRaw = [];
  const seenNormalized = new Set();
  const seenRaw = new Set();

  const inputLabels = Array.isArray(labels) ? labels : [];
  for (const raw of inputLabels) {
    const key = normalizeLabelKey(raw);
    if (!key || !Object.prototype.hasOwnProperty.call(labelMap, key)) {
      continue;
    }

    const normalizedValue = labelMap[key];
    if (!seenRaw.has(key)) {
      matchedRaw.push(String(raw));
      seenRaw.add(key);
    }
    if (!seenNormalized.has(normalizedValue)) {
      normalized.push(normalizedValue);
      seenNormalized.add(normalizedValue);
    }
  }

  return {
    normalized,
    matchedRaw
  };
}

function getExemptStaleLabels(contract) {
  const labels = Array.isArray(contract?.labels) ? contract.labels : [];
  const names = [];
  const seen = new Set();

  for (const entry of labels) {
    if (!entry || entry.stale_exempt !== true) {
      continue;
    }

    const name = String(entry.name || '').trim();
    if (!name) {
      continue;
    }

    const key = name.toLowerCase();
    if (!seen.has(key)) {
      names.push(name);
      seen.add(key);
    }
  }

  return names;
}

function addMapEntry(map, label, normalizedValue) {
  const key = normalizeLabelKey(label);
  if (!key || !normalizedValue) {
    return;
  }

  map[key] = normalizedValue;
}

function normalizeLabelKey(value) {
  return String(value || '').trim().toLowerCase();
}

function normalizeValue(value) {
  const normalized = String(value || '').trim().toLowerCase();
  return normalized === '' ? '' : normalized;
}

module.exports = {
  loadLabelContract,
  buildReleaseLabelMap,
  buildIssueTypeLabelMap,
  normalizeLabels,
  getExemptStaleLabels
};
