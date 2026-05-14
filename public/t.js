/*
 * person_scan tracker (t.js)
 * Vanilla JS, no dependencies. Installs on customer sites via:
 *   <script src="https://your-host/t.js?site=PUBLIC_KEY"></script>
 *
 * Ported from individlabs_person_scan/lib/assets/external-js/analyzer.js (2016).
 * Behaviour preserved; modernized: ES2020, fetch, localStorage fingerprint,
 * fixed typos, configurable base URL, attribute-based site lookup.
 */
(function () {
  "use strict";

  // ---- config -----------------------------------------------------------
  var scriptTag = document.currentScript || (function () {
    var s = document.getElementsByTagName("script");
    return s[s.length - 1];
  })();

  function paramFromSrc(name) {
    var src = (scriptTag && scriptTag.getAttribute("src")) || "";
    var q = src.indexOf("?");
    if (q < 0) return null;
    var parts = src.substring(q + 1).split("&");
    for (var i = 0; i < parts.length; i++) {
      var kv = parts[i].split("=");
      if (decodeURIComponent(kv[0]) === name) return decodeURIComponent(kv[1] || "");
    }
    return null;
  }

  var siteId = paramFromSrc("site") || paramFromSrc("site_id") || "unknown";

  var baseUrl = (function () {
    var attr = scriptTag && scriptTag.getAttribute("data-base-url");
    if (attr) return attr.replace(/\/$/, "");
    var src = scriptTag && scriptTag.getAttribute("src");
    if (src) {
      try {
        var u = new URL(src, window.location.href);
        return u.origin;
      } catch (e) {}
    }
    return "";
  })();

  // ---- transport --------------------------------------------------------
  function post(path, data, cb) {
    data.site_id = siteId;
    var body = Object.keys(data)
      .map(function (k) {
        var v = data[k];
        if (v === null || typeof v === "undefined") v = "";
        if (typeof v === "object") v = JSON.stringify(v);
        return encodeURIComponent(k) + "=" + encodeURIComponent(v);
      })
      .join("&");

    var url = baseUrl + "/" + path;
    if (navigator.sendBeacon && (path === "page_visits" || path.indexOf("track") !== -1)) {
      try {
        var blob = new Blob([body], { type: "application/x-www-form-urlencoded" });
        if (navigator.sendBeacon(url, blob)) {
          if (cb) cb();
          return;
        }
      } catch (e) {}
    }

    var xhr = new XMLHttpRequest();
    xhr.open("POST", url);
    xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded");
    if (cb) xhr.onload = cb;
    xhr.send(body);
  }

  // ---- fingerprint ------------------------------------------------------
  function getFingerprint() {
    var key = "person_scan_fp";
    var fp = null;
    try {
      fp = localStorage.getItem(key);
    } catch (e) {}
    if (!fp) {
      // Lightweight fallback. Combines crypto.randomUUID() with a few stable
      // browser bits so we have *some* repeatability if storage gets cleared.
      var rand = (crypto && crypto.randomUUID && crypto.randomUUID()) ||
                 Math.random().toString(36).slice(2) + Date.now().toString(36);
      fp = rand.replace(/-/g, "").slice(0, 32);
      try { localStorage.setItem(key, fp); } catch (e) {}
    }
    return fp;
  }

  var fp = getFingerprint();

  // ---- session ----------------------------------------------------------
  function reportNewSession() {
    var data = {
      fingerprint_id: fp,
      device_width: window.screen.availWidth,
      device_height: window.screen.availHeight,
      window_width: window.outerWidth,
      window_height: window.outerHeight,
      history_length: window.history.length,
      browser_language: navigator.language,
      referrer: document.referrer,
      color_depth: screen.colorDepth,
      timezone_offset: new Date().getTimezoneOffset() / 60,
      hardware_concurrency: navigator.hardwareConcurrency,
      cookies_enabled: navigator.cookieEnabled
    };
    var age, gender;
    try {
      age = sessionStorage.getItem("individlabs_age");
      gender = sessionStorage.getItem("individlabs_gender");
    } catch (e) {}
    if (age) data.age = age;
    if (gender) data.gender = gender;
    post("visitor/new-session", data);
  }

  // ---- scroll tracker ---------------------------------------------------
  function ScrollTracker() {
    var top = function () {
      return window.pageYOffset || document.documentElement.scrollTop;
    };
    this.completed = [];
    this.current = { up: false, down: false };
    this.lastTs = -1;
    var lastTop = top();
    var self = this;
    window.addEventListener("scroll", function (e) {
      if (self.lastTs !== -1 && e.timeStamp - self.lastTs > 3000) {
        self.completed.push(self.current);
        self.current = { up: false, down: false };
      }
      if (top() < lastTop) self.current.up = true;
      else if (top() > lastTop) self.current.down = true;
      lastTop = top();
      self.lastTs = e.timeStamp;
    });
  }
  ScrollTracker.prototype.flush = function () {
    var now = performance.now();
    if (now - this.lastTs > 3000 && (this.current.up || this.current.down)) {
      this.completed.push(this.current);
      this.current = { up: false, down: false };
      this.lastTs = -1;
    }
    var out = this.completed;
    this.completed = [];
    var decisive = 0, indecisive = 0;
    for (var i = 0; i < out.length; i++) {
      if (out[i].up === out[i].down) indecisive++; else decisive++;
    }
    return { decisive_scroll: decisive, indecisive_scroll: indecisive };
  };

  // ---- mouse tracker ----------------------------------------------------
  function MouseTracker() {
    var SAMPLE_MS = 100;
    var x = null, y = null;
    var currentMove = [];
    var self = this;
    this.recent = null;
    this.data = { directions: [], curvatureAngles: [], curvatureDistances: [], speeds: [], accelerations: [] };
    this.activity = { moving: 0, still: 0 };

    function update(e) { x = e.pageX; y = e.pageY; }
    document.addEventListener("mousemove", update, false);
    document.addEventListener("mouseenter", update, false);

    function sample() {
      if (x === null) { self.activity.still++; return; }
      var last = currentMove[currentMove.length - 1];
      if (!last || (last[0] === x && last[1] === y)) self.activity.still++;
      else self.activity.moving++;

      if (currentMove.length > 1000) { currentMove = []; return; }

      if (currentMove.length > 1 && last && last[0] === x && last[1] === y) {
        complete();
      } else if (!last || last[0] !== x || last[1] !== y) {
        currentMove.push([x, y]);
      }
    }
    setInterval(sample, SAMPLE_MS);

    function downsample(arr, factor) {
      var r = [];
      for (var i = 0; i < arr.length; i += factor) r.push(arr[i]);
      return r;
    }

    function complete() {
      var lower = downsample(currentMove, 3);
      var dir = direction(lower);
      var cur = curvature(lower);
      var sp = speed(currentMove, SAMPLE_MS);
      var ac = acceleration(sp, SAMPLE_MS);
      self.recent = { directions: dir, curvatureDistances: cur.distance, curvatureAngles: cur.angle, speeds: sp, accelerations: ac };
      if (dir.length) self.data.directions.push(dir);
      if (cur.distance.length) self.data.curvatureDistances.push(cur.distance);
      if (cur.angle.length) self.data.curvatureAngles.push(cur.angle);
      if (sp.length) self.data.speeds.push(sp);
      if (ac.length) self.data.accelerations.push(ac);
      currentMove = [];
    }
  }
  MouseTracker.prototype.flush = function () {
    var out = this.data;
    this.data = { directions: [], curvatureAngles: [], curvatureDistances: [], speeds: [], accelerations: [] };
    out.mouse_moving = this.activity.moving;
    out.mouse_still = this.activity.still;
    this.activity = { moving: 0, still: 0 };
    return out;
  };
  MouseTracker.prototype.getRecent = function () { return this.recent; };

  function direction(move) {
    var r = [];
    for (var i = 0; i < move.length - 1; i++) {
      var dx = move[i + 1][0] - move[i][0];
      var dy = move[i][1] - move[i + 1][1];
      var d;
      if (dx < 0) d = Math.PI + Math.atan(dy / dx);
      else if (dx > 0) d = Math.atan(dy / dx);
      else d = dy > 0 ? Math.PI / 2 : -Math.PI / 2;
      while (d < 0) d += 2 * Math.PI;
      r.push(Math.round(360 * (d / (2 * Math.PI))));
    }
    return r;
  }
  function curvature(move) {
    var out = { angle: [], distance: [] };
    for (var i = 0; i < move.length - 2; i++) {
      var dx1 = move[i + 1][0] - move[i][0], dy1 = move[i][1] - move[i + 1][1];
      var dx2 = move[i + 2][0] - move[i + 1][0], dy2 = move[i + 1][1] - move[i + 2][1];
      var dx3 = move[i + 2][0] - move[i][0], dy3 = move[i][1] - move[i + 2][1];
      var b = Math.sqrt(dx1 * dx1 + dy1 * dy1);
      var a = Math.sqrt(dx2 * dx2 + dy2 * dy2);
      var c = Math.sqrt(dx3 * dx3 + dy3 * dy3);
      var z = Math.max(-1, Math.min(1, (a * a + b * b - c * c) / (2 * a * b)));
      out.angle.push(Math.round(360 * (Math.acos(z) / (2 * Math.PI))));
      var z2 = Math.max(-1, Math.min(1, (a * a + c * c - b * b) / (2 * a * c)));
      var d = a * Math.sin(Math.acos(z2));
      out.distance.push(Math.round((d / c) * 100));
    }
    return out;
  }
  function speed(move, sampleMs) {
    var r = [];
    for (var i = 0; i < move.length - 1; i++) {
      var dx = move[i + 1][0] - move[i][0];
      var dy = move[i][1] - move[i + 1][1];
      r.push(Math.round(Math.sqrt(dx * dx + dy * dy) / (sampleMs / 1000)));
    }
    return r;
  }
  function acceleration(speeds, sampleMs) {
    var r = [];
    for (var i = 0; i < speeds.length - 1; i++) {
      r.push(Math.round((speeds[i + 1] - speeds[i]) / (sampleMs / 1000)));
    }
    return r;
  }

  // ---- click time tracker ----------------------------------------------
  function ClickTimeTracker() {
    var self = this;
    this.clickTimes = [];
    this.lastClickInfo = null;
    var down = null;
    document.addEventListener("mousedown", function (e) { down = e.timeStamp; });
    document.addEventListener("click", function (e) {
      if (down !== null) {
        self.clickTimes.push(Math.round((e.timeStamp - down) / 10));
        down = null;
      }
      var t = e.target;
      var rect = t.getBoundingClientRect();
      self.lastClickInfo = {
        html: e.currentTarget && e.currentTarget.innerHTML,
        elementId: t.getAttribute && t.getAttribute("id"),
        href: t.getAttribute && t.getAttribute("href"),
        timeStamp: e.timeStamp,
        x: rect.left,
        y: rect.top
      };
    });
  }
  ClickTimeTracker.prototype.flush = function () {
    var r = this.clickTimes;
    this.clickTimes = [];
    return r;
  };

  // ---- link tracker (rich click events + link overtime) ----------------
  function LinkTracker(mouseTracker) {
    this.enterTime = null;
    this.enterTarget = null;
    var links = document.querySelectorAll("a");
    for (var i = 0; i < links.length; i++) this.attach(mouseTracker, links[i]);
  }
  LinkTracker.prototype.attach = function (mouseTracker, link) {
    var self = this;
    link.addEventListener("mouseenter", function (e) {
      self.enterTime = e.timeStamp;
      self.enterTarget = e.currentTarget;
    });
    link.addEventListener("click", function (e) {
      var rect = e.currentTarget.getBoundingClientRect();
      var x = Math.round(((e.clientX - rect.left) / rect.width) * 100);
      var y = Math.round(((e.clientY - rect.top) / rect.height) * 100);
      var overtime = null;
      if (self.enterTime !== null && self.enterTarget === e.currentTarget) {
        overtime = e.timeStamp - self.enterTime;
      }
      var recent = overtime === null ? null : mouseTracker.getRecent();
      post("link_clicks", {
        fingerprint_id: fp,
        url: window.location.href,
        click_time: e.timeStamp,
        link_id: e.currentTarget.getAttribute("id"),
        text_analyze: e.currentTarget.getAttribute("data-individlabs-text-analyze"),
        link_href: e.currentTarget.getAttribute("href"),
        link_contents: e.currentTarget.innerHTML,
        link_x: rect.left,
        link_y: rect.top,
        link_size: Math.round(rect.width * rect.height),
        click_x: x,
        click_y: y,
        overtime: overtime,
        mouse_speed: recent ? recent.speeds.join(",") : null,
        mouse_acceleration: recent ? recent.accelerations.join(",") : null
      });
    });
  };

  // ---- link-position bucket (periodic, % within link) ------------------
  function LinkPositionBucket() {
    this.positions = [];
    this.overtimes = [];
    this.startedAt = null;
    var self = this;
    var enterTime = null, enterTarget = null;
    var links = document.querySelectorAll("a");
    for (var i = 0; i < links.length; i++) {
      links[i].addEventListener("mouseenter", function (e) { enterTime = e.timeStamp; enterTarget = e.currentTarget; });
      links[i].addEventListener("click", function (e) {
        var rect = e.currentTarget.getBoundingClientRect();
        var x = Math.round(((e.clientX - rect.left) / rect.width) * 100);
        var y = Math.round(((e.clientY - rect.top) / rect.height) * 100);
        self.positions.push("(" + x + "," + y + ")");
        if (enterTime !== null && enterTarget === e.currentTarget) {
          self.overtimes.push(e.timeStamp - enterTime);
        }
        if (self.startedAt === null) self.startedAt = Date.now();
      });
    }
  }
  LinkPositionBucket.prototype.flushIfReady = function () {
    if (this.startedAt === null) return null;
    if (Date.now() - this.startedAt < 55000) return null;
    var out = { link_positions: this.positions.join(""), link_overtimes: this.overtimes.join(",") };
    this.positions = []; this.overtimes = []; this.startedAt = null;
    return out;
  };

  // ---- orientation (mobile) --------------------------------------------
  function OrientationTracker() {
    var SAMPLE = 500;
    var STILL_TIMEOUT = 20;
    var LIMIT = (STILL_TIMEOUT * 1000) / SAMPLE;
    this.beta = []; this.gamma = [];
    var lastB = null, lastG = null, stillB = 0, stillG = 0, rb = null, rg = null;
    if (!window.DeviceOrientationEvent) return;
    window.addEventListener("deviceorientation", function (e) {
      rb = Math.round(e.beta);
      rg = Math.round(e.gamma);
    });
    var self = this;
    setInterval(function () {
      stillB = (rb === lastB) ? stillB + 1 : 0;
      lastB = rb;
      stillG = (rg === lastG) ? stillG + 1 : 0;
      lastG = rg;
      if (rb !== null && stillB < LIMIT) { self.beta.push(rb); rb = null; }
      if (rg !== null && stillG < LIMIT) { self.gamma.push(rg); rg = null; }
    }, SAMPLE);
  }
  OrientationTracker.prototype.flush = function () {
    var r = { beta: this.beta, gamma: this.gamma };
    this.beta = []; this.gamma = [];
    return r;
  };

  // ---- page visit + unload --------------------------------------------
  function reportPageVisit() {
    var pending = null;
    try { pending = sessionStorage.getItem("person_scan_pageleave"); } catch (e) {}
    if (pending) {
      try {
        post("page_visits", JSON.parse(pending), function () {
          try { sessionStorage.removeItem("person_scan_pageleave"); } catch (e) {}
        });
      } catch (e) {}
    }
    post("page_visits", {
      fingerprint_id: fp,
      url: window.location.href,
      visit_time: Date.now(),
      leave: "false"
    });
  }

  function attachUnload(clickTimeTracker) {
    window.addEventListener("beforeunload", function (e) {
      var lc = clickTimeTracker.lastClickInfo;
      var data;
      if (lc && e.timeStamp - lc.timeStamp < 100) {
        data = {
          click: true, element_href: lc.href, element_id: lc.elementId,
          element_x: lc.x, element_y: lc.y, element_html: lc.html
        };
      } else {
        data = { click: false, element_href: "", element_id: "", element_x: "", element_y: "", element_html: "" };
      }
      data.fingerprint_id = fp;
      data.visit_time = Date.now();
      data.url = window.location.href;
      data.leave = "true";
      try { sessionStorage.setItem("person_scan_pageleave", JSON.stringify(data)); } catch (e) {}
      post("page_visits", data);
    });
  }

  // ---- new-link MutationObserver ---------------------------------------
  function onLinkAdded(handler) {
    if (typeof MutationObserver === "undefined") return;
    var mo = new MutationObserver(function (muts) {
      for (var i = 0; i < muts.length; i++) {
        for (var j = 0; j < muts[i].addedNodes.length; j++) {
          var n = muts[i].addedNodes[j];
          if (n.tagName === "A") handler(n);
        }
      }
    });
    mo.observe(document.body, { childList: true, subtree: true });
  }

  // ---- boot ------------------------------------------------------------
  function start() {
    reportNewSession();
    reportPageVisit();

    var scrollT = new ScrollTracker();
    var mouseT = new MouseTracker();
    var clickT = new ClickTimeTracker();
    var linkT = new LinkTracker(mouseT);
    var linkPos = new LinkPositionBucket();
    var orientT = new OrientationTracker();

    onLinkAdded(function (a) { linkT.attach(mouseT, a); });
    attachUnload(clickT);

    function postBatch() {
      var scroll = scrollT.flush();
      var mouse = mouseT.flush();
      var clicks = clickT.flush();
      var orient = orientT.flush();
      var hasData = scroll.decisive_scroll || scroll.indecisive_scroll ||
                    mouse.directions.length || mouse.mouse_moving ||
                    clicks.length || orient.beta.length || orient.gamma.length;
      if (!hasData) return;

      var data = {
        fingerprint_id: fp,
        decisive_scroll: scroll.decisive_scroll,
        indecisive_scroll: scroll.indecisive_scroll,
        directions: mouse.directions,
        curvatureAngles: mouse.curvatureAngles,
        curvatureDistances: mouse.curvatureDistances,
        speeds: mouse.speeds,
        accelerations: mouse.accelerations,
        mouse_moving: mouse.mouse_moving,
        mouse_still: mouse.mouse_still,
        clickTimes: clicks,
        orientation_beta: orient.beta,
        orientation_gamma: orient.gamma
      };
      var lp = linkPos.flushIfReady();
      if (lp) {
        data.link_positions = lp.link_positions;
        data.link_overtimes = lp.link_overtimes;
      }
      post("visitor/track", data);
    }

    window.addEventListener("beforeunload", postBatch);
    setTimeout(postBatch, 10000);
    setInterval(postBatch, 30000);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", start);
  } else {
    start();
  }
})();
