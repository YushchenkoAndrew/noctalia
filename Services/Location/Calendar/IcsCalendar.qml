pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.Location

import "../../../Helpers/Ics.js" as Ics

/**
* Native calendar provider: reads standard iCalendar (.ics) data, no external calendar stack.
*
* Sources (settings.json -> location.calendarSources), each one of:
*   "https://example.com/calendar.ics"        remote feed (Google "secret address in iCal format", Nextcloud, ...)
*   "/home/me/calendars"                      folder, every *.ics below it is read (vdirsyncer / khal layout)
*   "/home/me/work.ics"                       single file
*   "Work|<any of the above>"                 same, with a display name
*
* Floating and TZID times are treated as system-local time; UTC times are converted exactly.
*/
Singleton {
  id: root

  readonly property int refreshIntervalMs: 5 * 60 * 1000

  // Parsed sources: [{name, source}]
  property var sources: []
  // Raw ics text per source index
  property var texts: ({})
  property double lastFetch: 0
  property int pending: 0

  // Current window in ms
  property double windowStart: 0
  property double windowEnd: 0

  function _normalizeSources() {
    var raw = Settings.data.location.calendarSources || [];
    var list = [];
    for (var i = 0; i < raw.length; i++) {
      var src = String(raw[i]).trim();
      var name = "";
      // optional "Name|source" prefix (a name never contains '/' or ':')
      var bar = src.indexOf("|");
      if (bar > 0 && !/[\/:]/.test(src.substring(0, bar))) {
        name = src.substring(0, bar).trim();
        src = src.substring(bar + 1).trim();
      }
      if (src === "")
        continue;
      if (src.indexOf("webcal://") === 0)
        src = "https://" + src.substring(9);
      if (name === "") {
        var base = src.replace(/[?#].*$/, "").replace(/\/+$/, "");
        name = base.substring(base.lastIndexOf("/") + 1) || base;
      }
      list.push({
                  "name": name,
                  "source": Settings.preprocessPath(src)
                });
    }
    root.sources = list;
  }

  function init() {
    _normalizeSources();
    if (root.sources.length === 0) {
      CalendarService.available = false;
      CalendarService.lastError = "No calendar sources configured (location.calendarSources)";
      return;
    }
    CalendarService.dataProvider = root;
    CalendarService.available = true;
    CalendarService.lastError = "";
    loadCalendars();
    loadEvents();
  }

  function loadCalendars() {
    CalendarService.setCalendars(root.sources.map(function (s) {
      return s.name;
    }));
  }

  function loadEvents(daysAhead = 31, daysBehind = 14) {
    var now = new Date();
    root.windowStart = new Date(now.getFullYear(), now.getMonth(), now.getDate() - daysBehind).getTime();
    root.windowEnd = new Date(now.getFullYear(), now.getMonth(), now.getDate() + daysAhead + 1).getTime();

    var stale = (Date.now() - root.lastFetch) > root.refreshIntervalMs;
    if (stale || Object.keys(root.texts).length === 0) {
      _fetchAll();
    } else {
      _rebuild();
    }
  }

  // ---------------------------------------------------------------
  function _fetchAll() {
    if (root.pending > 0)
      return;
    CalendarService.loading = true;
    root.lastFetch = Date.now();
    root.pending = root.sources.length;
    for (var i = 0; i < root.sources.length; i++)
      _fetchOne(i, root.sources[i].source);
  }

  function _done(index, text) {
    var t = Object.assign({}, root.texts);
    if (text !== null)
      t[index] = text;
    root.texts = t;
    root.pending = Math.max(0, root.pending - 1);
    if (root.pending === 0) {
      CalendarService.loading = false;
      _rebuild();
    }
  }

  function _fetchOne(index, src) {
    if (/^https?:\/\//i.test(src)) {
      var xhr = new XMLHttpRequest();
      xhr.onreadystatechange = function () {
        if (xhr.readyState !== XMLHttpRequest.DONE)
          return;
        if (xhr.status >= 200 && xhr.status < 300) {
          root._done(index, xhr.responseText);
        } else {
          Logger.w("Calendar", "Failed to fetch", src, "status", xhr.status);
          CalendarService.lastError = "Failed to fetch " + src + " (" + xhr.status + ")";
          root._done(index, null);
        }
      };
      xhr.open("GET", src);
      xhr.send();
      return;
    }
    // Local file or folder: concatenate every .ics below it
    var p = localReader.createObject(root, {
                                       "index": index,
                                       "command": ["find", "-L", src, "-type", "f", "-name", "*.ics", "-exec", "cat", "{}", "+"]
                                     });
    p.running = true;
  }

  Component {
    id: localReader

    Process {
      property int index: -1

      stdout: StdioCollector {
        onStreamFinished: root._done(index, text)
      }

      stderr: StdioCollector {
        onStreamFinished: {
          if (text.trim() !== "") {
            Logger.d("Calendar", "Reading local calendar:", text.trim());
          }
        }
      }

      onExited: (exitCode, exitStatus) => {
                  if (exitCode !== 0) {
                    // find failed (missing path); the source still counts as finished
                    CalendarService.lastError = "Cannot read calendar source #" + index;
                  }
                  destroy(1000);
                }
    }
  }

  function _rebuild() {
    var all = [];
    for (var i = 0; i < root.sources.length; i++) {
      var text = root.texts[i];
      if (!text)
        continue;
      try {
        all = all.concat(Ics.eventsFromText(text, root.windowStart, root.windowEnd, root.sources[i].name));
      } catch (e) {
        Logger.w("Calendar", "Failed to parse", root.sources[i].name, e);
        CalendarService.lastError = "Failed to parse " + root.sources[i].name;
      }
    }
    all.sort(function (a, b) {
      return a.start - b.start;
    });
    CalendarService.setEvents(all);
    Logger.d("Calendar", "Loaded", all.length, "event(s) from", root.sources.length, "source(s)");
  }
}
