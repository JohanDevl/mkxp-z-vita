/*
** vita-paths.cpp
**
** This file is part of mkxp. Vita on-device layout helpers.
**
** mkxp is free software: you can redistribute it and/or modify
** it under the terms of the GNU General Public License as published by
** the Free Software Foundation, either version 2 of the License, or
** (at your option) any later version.
*/

#ifdef __vita__

#include "vita-paths.h"

#include <dirent.h>
#include <sys/stat.h>

#include <fstream>

#include "util/json5pp.hpp"

static bool isDir(const std::string &path) {
    struct stat st{};
    return stat(path.c_str(), &st) == 0 && S_ISDIR(st.st_mode);
}

static bool isFile(const std::string &path) {
    struct stat st{};
    return stat(path.c_str(), &st) == 0 && S_ISREG(st.st_mode);
}

void vitaEnsureDataLayout() {
    const char *dirs[] = {
        MKXPZ_VITA_DATA_ROOT,
        MKXPZ_VITA_DATA_ROOT "/games",
        MKXPZ_VITA_DATA_ROOT "/saves",
        MKXPZ_VITA_DATA_ROOT "/config",
        MKXPZ_VITA_DATA_ROOT "/logs",
    };
    for (const char *d : dirs)
        mkdir(d, 0777);
}

bool vitaIsGameFolder(const std::string &dir) {
    if (!isFile(dir + "/Game.ini"))
        return false;

    /* Legacy (pre-v19): a single serialized script bundle.
     * Modern (v20+): loose .rb files under Data/Scripts/.
     * Keying on Scripts.rxdata alone would miss exactly the modern
     * games this port targets. */
    return isFile(dir + "/Data/Scripts.rxdata") ||
           isDir(dir + "/Data/Scripts");
}

static std::string bootJsonGame() {
    std::ifstream f(MKXPZ_VITA_DATA_ROOT "/config/boot.json");
    if (!f)
        return "";

    try {
        json5pp::value v = json5pp::parse5(f);
        if (!v.is_object())
            return "";
        auto &obj = v.as_object();
        auto it = obj.find("game");
        if (it == obj.end() || !it->second.is_string())
            return "";

        std::string game = it->second.as_string();
        if (game.empty())
            return "";

        /* Bare names refer to folders under games/. */
        if (game.find(':') == std::string::npos)
            game = std::string(MKXPZ_VITA_DATA_ROOT "/games/") + game;

        if (vitaIsGameFolder(game))
            return game;
    } catch (...) {
        /* Malformed boot.json: fall through to the scan. */
    }
    return "";
}

static std::string firstGameInLibrary() {
    const std::string root = MKXPZ_VITA_DATA_ROOT "/games";
    DIR *dp = opendir(root.c_str());
    if (!dp)
        return "";

    std::string found;
    while (struct dirent *ent = readdir(dp)) {
        if (ent->d_name[0] == '.')
            continue;
        std::string candidate = root + "/" + ent->d_name;
        if (vitaIsGameFolder(candidate)) {
            found = candidate;
            break;
        }
    }
    closedir(dp);
    return found;
}

std::string vitaResolveGameFolder() {
    vitaEnsureDataLayout();

    std::string game = bootJsonGame();
    if (game.empty())
        game = firstGameInLibrary();
    if (game.empty())
        game = "app0:/";

    return game;
}

#endif /* __vita__ */
