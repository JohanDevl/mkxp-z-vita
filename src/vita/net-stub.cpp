/*
** net-stub.cpp — Vita replacement for src/net/net.cpp
**
** cpp-httplib needs ifaddrs.h and a BSD socket surface newlib does not
** provide, and HTTPS is compiled out on this platform anyway (PRD
** 10.3). The HTTPLite Ruby module stays present; every request raises
** a catchable error instead.
**
** This file is part of mkxp. mkxp is free software: you can
** redistribute it and/or modify it under the terms of the GNU General
** Public License as published by the Free Software Foundation, either
** version 2 of the License, or (at your option) any later version.
*/

#ifdef __vita__

#include "net/net.h"

#include "util/exception.h"

namespace mkxp_net {

HTTPResponse::HTTPResponse() : _status(0) {}
HTTPResponse::~HTTPResponse() {}

int HTTPResponse::status() { return _status; }
std::string &HTTPResponse::body() { return _body; }
StringMap &HTTPResponse::headers() { return _headers; }

HTTPRequest::HTTPRequest(const char *dest, bool follow_redirects)
    : destination(dest), follow_location(follow_redirects) {}

HTTPRequest::~HTTPRequest() {}

StringMap &HTTPRequest::headers() { return _headers; }

static HTTPResponse unsupported() {
    throw Exception(Exception::MKXPError,
                    "HTTP requests are not supported on the Vita");
}

HTTPResponse HTTPRequest::get() { return unsupported(); }

HTTPResponse HTTPRequest::post(StringMap &) { return unsupported(); }

HTTPResponse HTTPRequest::post(const char *, const char *) {
    return unsupported();
}

} // namespace mkxp_net

#endif /* __vita__ */
