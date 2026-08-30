//
//  filesystemImpl.cpp
//  Player
//
//  Created by ゾロアーク on 11/21/20.
//

#include <SDL_filesystem.h>

#include "filesystemImpl.h"
#include "util/exception.h"
#include "util/debugwriter.h"

#ifdef MKXPZ_EXP_FS
#include <experimental/filesystem>
namespace fs = std::experimental::filesystem;
#else
#include "ghc/filesystem.hpp"
namespace fs = ghc::filesystem;
#endif

#include <fstream>

// https://stackoverflow.com/questions/12774207/fastest-way-to-check-if-a-file-exist-using-standard-c-c11-c
bool filesystemImpl::fileExists(const char *path) {
    fs::path stdPath(path);
    /* error_code overloads: the throwing ones raise filesystem_error for
     * any stat failure that is not file-not-found, and several callers
     * run outside any try block (uncaught -> abort, seen on Vita). */
    std::error_code ec;
    return (fs::exists(stdPath, ec) && !fs::is_directory(stdPath, ec));
}


// https://stackoverflow.com/questions/2912520/read-file-contents-into-a-string-in-c
std::string filesystemImpl::contentsOfFileAsString(const char *path) {
    std::string ret;
    try {
        std::ifstream ifs(path);
        ret = std::string ( (std::istreambuf_iterator<char>(ifs) ),
                       (std::istreambuf_iterator<char>()    ) );
    } catch (...) {
        throw Exception(Exception::NoFileError, "Failed to read file at %s", path);
    }

    return ret;
}

// chdir and getcwd do not support unicode on Windows
bool filesystemImpl::setCurrentDirectory(const char *path) {
    fs::path stdPath(path);
    fs::current_path(stdPath);
    bool ret;

    try {
        ret = fs::equivalent(fs::current_path(), stdPath);
    } catch (...) {
        Debug() << "Failed to check current path." << path;
        ret = false;
    }
    return ret;
}

std::string filesystemImpl::getCurrentDirectory() {
    std::string ret;
    try {
        ret = std::string(fs::current_path().string());
    } catch (...) {
        throw Exception(Exception::MKXPError, "Failed to retrieve current path");
    }
    return ret;
}


std::string filesystemImpl::normalizePath(const char *path, bool preferred, bool absolute) {
    fs::path stdPath(path);
    
    if (!stdPath.is_absolute() && absolute) {
        std::error_code ec;
        fs::path cwd = fs::current_path(ec);
        if (!ec)
            stdPath = cwd / stdPath;
    }

    stdPath = stdPath.lexically_normal();
    std::string ret(stdPath);
    for (size_t i = 0; i < ret.length(); i++) {
        char sep;
        char sep_alt;
#ifdef __WIN32__
        if (preferred) {
            sep = '\\';
            sep_alt = '/';
        }
        else
#endif
        {
            sep = '/';
            sep_alt = '\\';
        }
        
        if (ret[i] == sep_alt)
            ret[i] = sep;
    }
    return ret;
}

#ifdef __vita__
#include "vita/vita-paths.h"
#endif

std::string filesystemImpl::getDefaultGameRoot() {
#ifdef __vita__
    /* Resolve the game to run from the memory card layout
     * (boot.json, then the first game in the library). */
    return vitaResolveGameFolder();
#else
    char *p = SDL_GetBasePath();
    std::string ret(p);
    SDL_free(p);
    return ret;
#endif
}
