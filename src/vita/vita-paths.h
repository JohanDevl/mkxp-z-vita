/*
** vita-paths.h
**
** This file is part of mkxp. Vita on-device layout helpers.
**
** mkxp is free software: you can redistribute it and/or modify
** it under the terms of the GNU General Public License as published by
** the Free Software Foundation, either version 2 of the License, or
** (at your option) any later version.
*/

#ifndef MKXPZ_VITA_PATHS_H
#define MKXPZ_VITA_PATHS_H

#ifdef __vita__

#include <string>

/* Root of all RPG-Player data on the memory card. */
#define MKXPZ_VITA_DATA_ROOT "ux0:data/RPGPlayer"

/* Ensures the on-device directory layout exists
 * (games/, saves/, config/, logs/). */
void vitaEnsureDataLayout();

/* True if `dir` looks like an RPG Maker XP / Essentials game folder:
 * a Game.ini next to either Data/Scripts.rxdata (legacy) or a
 * Data/Scripts/ directory (Essentials v20+ ships loose .rb scripts). */
bool vitaIsGameFolder(const std::string &dir);

/* Resolves the game folder to run:
 *   1. config/boot.json {"game": "<name or absolute path>"} if valid,
 *   2. else the first valid game under games/,
 *   3. else app0:/ (allows embedding a game in the VPK for testing).
 * Never returns an empty string. */
std::string vitaResolveGameFolder();

#endif /* __vita__ */

#endif /* MKXPZ_VITA_PATHS_H */
