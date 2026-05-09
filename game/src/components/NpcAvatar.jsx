import React from 'react';
import { getNpcImage } from '../engine/imageRegistry.js';

/**
 * NPC avatar that renders a circular illustration if a PNG exists for this
 * npc id, otherwise falls back to the legacy single-letter colored disc.
 *
 * Usage: <NpcAvatar npc={npc} gender={state.gender} size={48} />
 */
export function NpcAvatar({ npc, gender, size = 40, className = '' }) {
  if (!npc) return null;
  const url = getNpcImage(npc.id, gender);
  const dim = { width: size, height: size };

  if (url) {
    return (
      <img
        src={url}
        alt={npc.cn || npc.name || ''}
        className={`rounded-full object-cover flex-shrink-0 ${className}`}
        style={{ ...dim, border: `1.5px solid ${npc.color || '#888'}` }}
      />
    );
  }

  // Letter fallback (legacy look)
  return (
    <div
      className={`rounded-full flex items-center justify-center flex-shrink-0 font-medium ${className}`}
      style={{
        ...dim,
        background: npc.color,
        color: '#1a1612',
        fontSize: Math.round(size * 0.42),
      }}
    >
      {npc.avatar}
    </div>
  );
}
